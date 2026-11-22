// Trang quản trị VieTing (/admin) + API /api/admin/*. Tác giả: Phạm Thành Long (thlong)
//
// Admin đăng nhập bằng chính tài khoản VieTing của mình; tài khoản phải nằm trong bảng `admins`
// (chạy dat-admin.bat ở thư mục gốc để cấp quyền lần đầu).
// Admin chỉ xem số liệu tổng hợp (số giao dịch, lần đồng bộ cuối...), KHÔNG xem nội dung chi tiêu của người dùng.

import { DEFAULT_SMART, DEFAULT_OCCASIONS, DEFAULT_RATES, DEFAULT_TONES, fxRates, getConfig, grantPro, setConfig } from './config.js';

import PAGE from './admin.html';

const DAY = 86400000;

export async function adminCheck(env, userId) {
  if (userId == null) return false;
  const r = await env.DB.prepare('SELECT 1 AS ok FROM admins WHERE user_id = ?').bind(userId).first();
  return !!r;
}

async function log(env, adminId, action, target) {
  await env.DB.prepare('INSERT INTO admin_log (admin_id, action, target, created) VALUES (?, ?, ?, ?)')
    .bind(adminId, action, String(target ?? ''), Date.now())
    .run();
}

function vnDay(ms) {
  // ngày theo giờ Việt Nam (UTC+7)
  return new Date(ms + 7 * 3600000).toISOString().slice(0, 10);
}

async function stats(env) {
  const now = Date.now();
  const one = (sql, ...b) => env.DB.prepare(sql).bind(...b).first();
  const [users, new7, new30, active1, active7, active30, txns, banned, admins] = await Promise.all([
    one('SELECT COUNT(*) AS n FROM users'),
    one('SELECT COUNT(*) AS n FROM users WHERE created > ?', now - 7 * DAY),
    one('SELECT COUNT(*) AS n FROM users WHERE created > ?', now - 30 * DAY),
    one('SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE srv > ?', now - DAY),
    one('SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE srv > ?', now - 7 * DAY),
    one('SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE srv > ?', now - 30 * DAY),
    one("SELECT COUNT(*) AS n FROM records WHERE kind = 'txn' AND deleted = 0"),
    one('SELECT COUNT(*) AS n FROM banned'),
    one('SELECT COUNT(*) AS n FROM admins'),
  ]);
  const since = now - 30 * DAY;
  const signRows = (await env.DB.prepare('SELECT created FROM users WHERE created > ?').bind(since).all()).results || [];
  const syncRows =
    (
      await env.DB.prepare(
        "SELECT srv FROM records WHERE kind = 'txn' AND srv > ? ORDER BY srv DESC LIMIT 20000"
      )
        .bind(since)
        .all()
    ).results || [];
  const days = [];
  for (let i = 29; i >= 0; i--) days.push(vnDay(now - i * DAY));
  const signups = Object.fromEntries(days.map((d) => [d, 0]));
  const txnDays = Object.fromEntries(days.map((d) => [d, 0]));
  for (const r of signRows) if (vnDay(r.created) in signups) signups[vnDay(r.created)]++;
  for (const r of syncRows) if (vnDay(r.srv) in txnDays) txnDays[vnDay(r.srv)]++;
  const aiRows =
    (
      await env.DB.prepare('SELECT day, SUM(n) AS n, COUNT(*) AS people FROM ai_usage WHERE day >= ? AND day NOT LIKE "M%" AND k NOT LIKE "tk%" GROUP BY day ORDER BY day')
        .bind(new Date(now - 14 * DAY).toISOString().slice(0, 10))
        .all()
    ).results || [];
  return {
    users: users.n,
    new7: new7.n,
    new30: new30.n,
    active1: active1.n,
    active7: active7.n,
    active30: active30.n,
    txns: txns.n,
    banned: banned.n,
    admins: admins.n,
    days,
    signups: days.map((d) => signups[d]),
    txnDays: days.map((d) => txnDays[d]),
    ai: aiRows,
    openTickets: (await env.DB.prepare("SELECT COUNT(*) AS n FROM tickets WHERE status IN ('open','doing')").first().catch(() => ({ n: 0 })))?.n || 0,
    newOcr: (await env.DB.prepare("SELECT COUNT(*) AS n FROM ocr_reports WHERE status = 'new'").first().catch(() => ({ n: 0 })))?.n || 0,
    pro: (await env.DB.prepare('SELECT COUNT(*) AS n FROM plans WHERE until > ?').bind(now).first().catch(() => ({ n: 0 })))?.n || 0,
    ai_error: await getConfig(env, 'ai_error', null),
    ai_provider: env.GEMINI_API_KEY ? 'Gemini' : env.AI ? 'Workers AI (dự phòng)' : 'chưa bật',
  };
}

