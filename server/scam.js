// Kiểm tra tài khoản có bị người dùng báo cáo lừa đảo hay không. Tác giả: Phạm Thành Long (thlong)
//
// Nguyên tắc (để đúng luật và chính sách Google Play về nội dung do người dùng tạo):
// - App chỉ hiện PHẢN ÁNH của người dùng đã được admin kiểm duyệt, không tự kết luận ai lừa đảo.
// - Báo cáo chờ duyệt không bao giờ hiện ra; danh tính người báo cáo không bao giờ lộ.
// - Ảnh bằng chứng chỉ hiện khi admin đã che thông tin cá nhân không cần thiết và bật công khai.
// - Chủ tài khoản được khiếu nại; người xem được báo cáo nội dung sai và chặn người báo cáo.
// - Báo cáo đã duyệt chỉ hiện trong 2 năm.
//
// GET  /api/scam/check?acct=&bin=     kết quả kiểm tra (không cần đăng nhập)
// GET  /api/scam/photo?id=            ảnh bằng chứng đã công khai
// POST /api/scam/report               gửi báo cáo (cần đăng nhập, đồng ý điều khoản)
// GET  /api/scam/mine                 báo cáo của tôi và trạng thái
// POST /api/scam/appeal               chủ tài khoản khiếu nại
// POST /api/scam/flag                 báo cáo nội dung sai / vi phạm
// POST /api/scam/block                chặn người báo cáo (ẩn mọi báo cáo của họ với mình)

const DAY = 86400000;
const KEEP = 730 * DAY;
const MAX_PHOTO = 700000;

export const SCAM_SCHEMA = [
  `CREATE TABLE IF NOT EXISTS scam_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, bin TEXT NOT NULL DEFAULT '', acct TEXT NOT NULL, holder TEXT NOT NULL DEFAULT '', channel TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', amount INTEGER NOT NULL DEFAULT 0, happened TEXT NOT NULL DEFAULT '', user_id INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending', note TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL, reviewed INTEGER, reviewer INTEGER)`,
  `CREATE INDEX IF NOT EXISTS scam_reports_acct ON scam_reports (acct, status)`,
  `CREATE INDEX IF NOT EXISTS scam_reports_user ON scam_reports (user_id, created)`,
  `CREATE TABLE IF NOT EXISTS scam_photos (id INTEGER PRIMARY KEY AUTOINCREMENT, report_id INTEGER NOT NULL, img TEXT NOT NULL, public INTEGER NOT NULL DEFAULT 0, masked INTEGER NOT NULL DEFAULT 0)`,
  `CREATE INDEX IF NOT EXISTS scam_photos_report ON scam_photos (report_id)`,
  `CREATE TABLE IF NOT EXISTS scam_appeals (id INTEGER PRIMARY KEY AUTOINCREMENT, bin TEXT NOT NULL DEFAULT '', acct TEXT NOT NULL, user_id INTEGER NOT NULL, contact TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'open', reply TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS scam_flags (id INTEGER PRIMARY KEY AUTOINCREMENT, report_id INTEGER NOT NULL, user_id INTEGER, reason TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL, done INTEGER NOT NULL DEFAULT 0)`,
  `CREATE TABLE IF NOT EXISTS scam_blocks (user_id INTEGER NOT NULL, reporter INTEGER NOT NULL, PRIMARY KEY (user_id, reporter))`,
];

let ready = false;
export async function ensureScamSchema(env) {
  if (ready) return;
  for (const s of SCAM_SCHEMA) await env.DB.prepare(s).run();
  ready = true;
}

const str = (v, n) => String(v ?? '').trim().slice(0, n);
export const normAcct = (v) => String(v ?? '').toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 32);
const normBin = (v) => String(v ?? '').replace(/\D/g, '').slice(0, 8);
const CHANNELS = ['mua_ban', 'viec_lam', 'dau_tu', 'vay', 'gia_danh', 'tinh_cam', 'game', 'khac'];

async function publicReports(env, acct, bin, viewer) {
  const since = Date.now() - KEEP;
  const rows =
    (
      await env.DB.prepare(
        `SELECT id, bin, holder, channel, body, amount, happened, created, user_id FROM scam_reports
         WHERE acct = ? AND status = 'approved' AND created > ? ORDER BY created DESC LIMIT 50`
      )
        .bind(acct, since)
        .all()
    ).results || [];
  let blocked = new Set();
  if (viewer != null) {
    const b = (await env.DB.prepare('SELECT reporter FROM scam_blocks WHERE user_id = ?').bind(viewer).all()).results || [];
    blocked = new Set(b.map((x) => x.reporter));
  }
  // Có chọn ngân hàng thì chỉ lấy báo cáo cùng ngân hàng hoặc báo cáo không rõ ngân hàng
  const list = rows.filter((r) => !blocked.has(r.user_id) && (!bin || !r.bin || r.bin === bin));
  const out = [];
  for (const r of list) {
    const ph = (await env.DB.prepare('SELECT id FROM scam_photos WHERE report_id = ? AND public = 1 AND masked = 1').bind(r.id).all()).results || [];
    out.push({
      id: r.id,
      bin: r.bin,
      holder: r.holder,
      channel: r.channel,
      body: r.body,
      amount: r.amount,
      happened: r.happened,
      at: r.created,
      photos: ph.map((p) => p.id),
    });
  }
  return out;
}

