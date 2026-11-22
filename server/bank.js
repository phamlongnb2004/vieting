// Quỹ chung nối thẳng ngân hàng qua SePay: server tự đọc giao dịch của tài khoản quỹ, nên tiền vào được
// xác nhận bởi chính ngân hàng (không cần ảnh, không cần thủ quỹ bấm), tiền ra bị báo cho cả nhóm ngay,
// và số dư thật được so với số quỹ phải có. Khóa API do thủ quỹ tự tạo trên SePay, chỉ nằm trên server.
// Tác giả: Phạm Thành Long (thlong)

const SEPAY = 'https://userapi.sepay.vn/v2/transactions'; // SePay API v2
const vnd = (n) => Number(n || 0).toLocaleString('vi-VN') + ' ₫';
const fold = (t) =>
  String(t || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');

/** "2026-11-22 20:15:03" (giờ Việt Nam) hoặc ISO có +07:00 → ms */
function vnTime(s) {
  const t = String(s || '');
  if (/[+-]\d{2}:\d{2}$|Z$/.test(t)) return Date.parse(t) || Date.now();
  const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/.exec(t);
  if (!m) return Date.now();
  return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0)) - 7 * 3600000;
}

function vnStamp(ms) {
  const d = new Date(ms + 7 * 3600000).toISOString();
  return d.slice(0, 10) + ' ' + d.slice(11, 19);
}

/**
 * Đọc giao dịch SePay v2. Có sinceId: lấy các giao dịch ghi nhận sau đó (cũ → mới, đọc hết các trang).
 * Chưa có: chỉ lấy từ [fromMs] để không kéo cả lịch sử tài khoản.
 */
export async function sepayList(token, { sinceId = '', fromMs = 0, maxPages = 5 } = {}) {
  const out = [];
  for (let page = 1; page <= maxPages; page++) {
    const u = new URL(SEPAY);
    u.searchParams.set('per_page', '100');
    u.searchParams.set('page', String(page));
    u.searchParams.set('transaction_date_sort', 'asc');
    if (sinceId) u.searchParams.set('since_id', sinceId);
    else if (fromMs) u.searchParams.set('transaction_date_from', vnStamp(fromMs));
    const r = await fetch(u, { headers: { authorization: 'Bearer ' + token, accept: 'application/json' } });
    const j = await r.json().catch(() => null);
    if (!r.ok || !j || j.status === 'error') {
      const e = new Error(
        r.status === 401
          ? 'Khóa API SePay sai, đã bị tắt hoặc thu hồi'
          : r.status === 429
            ? 'SePay đang giới hạn tốc độ, thử lại sau'
            : `SePay lỗi ${r.status}${j?.message ? ': ' + j.message : ''}`
      );
      e.status = r.status;
      throw e;
    }
    for (const t of j.data || []) {
      out.push({
        bid: String(t.id),
        acct: String(t.account_number || ''),
        in: Math.round(Number(t.amount_in) || 0),
        out: Math.round(Number(t.amount_out) || 0),
        // accumulated = số dư sau giao dịch (bằng 0 với giao dịch QR tĩnh NAPAS: bỏ qua)
        balance: t.accumulated == null || Number(t.accumulated) === 0 ? null : Math.round(Number(t.accumulated)),
        content: String(t.transaction_content || '').slice(0, 300),
        at: vnTime(t.transaction_date),
      });
    }
    if (!j.meta?.pagination?.has_more) break;
    await new Promise((res) => setTimeout(res, 400)); // tối đa 3 lần / giây
  }
  return out;
}

/**
 * Đọc giao dịch mới của tài khoản quỹ, khớp tiền nộp, báo tiền ra.
 * h: { getSettings, putSettings, logStmt } từ space.js. Trả về settings mới.
 */