async function listUsers(env, url) {
  const q = (url.searchParams.get('q') || '').trim().toLowerCase();
  const offset = Math.max(0, Number(url.searchParams.get('offset')) || 0);
  const sort = url.searchParams.get('sort') === 'active' ? 'last DESC' : 'u.created DESC';
  const rows =
    (
      await env.DB.prepare(
        `SELECT u.id, u.email, u.created,
                r.last, COALESCE(r.txn, 0) AS txn, COALESCE(r.n, 0) AS n,
                (SELECT COUNT(*) FROM sessions s WHERE s.user_id = u.id) AS devices,
                (SELECT reason FROM banned b WHERE b.user_id = u.id) AS banned,
                EXISTS (SELECT 1 FROM admins a WHERE a.user_id = u.id) AS admin,
                (SELECT until FROM plans p WHERE p.user_id = u.id AND p.until > ${Date.now()}) AS pro_until
         FROM users u
         LEFT JOIN (SELECT user_id, MAX(srv) AS last, SUM(kind = 'txn' AND deleted = 0) AS txn, COUNT(*) AS n
                    FROM records GROUP BY user_id) r ON r.user_id = u.id
         WHERE (? = '' OR u.email LIKE ?)
         ORDER BY ${sort}
         LIMIT 50 OFFSET ?`
      )
        .bind(q, `%${q}%`, offset)
        .all()
    ).results || [];
  const total = await env.DB.prepare("SELECT COUNT(*) AS n FROM users WHERE (? = '' OR email LIKE ?)").bind(q, `%${q}%`).first();
  return { users: rows, total: total.n, offset };
}

async function userAction(env, adminId, b, h) {
  const id = Number(b?.id);
  const action = String(b?.action || '');
  if (!id) return h.json({ error: 'Thiếu id' }, 400);
  const u = await env.DB.prepare('SELECT id, email FROM users WHERE id = ?').bind(id).first();
  if (!u) return h.json({ error: 'Không có người dùng này' }, 404);
  if (id === adminId && ['ban', 'delete', 'unadmin'].includes(action)) {
    return h.json({ error: 'Không thể tự khóa / xóa / bỏ quyền chính mình' }, 400);
  }
  let extra = {};
  switch (action) {
    case 'ban':
      await env.DB.batch([
        env.DB.prepare('INSERT OR REPLACE INTO banned (user_id, reason, created) VALUES (?, ?, ?)').bind(
          id,
          String(b.reason || '').slice(0, 200),
          Date.now()
        ),
        env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id),
      ]);
      break;
    case 'unban':
      await env.DB.prepare('DELETE FROM banned WHERE user_id = ?').bind(id).run();
      break;
    case 'logout':
      await env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id).run();
      break;
    case 'reset': {
      const pass = h.randomHex(4); // 8 ký tự
      const salt = h.randomHex(16);
      const hash = await h.hashPassword(pass, salt);
      await env.DB.batch([
        env.DB.prepare('UPDATE users SET salt = ?, hash = ? WHERE id = ?').bind(salt, hash, id),
        env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id),
      ]);
      extra = { password: pass };
      break;
    }
    case 'gift': {
      const days = Math.min(3650, Math.max(1, Number(b.days) || 0));
      extra = { until: await grantPro(env, id, days, String(b.reason || 'Admin tặng').slice(0, 200)) };
      await log(env, adminId, 'gift ' + days + ' ngày', u.email);
      return h.json({ ok: true, ...extra });
    }
    case 'unpro':
      await env.DB.prepare('DELETE FROM plans WHERE user_id = ?').bind(id).run();
      break;
    case 'admin':
      await env.DB.prepare('INSERT OR IGNORE INTO admins (user_id, created) VALUES (?, ?)').bind(id, Date.now()).run();
      break;
    case 'unadmin':
      await env.DB.prepare('DELETE FROM admins WHERE user_id = ?').bind(id).run();
      break;
    case 'delete':
      await env.DB.batch([
        env.DB.prepare('DELETE FROM records WHERE user_id = ?').bind(id),
        env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id),
        env.DB.prepare('DELETE FROM banned WHERE user_id = ?').bind(id),
        env.DB.prepare('DELETE FROM admins WHERE user_id = ?').bind(id),
        env.DB.prepare('DELETE FROM plans WHERE user_id = ?').bind(id),
        env.DB.prepare('DELETE FROM voucher_uses WHERE user_id = ?').bind(id),
        env.DB.prepare('UPDATE tickets SET user_id = NULL WHERE user_id = ?').bind(id),
        env.DB.prepare('UPDATE ocr_reports SET user_id = NULL WHERE user_id = ?').bind(id),
        env.DB.prepare("DELETE FROM ai_usage WHERE k = ?").bind('u' + id),
        env.DB.prepare('DELETE FROM users WHERE id = ?').bind(id),
      ]);
      break;
    default:
      return h.json({ error: 'Thao tác không hợp lệ' }, 400);
  }
  await log(env, adminId, action, u.email);
  return h.json({ ok: true, ...extra });
}