export async function handleScam(req, env, url, userId, h) {
  const path = url.pathname.slice('/api/scam'.length);
  await ensureScamSchema(env);

  if (req.method === 'GET' && path === '/check') {
    const acct = normAcct(url.searchParams.get('acct'));
    const bin = normBin(url.searchParams.get('bin'));
    if (acct.length < 4) return h.json({ error: 'Số tài khoản không hợp lệ' }, 400);
    const reports = await publicReports(env, acct, bin, userId);
    const people = new Set(
      (
        (
          await env.DB.prepare(`SELECT user_id FROM scam_reports WHERE acct = ? AND status = 'approved' AND created > ?`)
            .bind(acct, Date.now() - KEEP)
            .all()
        ).results || []
      ).map((r) => r.user_id)
    ).size;
    return h.json({ acct, bin, count: reports.length, people, reports, checkedAt: Date.now() });
  }

  if (req.method === 'GET' && path === '/photo') {
    const id = Number(url.searchParams.get('id'));
    const p = await env.DB.prepare(
      `SELECT p.img FROM scam_photos p JOIN scam_reports r ON r.id = p.report_id
       WHERE p.id = ? AND p.public = 1 AND p.masked = 1 AND r.status = 'approved'`
    )
      .bind(id)
      .first();
    return p ? h.json({ img: p.img }) : h.json({ error: 'Không có ảnh' }, 404);
  }

  if (userId == null) return h.json({ error: 'Cần đăng nhập để dùng chức năng này' }, 401);
  const b = req.method === 'POST' ? await h.readJson(req) : null;

  if (req.method === 'POST' && path === '/report') {
    if (b?.agree !== true) return h.json({ error: 'Bạn cần đồng ý điều khoản báo cáo' }, 400);
    const acct = normAcct(b.acct);
    const bin = normBin(b.bin);
    const body = str(b.body, 2000);
    if (acct.length < 4) return h.json({ error: 'Số tài khoản không hợp lệ' }, 400);
    if (body.length < 20) return h.json({ error: 'Mô tả sự việc cụ thể hơn (ít nhất 20 ký tự)' }, 400);
    const photos = Array.isArray(b.photos) ? b.photos.filter((x) => typeof x === 'string' && x.length > 100) : [];
    if (!photos.length) return h.json({ error: 'Cần ít nhất 1 ảnh bằng chứng' }, 400);
    if (photos.length > 5) return h.json({ error: 'Tối đa 5 ảnh' }, 400);
    if (photos.some((x) => x.length > MAX_PHOTO)) return h.json({ error: 'Ảnh quá lớn' }, 400);
    const today = await env.DB.prepare('SELECT COUNT(*) AS n FROM scam_reports WHERE user_id = ? AND created > ?')
      .bind(userId, Date.now() - DAY)
      .first();
    if ((today?.n || 0) >= 5) return h.json({ error: 'Mỗi ngày chỉ gửi được tối đa 5 báo cáo' }, 429);
    const dup = await env.DB.prepare(`SELECT id FROM scam_reports WHERE user_id = ? AND acct = ? AND status IN ('pending', 'approved')`)
      .bind(userId, acct)
      .first();
    if (dup) return h.json({ error: 'Bạn đã báo cáo tài khoản này rồi' }, 409);
    const channel = CHANNELS.includes(b.channel) ? b.channel : 'khac';
    const r = await env.DB.prepare(
      'INSERT INTO scam_reports (bin, acct, holder, channel, body, amount, happened, user_id, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(bin, acct, str(b.holder, 80), channel, body, Math.max(0, Math.min(1e13, Number(b.amount) || 0)), str(b.happened, 10), userId, Date.now())
      .run();
    const id = r.meta.last_row_id;
    for (const img of photos) await env.DB.prepare('INSERT INTO scam_photos (report_id, img) VALUES (?, ?)').bind(id, img).run();
    return h.json({ ok: true, id });
  }

  if (req.method === 'GET' && path === '/mine') {
    const rows =
      (
        await env.DB.prepare('SELECT id, bin, acct, channel, status, note, created, reviewed FROM scam_reports WHERE user_id = ? ORDER BY id DESC LIMIT 50')
          .bind(userId)
          .all()
      ).results || [];
    const ap =
      (
        await env.DB.prepare('SELECT id, bin, acct, status, reply, created FROM scam_appeals WHERE user_id = ? ORDER BY id DESC LIMIT 20')
          .bind(userId)
          .all()
      ).results || [];
    return h.json({ reports: rows, appeals: ap });
  }

  if (req.method === 'POST' && path === '/appeal') {
    const acct = normAcct(b?.acct);
    const body = str(b?.body, 2000);
    if (acct.length < 4) return h.json({ error: 'Số tài khoản không hợp lệ' }, 400);
    if (body.length < 20) return h.json({ error: 'Trình bày rõ hơn (ít nhất 20 ký tự)' }, 400);
    const open = await env.DB.prepare(`SELECT id FROM scam_appeals WHERE user_id = ? AND acct = ? AND status = 'open'`).bind(userId, acct).first();
    if (open) return h.json({ error: 'Khiếu nại trước của bạn đang được xem xét' }, 409);
    await env.DB.prepare('INSERT INTO scam_appeals (bin, acct, user_id, contact, body, created) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(normBin(b?.bin), acct, userId, str(b?.contact, 120), body, Date.now())
      .run();
    return h.json({ ok: true });
  }

  if (req.method === 'POST' && path === '/flag') {
    const id = Number(b?.report);
    if (!id) return h.json({ error: 'Thiếu báo cáo' }, 400);
    await env.DB.prepare('INSERT INTO scam_flags (report_id, user_id, reason, created) VALUES (?, ?, ?, ?)')
      .bind(id, userId, str(b?.reason, 500), Date.now())
      .run();
    return h.json({ ok: true });
  }

  if (req.method === 'POST' && path === '/block') {
    const r = await env.DB.prepare('SELECT user_id FROM scam_reports WHERE id = ?').bind(Number(b?.report)).first();
    if (!r) return h.json({ error: 'Không tìm thấy' }, 404);
    if (r.user_id === userId) return h.json({ error: 'Đây là báo cáo của bạn' }, 400);
    await env.DB.prepare('INSERT OR IGNORE INTO scam_blocks (user_id, reporter) VALUES (?, ?)').bind(userId, r.user_id).run();
    return h.json({ ok: true });
  }

  return null;
}

// ---------------- Admin ----------------
export async function scamAdmin(env, adminId, method, path, url, b, h, log) {
  await ensureScamSchema(env);
  if (method === 'GET' && path === '/scam') {
    const st = ['pending', 'approved', 'rejected', 'hidden'].includes(url.searchParams.get('status')) ? url.searchParams.get('status') : 'pending';
    const rows =
      (
        await env.DB.prepare(
          `SELECT r.*, u.email FROM scam_reports r LEFT JOIN users u ON u.id = r.user_id WHERE r.status = ? ORDER BY r.id ${st === 'pending' ? 'ASC' : 'DESC'} LIMIT 40`
        )
          .bind(st)
          .all()
      ).results || [];
    for (const r of rows) {
      r.photos = (await env.DB.prepare('SELECT id, public, masked FROM scam_photos WHERE report_id = ?').bind(r.id).all()).results || [];
      const o = await env.DB.prepare(`SELECT COUNT(*) AS n FROM scam_reports WHERE acct = ? AND status = 'approved'`).bind(r.acct).first();
      r.others = o?.n || 0;
    }
    const counts = {};
    for (const x of (await env.DB.prepare('SELECT status, COUNT(*) AS n FROM scam_reports GROUP BY status').all()).results || []) counts[x.status] = x.n;
    const flags =
      (
        await env.DB.prepare(
          'SELECT f.*, r.acct, r.body FROM scam_flags f LEFT JOIN scam_reports r ON r.id = f.report_id WHERE f.done = 0 ORDER BY f.id DESC LIMIT 50'
        ).all()
      ).results || [];
    const appeals =
      (
        await env.DB.prepare(
          `SELECT a.*, u.email FROM scam_appeals a LEFT JOIN users u ON u.id = a.user_id WHERE a.status = 'open' ORDER BY a.id ASC LIMIT 50`
        ).all()
      ).results || [];
    return h.json({ reports: rows, counts, flags, appeals });
  }
  if (method === 'GET' && path === '/scam-photo') {
    const p = await env.DB.prepare('SELECT img FROM scam_photos WHERE id = ?').bind(Number(url.searchParams.get('id'))).first();
    return p ? h.json({ img: p.img }) : h.json({ error: 'Không có ảnh' }, 404);
  }
  if (method === 'POST' && path === '/scam-photo') {
    // Lưu bản đã che thông tin và bật / tắt công khai
    const id = Number(b?.id);
    if (typeof b?.img === 'string' && b.img.length > 100) {
      if (b.img.length > MAX_PHOTO * 1.5) return h.json({ error: 'Ảnh quá lớn' }, 400);
      await env.DB.prepare('UPDATE scam_photos SET img = ?, masked = 1 WHERE id = ?').bind(b.img, id).run();
    }
    if (b?.masked === true) await env.DB.prepare('UPDATE scam_photos SET masked = 1 WHERE id = ?').bind(id).run();
    if (typeof b?.public === 'boolean') await env.DB.prepare('UPDATE scam_photos SET public = ? WHERE id = ?').bind(b.public ? 1 : 0, id).run();
    return h.json({ ok: true });
  }
  if (method === 'POST' && path === '/scam') {
    const id = Number(b?.id);
    const status = { approve: 'approved', reject: 'rejected', hide: 'hidden', pending: 'pending' }[b?.action];
    if (!status) return h.json({ error: 'Thao tác không hợp lệ' }, 400);
    if (status === 'approved') {
      const bad = await env.DB.prepare('SELECT COUNT(*) AS n FROM scam_photos WHERE report_id = ? AND public = 1 AND masked = 0').bind(id).first();
      if (bad?.n) return h.json({ error: 'Còn ảnh công khai chưa che thông tin. Che hoặc tắt công khai trước khi duyệt.' }, 400);
    }
    const fields = ['status = ?', 'reviewed = ?', 'reviewer = ?'];
    const vals = [status, Date.now(), adminId];
    if (typeof b?.note === 'string') {
      fields.push('note = ?');
      vals.push(str(b.note, 500));
    }
    if (typeof b?.body === 'string' && b.body.trim()) {
      // admin có thể bỏ bớt chi tiết cá nhân trong mô tả trước khi công khai
      fields.push('body = ?');
      vals.push(str(b.body, 2000));
    }
    if (typeof b?.holder === 'string') {
      fields.push('holder = ?');
      vals.push(str(b.holder, 80));
    }
    await env.DB.prepare(`UPDATE scam_reports SET ${fields.join(', ')} WHERE id = ?`).bind(...vals, id).run();
    await log(env, adminId, 'scam ' + status, '#' + id);
    return h.json({ ok: true });
  }
  if (method === 'POST' && path === '/scam-flag') {
    await env.DB.prepare('UPDATE scam_flags SET done = 1 WHERE id = ?').bind(Number(b?.id)).run();
    return h.json({ ok: true });
  }
  if (method === 'POST' && path === '/scam-appeal') {
    const id = Number(b?.id);
    const a = await env.DB.prepare('SELECT * FROM scam_appeals WHERE id = ?').bind(id).first();
    if (!a) return h.json({ error: 'Không tìm thấy' }, 404);
    const status = b?.status === 'accepted' ? 'accepted' : 'rejected';
    await env.DB.prepare('UPDATE scam_appeals SET status = ?, reply = ? WHERE id = ?').bind(status, str(b?.reply, 1000), id).run();
    if (status === 'accepted') {
      // Khiếu nại đúng: ẩn mọi báo cáo đang công khai của tài khoản này
      await env.DB.prepare(`UPDATE scam_reports SET status = 'hidden', reviewed = ?, reviewer = ?, note = 'Ẩn do khiếu nại hợp lệ' WHERE acct = ? AND status = 'approved'`)
        .bind(Date.now(), adminId, a.acct)
        .run();
    }
    await log(env, adminId, 'scam-appeal ' + status, a.acct);
    return h.json({ ok: true });
  }
  return null;
}

// Xóa tài khoản người dùng: bỏ báo cáo chưa duyệt; báo cáo đã duyệt giữ lại (không gắn danh tính) để cảnh báo người khác
export async function scamWipe(env, userId) {
  await ensureScamSchema(env);
  const pend = (await env.DB.prepare(`SELECT id FROM scam_reports WHERE user_id = ? AND status != 'approved'`).bind(userId).all()).results || [];
  for (const r of pend) {
    await env.DB.prepare('DELETE FROM scam_photos WHERE report_id = ?').bind(r.id).run();
    await env.DB.prepare('DELETE FROM scam_reports WHERE id = ?').bind(r.id).run();
  }
  await env.DB.prepare('UPDATE scam_reports SET user_id = 0 WHERE user_id = ?').bind(userId).run();
  await env.DB.prepare('DELETE FROM scam_appeals WHERE user_id = ?').bind(userId).run();
  await env.DB.prepare('DELETE FROM scam_blocks WHERE user_id = ? OR reporter = ?').bind(userId, userId).run();
  await env.DB.prepare('UPDATE scam_flags SET user_id = NULL WHERE user_id = ?').bind(userId).run();
}