export async function syncBank(env, spaceId, h, { force = false } = {}) {
  const link = await env.DB.prepare('SELECT provider, token FROM space_bank WHERE space_id = ?').bind(spaceId).first().catch(() => null);
  if (!link) return null;
  const st = await h.getSettings(env, spaceId);
  const bl = st.bankLink || {};
  if (!force && bl.lastSync && Date.now() - bl.lastSync < 60000) return st;
  const acct = st.bank?.acct || '';
  const sp = await env.DB.prepare('SELECT code FROM spaces WHERE id = ?').bind(spaceId).first();
  let list;
  try {
    list = await sepayList(link.token, { sinceId: bl.lastId || '', fromMs: bl.since || Date.now() - 86400000 });
  } catch (e) {
    const first = !bl.error;
    st.bankLink = { ...bl, lastSync: Date.now(), error: e.message };
    await h.putSettings(env, spaceId, st);
    if (first) await h.logStmt(env, spaceId, 0, '', 'bankerr', `MẤT KẾT NỐI NGÂN HÀNG: ${e.message}. Số dư quỹ tạm thời không được ngân hàng xác thực`).run();
    return st;
  }
  // cùng khóa SePay có thể có nhiều tài khoản: chỉ lấy tài khoản quỹ. Con trỏ vẫn đi theo mọi giao dịch.
  const all = list;
  list = list.filter((t) => !acct || t.acct === acct);
  const stmts = [];
  let lastId = all.length ? all[all.length - 1].bid : bl.lastId || '';
  let balance = bl.balance ?? null;
  let balanceAt = bl.balanceAt || 0;
  const code = fold('VT' + (sp?.code || ''));
  // các khoản nộp đang chờ của quỹ
  const pending =
    (
      await env.DB.prepare("SELECT id, data FROM space_records WHERE space_id = ? AND deleted = 0").bind(spaceId).all()
    ).results || [];
  const waiting = pending
    .map((r) => ({ id: r.id, d: JSON.parse(r.data || '{}') }))
    .filter((r) => r.d.type === 'contrib');
  const used = new Set(
    ((await env.DB.prepare("SELECT rec_id FROM space_bank_txns WHERE space_id = ? AND rec_id != ''").bind(spaceId).all()).results || []).map((r) => r.rec_id)
  );
  for (const t of list) {
    if (t.balance != null && t.at >= balanceAt) {
      balance = t.balance;
      balanceAt = t.at;
    }
    const exists = await env.DB.prepare('SELECT 1 AS x FROM space_bank_txns WHERE space_id = ? AND bid = ?').bind(spaceId, t.bid).first();
    if (exists) continue;
    let rec = '';
    const memo = fold(t.content);
    if (t.in > 0) {
      const hit =
        waiting.find((r) => !used.has(r.id) && r.d.tag && memo.includes(code + fold(r.d.tag)) && Math.round(r.d.amount) === t.in) ||
        (memo.includes(code) ? waiting.find((r) => !used.has(r.id) && !r.d.tag && Math.round(r.d.amount) === t.in) : null);
      if (hit) {
        rec = hit.id;
        used.add(hit.id);
        stmts.push(
          env.DB.prepare(
            'INSERT INTO space_marks (space_id, rec_id, user_id, kind, at) VALUES (?, ?, 0, ?, ?) ON CONFLICT (space_id, rec_id, user_id) DO UPDATE SET kind = excluded.kind, at = excluded.at'
          ).bind(spaceId, hit.id, 'bank', Date.now()),
          env.DB.prepare('UPDATE space_records SET srv = ? WHERE space_id = ? AND id = ?').bind(Date.now(), spaceId, hit.id),
          h.logStmt(env, spaceId, 0, hit.id, 'bankin', `Ngân hàng xác nhận tiền nộp ${vnd(t.in)} đã về tài khoản quỹ`)
        );
      } else if (memo.includes(code)) {
        stmts.push(h.logStmt(env, spaceId, 0, '', 'bankin', `Tài khoản quỹ nhận ${vnd(t.in)} có mã quỹ nhưng không khớp khoản nộp nào · ${t.content.slice(0, 80)}`));
      }
    }
    const ch = st.challenge;
    if (t.out > 0 && ch && !ch.passed && !ch.failed && memo.includes(fold('VTKT' + ch.code))) {
      st.challenge = { ...ch, passed: true, passedAt: Date.now(), how: 'bank' };
      stmts.push(h.logStmt(env, spaceId, 0, '', 'challengeok', `Ngân hàng xác nhận thủ quỹ đã chuyển ${vnd(t.out)} với mã ${ch.code}: đang giữ đúng tài khoản quỹ`));
    } else if (t.out > 0 && t.at >= (bl.linkedAt || 0) - 60000) {
      stmts.push(h.logStmt(env, spaceId, 0, '', 'bankout', `TÀI KHOẢN QUỸ VỪA CHUYỂN RA ${vnd(t.out)} · ${t.content.slice(0, 100)}`));
    }
    stmts.push(
      env.DB.prepare('INSERT OR IGNORE INTO space_bank_txns (space_id, bid, dir, amount, content, balance, at, rec_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)').bind(
        spaceId,
        t.bid,
        t.in > 0 ? 'in' : 'out',
        t.in > 0 ? t.in : t.out,
        t.content,
        t.balance,
        t.at,
        rec
      )
    );
  }
  if (bl.error) stmts.push(h.logStmt(env, spaceId, 0, '', 'bankok', 'Đã kết nối lại ngân hàng'));
  if (stmts.length) await env.DB.batch(stmts);
  st.bankLink = { provider: link.provider, lastSync: Date.now(), lastId, balance, balanceAt, error: null, since: bl.since || Date.now(), linkedAt: bl.linkedAt || 0 };
  await h.putSettings(env, spaceId, st);
  return st;
}

/** Cron: đọc ngân hàng cho mọi quỹ đã nối (để tiền ra được báo cả khi không ai mở app). */
export async function syncAllBanks(env, h) {
  const rows = (await env.DB.prepare('SELECT space_id FROM space_bank ORDER BY at LIMIT 200').all().catch(() => ({ results: [] }))).results || [];
  for (const r of rows) {
    try {
      await syncBank(env, r.space_id, h, { force: true });
    } catch {}
    await new Promise((res) => setTimeout(res, 600)); // SePay: tối đa 2 lần / giây
  }
}