async function notices(env) {
  return (await env.DB.prepare('SELECT * FROM notices ORDER BY id DESC LIMIT 30').all()).results || [];
}

async function saveNotice(env, adminId, b, h) {
  const level = ['info', 'success', 'warning'].includes(b?.level) ? b.level : 'info';
  if (b?.id && b.toggle) {
    await env.DB.prepare('UPDATE notices SET active = 1 - active WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'notice-toggle', b.id);
    return h.json({ ok: true });
  }
  if (b?.id && b.remove) {
    await env.DB.prepare('DELETE FROM notices WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'notice-delete', b.id);
    return h.json({ ok: true });
  }
  const title = String(b?.title || '').trim().slice(0, 120);
  const body = String(b?.body || '').trim().slice(0, 1000);
  if (!title) return h.json({ error: 'Cần tiêu đề' }, 400);
  const inApp = b?.inApp !== false, push = !!b?.push;
  if (!inApp && !push) return h.json({ error: 'Chọn ít nhất một cách gửi' }, 400);
  if (inApp) {
    await env.DB.prepare('INSERT INTO notices (title, body, level, active, created) VALUES (?, ?, ?, 1, ?)')
      .bind(title, body, level, Date.now())
      .run();
  }
  if (push) {
    await env.DB.prepare('INSERT INTO pushes (title, body, created) VALUES (?, ?, ?)').bind(title, body.slice(0, 300), Date.now()).run();
  }
  await log(env, adminId, push ? (inApp ? 'notice+push' : 'push') : 'notice', title);
  return h.json({ ok: true });
}

/** Thông báo đang bật mới nhất, app hiện ở trang Tổng quan. */
export async function publicNotice(env, h) {
  try {
    const n = await env.DB.prepare('SELECT id, title, body, level, created FROM notices WHERE active = 1 ORDER BY id DESC LIMIT 1').first();
    return h.json({ notice: n || null });
  } catch {
    return h.json({ notice: null });
  }
}

const CATS = ['an_uong','di_lai','mua_sam','hoa_don','nha_o','giai_tri','suc_khoe','giao_duc','gia_dinh','chuyen_di','chi_ho','chuyen_vi','khac_chi','luong','thuong','dau_tu','nhan_tien','khac_thu','thu_ho','nhan_vi'];
const all = async (env, sql, ...b) => (await env.DB.prepare(sql).bind(...b).all()).results || [];
const str = (v, n) => String(v ?? '').trim().slice(0, n);

async function dictSave(env, adminId, b, h) {
  if (b?.id && b.remove) {
    await env.DB.prepare('DELETE FROM dict WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'dict-delete', b.id);
    return h.json({ ok: true });
  }
  const keyword = str(b?.keyword, 60).toLowerCase();
  const category = String(b?.category || '');
  if (keyword.length < 2 || !CATS.includes(category)) return h.json({ error: 'Cần từ khóa (≥ 2 ký tự) và danh mục hợp lệ' }, 400);
  await env.DB.prepare(
    `INSERT INTO dict (keyword, category, note, created) VALUES (?, ?, ?, ?)
     ON CONFLICT (keyword) DO UPDATE SET category = excluded.category, note = excluded.note`
  )
    .bind(keyword, category, str(b?.note, 120), Date.now())
    .run();
  await log(env, adminId, 'dict', keyword + ' → ' + category);
  return h.json({ ok: true });
}

async function campaignSave(env, adminId, b, h) {
  if (b?.id && b.toggle) {
    await env.DB.prepare('UPDATE campaigns SET active = 1 - active WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'campaign-toggle', b.id);
    return h.json({ ok: true });
  }
  if (b?.id && b.remove) {
    await env.DB.prepare('DELETE FROM campaigns WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'campaign-delete', b.id);
    return h.json({ ok: true });
  }
  const kind = b?.kind === 'goal' ? 'goal' : 'avoid';
  const title = str(b?.title, 80);
  const start = Number(b?.start) || Date.now();
  const end = Number(b?.end) || start + 30 * DAY;
  const days = Math.min(90, Math.max(1, Number(b?.days) || 7));
  const keywords = str(b?.keywords, 300);
  const category = CATS.includes(b?.category) ? b.category : '';
  const target = Math.max(0, Math.round(Number(b?.target) || 0));
  if (!title) return h.json({ error: 'Cần tên sự kiện' }, 400);
  if (end <= start) return h.json({ error: 'Ngày kết thúc phải sau ngày bắt đầu' }, 400);
  if (kind === 'avoid' && !keywords && !category) return h.json({ error: 'Thử thách kiêng chi cần từ khóa hoặc danh mục' }, 400);
  if (kind === 'goal' && !target) return h.json({ error: 'Sự kiện gom tiền cần số tiền mục tiêu' }, 400);
  const vals = [kind, title, str(b?.emoji, 8) || '🎯', str(b?.body, 500), keywords, category, days, target, start, end];
  if (b?.id) {
    await env.DB.prepare(
      'UPDATE campaigns SET kind=?, title=?, emoji=?, body=?, keywords=?, category=?, days=?, target=?, start=?, end=? WHERE id = ?'
    )
      .bind(...vals, Number(b.id))
      .run();
  } else {
    await env.DB.prepare(
      'INSERT INTO campaigns (kind, title, emoji, body, keywords, category, days, target, start, end, active, created) VALUES (?,?,?,?,?,?,?,?,?,?,1,?)'
    )
      .bind(...vals, Date.now())
      .run();
  }
  await log(env, adminId, 'campaign', title);
  return h.json({ ok: true });
}

async function catalogSave(env, adminId, b, h) {
  if (b?.id && b.remove) {
    await env.DB.prepare('DELETE FROM catalog WHERE id = ?').bind(Number(b.id)).run();
    await log(env, adminId, 'catalog-delete', b.id);
    return h.json({ ok: true });
  }
  const name = str(b?.name, 60);
  const amount = Math.round(Number(b?.amount) || 0);
  const cycle = ['week', 'month', 'year'].includes(b?.cycle) ? b.cycle : 'month';
  const category = CATS.includes(b?.category) ? b.category : 'giai_tri';
  if (!name || amount <= 0) return h.json({ error: 'Cần tên và giá' }, 400);
  if (b?.id) {
    await env.DB.prepare('UPDATE catalog SET name=?, amount=?, cycle=?, category=?, sort=? WHERE id=?')
      .bind(name, amount, cycle, category, Number(b.sort) || 0, Number(b.id))
      .run();
  } else {
    await env.DB.prepare(
      `INSERT INTO catalog (name, amount, cycle, category, sort) VALUES (?,?,?,?,?)
       ON CONFLICT (name) DO UPDATE SET amount = excluded.amount, cycle = excluded.cycle, category = excluded.category`
    )
      .bind(name, amount, cycle, category, Number(b.sort) || 99)
      .run();
  }
  await log(env, adminId, 'catalog', name + ' ' + amount);
  return h.json({ ok: true });
}

async function voucherSave(env, adminId, b, h) {
  if (b?.code && b.remove) {
    await env.DB.prepare('DELETE FROM vouchers WHERE code = ?').bind(String(b.code)).run();
    await log(env, adminId, 'voucher-delete', b.code);
    return h.json({ ok: true });
  }
  let code = str(b?.code, 24).toUpperCase().replace(/[^A-Z0-9_-]/g, '');
  if (!code) code = 'VT' + crypto.getRandomValues(new Uint32Array(1))[0].toString(36).toUpperCase().slice(0, 6);
  const days = Math.min(3650, Math.max(1, Number(b?.days) || 30));
  const max = Math.min(100000, Math.max(1, Number(b?.max_uses) || 1));
  const exp = Number(b?.expires_days) > 0 ? Date.now() + Number(b.expires_days) * DAY : 0;
  try {
    await env.DB.prepare('INSERT INTO vouchers (code, days, max_uses, used, expires, note, created) VALUES (?,?,?,0,?,?,?)')
      .bind(code, days, max, exp, str(b?.note, 120), Date.now())
      .run();
  } catch {
    return h.json({ error: 'Mã này đã tồn tại' }, 409);
  }
  await log(env, adminId, 'voucher', code + ' (' + days + ' ngày × ' + max + ')');
  return h.json({ ok: true, code });
}

async function ticketSave(env, adminId, b, h) {
  const id = Number(b?.id);
  const status = ['open', 'doing', 'fixed', 'closed'].includes(b?.status) ? b.status : null;
  const t = await env.DB.prepare('SELECT id, reply, status FROM tickets WHERE id = ?').bind(id).first();
  if (!t) return h.json({ error: 'Không có phiếu này' }, 404);
  const reply = b?.reply == null ? t.reply : str(b.reply, 2000);
  const changed = reply !== t.reply || (status && status !== t.status);
  await env.DB.prepare('UPDATE tickets SET status = ?, reply = ?, updated = ?, seen = ? WHERE id = ?')
    .bind(status || t.status, reply, Date.now(), changed ? 0 : 1, id)
    .run();
  await log(env, adminId, 'ticket ' + (status || t.status), '#' + id);
  return h.json({ ok: true });
}

/** Phễu, giữ chân theo tuần đăng ký, xu hướng chi tiêu ẩn danh (nhóm < 5 người thì ẩn). */
async function analytics(env) {
  const now = Date.now();
  const one = async (sql, ...b) => (await env.DB.prepare(sql).bind(...b).first())?.n || 0;
  const funnel = [
    ['Đăng ký', await one('SELECT COUNT(*) AS n FROM users')],
    ['Đã đồng bộ dữ liệu', await one('SELECT COUNT(DISTINCT user_id) AS n FROM records')],
    ['Có ví', await one("SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE kind = 'wallet'")],
    ['Ghi giao dịch đầu tiên', await one("SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE kind = 'txn'")],
    ['Có ≥ 10 giao dịch', await one("SELECT COUNT(*) AS n FROM (SELECT user_id FROM records WHERE kind = 'txn' GROUP BY user_id HAVING COUNT(*) >= 10)")],
    ['Còn dùng sau 7 ngày', await one('SELECT COUNT(DISTINCT r.user_id) AS n FROM records r JOIN users u ON u.id = r.user_id WHERE r.srv > u.created + ?', 7 * DAY)],
    ['Còn dùng sau 30 ngày', await one('SELECT COUNT(DISTINCT r.user_id) AS n FROM records r JOIN users u ON u.id = r.user_id WHERE r.srv > u.created + ?', 30 * DAY)],
    ['Dùng gói định kỳ / mục tiêu', await one("SELECT COUNT(DISTINCT user_id) AS n FROM records WHERE kind IN ('bill','goal')")],
  ];
  // giữ chân theo tuần đăng ký (8 tuần gần nhất)
  const since = now - 8 * 7 * DAY;
  const users = await all(env, 'SELECT id, created FROM users WHERE created > ?', since);
  const act = await all(
    env,
    'SELECT r.user_id AS uid, CAST((r.srv - u.created) / ? AS INTEGER) AS w FROM records r JOIN users u ON u.id = r.user_id WHERE u.created > ? GROUP BY uid, w',
    7 * DAY,
    since
  );
  const weeksOf = {};
  for (const a of act) (weeksOf[a.uid] ||= new Set()).add(a.w);
  const cohorts = [];
  for (let i = 7; i >= 0; i--) {
    const a = now - (i + 1) * 7 * DAY, b = now - i * 7 * DAY;
    const us = users.filter((u) => u.created > a && u.created <= b);
    const row = { week: new Date(a + 7 * 3600000).toISOString().slice(5, 10), size: us.length, w: [] };
    for (let k = 1; k <= 4; k++) {
      if (now - k * 7 * DAY < a) row.w.push(null);
      else row.w.push(us.length ? Math.round((us.filter((u) => weeksOf[u.id]?.has(k)).length * 100) / us.length) : null);
    }
    cohorts.push(row);
  }
  // xu hướng chi tiêu: 2 tháng gần nhất theo danh mục (theo giờ VN, bỏ khoản riêng tư và khoản trung gian)
  const vn = new Date(now + 7 * 3600000);
  const m0 = Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth(), 1) - 7 * 3600000;
  const m1 = Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth() - 1, 1) - 7 * 3600000;
  const rows = await all(
    env,
    `SELECT json_extract(data, '$.cat') AS cat,
            CASE WHEN json_extract(data, '$.date') >= ? THEN 0 ELSE 1 END AS m,
            SUM(json_extract(data, '$.amount')) AS total, COUNT(DISTINCT user_id) AS people, COUNT(*) AS n
     FROM records
     WHERE kind = 'txn' AND deleted = 0 AND json_extract(data, '$.income') = 0
       AND COALESCE(json_extract(data, '$.hid'), 0) = 0
       AND json_extract(data, '$.date') >= ? AND json_extract(data, '$.date') < ?
       AND json_extract(data, '$.cat') NOT IN ('chi_ho', 'chuyen_vi')
     GROUP BY cat, m`,
    m0,
    m1,
    now
  );
  const K = 5;
  const byCat = {};
  for (const r of rows) {
    const c = (byCat[r.cat] ||= { cat: r.cat });
    c[r.m === 0 ? 'cur' : 'prev'] = r.people >= K ? { total: r.total, people: r.people, avg: Math.round(r.total / r.people) } : { hidden: true, people: r.people };
  }
  const trends = Object.values(byCat).sort((a, b) => (b.cur?.total || 0) - (a.cur?.total || 0));
  return { funnel, cohorts, trends, k: K };
}

export async function handleAdmin(req, env, url, userId, h) {
  if (!(await adminCheck(env, userId))) return h.json({ error: 'Tài khoản này không có quyền quản trị' }, 403);
  const path = url.pathname.slice('/api/admin'.length);
  if (req.method === 'GET' && path === '/me') {
    const u = await env.DB.prepare('SELECT email FROM users WHERE id = ?').bind(userId).first();
    return h.json({ email: u?.email || '' });
  }
  if (req.method === 'GET' && path === '/stats') return h.json(await stats(env));
  if (req.method === 'GET' && path === '/users') return h.json(await listUsers(env, url));
  if (req.method === 'POST' && path === '/user') return await userAction(env, userId, await h.readJson(req), h);
  if (req.method === 'GET' && path === '/notices') return h.json({ notices: await notices(env) });
  if (req.method === 'POST' && path === '/notice') return await saveNotice(env, userId, await h.readJson(req), h);
  const b = req.method === 'POST' ? await h.readJson(req) : null;
  switch (req.method + ' ' + path) {
    case 'GET /pushes':
      return h.json({ pushes: await all(env, 'SELECT * FROM pushes ORDER BY id DESC LIMIT 30') });
    case 'GET /smart':
      return h.json({ smart: { ...DEFAULT_SMART, ...(await getConfig(env, 'smart', {})) } });
    case 'POST /smart': {
      const out = {};
      for (const k of Object.keys(DEFAULT_SMART)) {
        const d = DEFAULT_SMART[k], v = b?.smart?.[k] || {};
        out[k] = { on: v.on !== false, title: str(v.title, 600) || d.title, body: str(v.body, 1500) || d.body };
        if ('hour' in d) out[k].hour = Math.min(23, Math.max(0, Number(v.hour) || d.hour));
        if ('days' in d) out[k].days = Math.min(30, Math.max(1, Number(v.days) || d.days));
        if ('before' in d) out[k].before = Math.min(7, Math.max(0, Number(v.before ?? d.before)));
      }
      await setConfig(env, 'smart', out);
      await log(env, userId, 'smart', '');
      return h.json({ ok: true });
    }
    case 'GET /dict':
      return h.json({ dict: await all(env, 'SELECT * FROM dict ORDER BY id DESC') });
    case 'POST /dict':
      return await dictSave(env, userId, b, h);
    case 'GET /ocr':
      return h.json({
        reports: await all(env, 'SELECT o.*, u.email FROM ocr_reports o LEFT JOIN users u ON u.id = o.user_id ORDER BY o.id DESC LIMIT 200'),
      });
    case 'POST /ocr':
      await env.DB.prepare('UPDATE ocr_reports SET status = ? WHERE id = ?').bind(b?.status === 'done' ? 'done' : 'new', Number(b?.id)).run();
      await log(env, userId, 'ocr ' + (b?.status || ''), '#' + b?.id);
      return h.json({ ok: true });
    case 'GET /ai-config':
      return h.json({
        tones: { ...DEFAULT_TONES, ...(await getConfig(env, 'tones', {})) },
        occasions: await getConfig(env, 'occasions', DEFAULT_OCCASIONS),
      });
    case 'POST /ai-config': {
      const tones = {};
      for (const k of ['gentle', 'funny', 'strict', 'expert']) tones[k] = str(b?.tones?.[k], 600) || DEFAULT_TONES[k];
      const occ = (Array.isArray(b?.occasions) ? b.occasions : []).slice(0, 30).map((o) => ({
        name: str(o.name, 60),
        ...(o.payday ? { payday: true } : { from: str(o.from, 5), to: str(o.to, 5) }),
        note: str(o.note, 400),
      })).filter((o) => o.name && (o.payday || (/^\d\d-\d\d$/.test(o.from) && /^\d\d-\d\d$/.test(o.to))));
      await setConfig(env, 'tones', tones);
      await setConfig(env, 'occasions', occ);
      await log(env, userId, 'ai-config', '');
      return h.json({ ok: true });
    }
    case 'GET /campaigns':
      return h.json({ campaigns: await all(env, 'SELECT * FROM campaigns ORDER BY start DESC LIMIT 100') });
    case 'POST /campaign':
      return await campaignSave(env, userId, b, h);
    case 'GET /catalog':
      return h.json({
        catalog: await all(env, 'SELECT * FROM catalog ORDER BY sort, name'),
        rates: await getConfig(env, 'rates', DEFAULT_RATES),
        fx: await fxRates(env),
      });
    case 'POST /catalog':
      return await catalogSave(env, userId, b, h);
    case 'POST /rates': {
      const r = { saving6: Number(b?.saving6) || 0, saving12: Number(b?.saving12) || 0, note: str(b?.note, 200) };
      await setConfig(env, 'rates', r);
      await log(env, userId, 'rates', r.saving6 + '% / ' + r.saving12 + '%');
      return h.json({ ok: true });
    }
    case 'POST /fx-refresh':
      return h.json({ fx: await fxRates(env, true) });
    case 'GET /analytics':
      return h.json(await analytics(env));
    case 'GET /tickets': {
      const st = url.searchParams.get('status') || 'active';
      const where = st === 'all' ? '1=1' : st === 'active' ? "t.status IN ('open','doing')" : 't.status = ?';
      const args = st === 'all' || st === 'active' ? [] : [st];
      return h.json({
        tickets: await all(env, `SELECT t.*, u.email FROM tickets t LEFT JOIN users u ON u.id = t.user_id WHERE ${where} ORDER BY t.id DESC LIMIT 200`, ...args),
      });
    }
    case 'POST /ticket':
      return await ticketSave(env, userId, b, h);
    case 'GET /vouchers':
      return h.json({ vouchers: await all(env, 'SELECT * FROM vouchers ORDER BY created DESC LIMIT 200') });
    case 'POST /voucher':
      return await voucherSave(env, userId, b, h);
  }
  if (req.method === 'GET' && path === '/log') {
    const rows =
      (
        await env.DB.prepare(
          'SELECT l.action, l.target, l.created, u.email AS admin FROM admin_log l LEFT JOIN users u ON u.id = l.admin_id ORDER BY l.id DESC LIMIT 100'
        ).all()
      ).results || [];
    return h.json({ log: rows });
  }
  return h.json({ error: 'Không tìm thấy' }, 404);
}

export function adminPage() {
  return new Response(PAGE, {
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'no-store',
      'x-frame-options': 'DENY',
      'referrer-policy': 'no-referrer',
      'x-robots-tag': 'noindex',
    },
  });
}
