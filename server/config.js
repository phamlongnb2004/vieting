// Cấu hình động cho app + AI: từ điển, giọng trợ lý theo dịp, thử thách, gói định kỳ, tỷ giá, lãi suất,
// gói Pro / mã khuyến mãi, góp ý / báo lỗi. Tác giả: Phạm Thành Long (thlong)

export const DEFAULT_TONES = {
  gentle: 'Giọng nhẹ nhàng, đồng cảm, động viên, không phán xét; khi người dùng tiêu quá tay thì gợi ý điều chỉnh nhẹ nhàng.',
  funny: 'Giọng hài hước, cà khịa nhẹ kiểu bạn thân, dùng vài emoji, nhưng vẫn đưa lời khuyên hữu ích; không xúc phạm.',
  strict: 'Giọng nghiêm khắc kiểu "mẹ mắng" khi người dùng tiêu hoang (VD chốt đơn Shopee), thẳng thắn, ngắn gọn; vẫn tôn trọng, không xúc phạm.',
  expert: 'Giọng chuyên gia tài chính: điềm tĩnh, dựa trên số liệu, đưa con số và quy tắc cụ thể (VD quy tắc 50/30/20, quỹ dự phòng 3–6 tháng), ngắn gọn, không phán xét.',
};

// from/to dạng MM-DD (giờ Việt Nam). payday: áp dụng khi app báo hôm nay gần ngày nhận lương.
export const DEFAULT_OCCASIONS = [
  { name: 'Tết Nguyên Đán', from: '01-20', to: '02-20', note: 'Đang mùa Tết: nhắc chuẩn bị tiền lì xì, quà biếu; khuyên đặt ngân sách Tết riêng và tránh tiêu quá tay đầu năm.' },
  { name: 'Sale 11.11', from: '11-09', to: '11-12', note: 'Đang mùa sale 11.11: nhắc người dùng chỉ mua món đã nằm trong danh sách chờ 48 giờ.' },
  { name: 'Black Friday', from: '11-24', to: '11-30', note: 'Đang mùa Black Friday: nhắc kiểm tra xem có thật sự cần không, so giá trước khi chốt đơn.' },
  { name: 'Sale 12.12', from: '12-10', to: '12-13', note: 'Đang mùa sale 12.12: nhắc giữ ngân sách mua sắm cuối năm.' },
  { name: 'Ngày nhận lương', payday: true, note: 'Người dùng vừa nhận lương: chúc mừng và nhắc trích tiền tiết kiệm / cất vào hũ trước khi tiêu.' },
];

// Nhắc tự động trên máy người dùng (app tự hẹn giờ, admin chỉnh lời & mốc)
export const DEFAULT_SMART = {
  daily: { on: true, hour: 21, title: 'Hôm nay tiêu gì rồi?', body: 'Dành 10 giây ghi lại chi tiêu hôm nay để cuối tháng không bất ngờ nhé.' },
  comeback: { on: true, days: 3, title: 'Lâu rồi không gặp', body: 'Ví của bạn vẫn đang chờ. Mở VieTing xem tuần này đã tiêu bao nhiêu nhé — chỉ mất 1 phút.' },
  bill: { on: true, before: 1, title: 'Sắp trừ tiền: {name}', body: '{amount} sẽ bị trừ ngày mai. Không dùng nữa thì hủy kịp nhé.' },
  wish: { on: true, title: 'Đủ 48 giờ rồi: {name}', body: 'Bạn còn muốn mua không? Mở VieTing để quyết định.' },
  gift: { on: true, title: 'Sắp tới dịp của {name}', body: 'Xem lần trước đã mừng bao nhiêu để chuẩn bị phong bì.' },
  payday: { on: true, title: 'Hôm nay nhận lương', body: 'Trích tiền tiết kiệm trước khi tiêu nhé — cây tre của bạn đang chờ lớn.' },
};

// Lượt hỏi trợ lý mỗi ngày (tính theo ngày Việt Nam)
export const CHAT_FREE = 30;
export const CHAT_PRO = 300;

export function chatKey(userId, req) {
  return 'chat:' + (userId != null ? 'u' + userId : 'ip' + (req.headers.get('cf-connecting-ip') || '?'));
}

/** Còn bao nhiêu tin nhắn trợ lý hôm nay (không trừ lượt). */
export async function chatQuota(env, userId, req, plan) {
  const pro = plan?.plan === 'pro';
  const limit = pro ? CHAT_PRO : CHAT_FREE;
  let used = 0;
  try {
    used = (await env.DB.prepare('SELECT n FROM ai_usage WHERE k = ? AND day = ?').bind(chatKey(userId, req), vnToday()).first())?.n || 0;
  } catch {}
  return { limit, left: Math.max(0, limit - used), pro };
}

export const DEFAULT_RATES = { saving6: 4.5, saving12: 5.0, note: 'Lãi suất tiết kiệm tham khảo (%/năm), admin cập nhật' };

const FX_CODES = ['USD', 'EUR', 'JPY', 'KRW', 'CNY', 'THB', 'SGD', 'GBP', 'AUD', 'TWD', 'HKD', 'MYR'];
const DAY = 86400000;

export async function getConfig(env, k, fallback) {
  try {
    const r = await env.DB.prepare('SELECT v FROM config WHERE k = ?').bind(k).first();
    return r ? JSON.parse(r.v) : fallback;
  } catch {
    return fallback;
  }
}

export async function setConfig(env, k, v) {
  await env.DB.prepare('INSERT INTO config (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v')
    .bind(k, JSON.stringify(v))
    .run();
}

export function vnToday() {
  return new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
}

/** Dịp đặc biệt đang diễn ra (theo ngày VN), có tính "ngày nhận lương" nếu app báo. */
export function currentOccasions(occasions, today, payday) {
  const md = today.slice(5);
  return (occasions || []).filter((o) => {
    if (o.payday) return !!payday;
    if (!o.from || !o.to) return false;
    return o.from <= o.to ? md >= o.from && md <= o.to : md >= o.from || md <= o.to;
  });
}

let aiCache = { at: 0, v: null };
/** Phần bổ sung cho prompt AI: giọng theo cấu hình admin, dịp đặc biệt, từ điển. Lưu tạm 60 giây. */
export async function aiExtras(env) {
  if (aiCache.v && Date.now() - aiCache.at < 60000) return aiCache.v;
  const [tones, occasions, dictRows] = await Promise.all([
    getConfig(env, 'tones', DEFAULT_TONES),
    getConfig(env, 'occasions', DEFAULT_OCCASIONS),
    env.DB.prepare('SELECT keyword, category, note FROM dict ORDER BY id LIMIT 400')
      .all()
      .then((r) => r.results || [])
      .catch(() => []),
  ]);
  aiCache = { at: Date.now(), v: { tones: { ...DEFAULT_TONES, ...tones }, occasions, dict: dictRows } };
  return aiCache.v;
}

export function dictText(dict) {
  if (!dict?.length) return '';
  return (
    'TỪ ĐIỂN TIẾNG VIỆT (từ lóng / thương hiệu -> mã danh mục): ' +
    dict.map((d) => `"${d.keyword}"${d.note ? ' (' + d.note + ')' : ''} -> ${d.category}`).join('; ')
  );
}

export async function planOf(env, userId) {
  if (userId == null) return { plan: 'free', until: 0 };
  try {
    const r = await env.DB.prepare('SELECT plan, until FROM plans WHERE user_id = ?').bind(userId).first();
    if (r && r.until > Date.now()) return { plan: r.plan, until: r.until };
  } catch {}
  return { plan: 'free', until: 0 };
}

export async function grantPro(env, userId, days, note) {
  const cur = await planOf(env, userId);
  const base = cur.plan === 'pro' ? cur.until : Date.now();
  const until = base + days * DAY;
  await env.DB.prepare(
    `INSERT INTO plans (user_id, plan, until, note) VALUES (?, 'pro', ?, ?)
     ON CONFLICT (user_id) DO UPDATE SET plan = 'pro', until = excluded.until, note = excluded.note`
  )
    .bind(userId, until, String(note || '').slice(0, 200))
    .run();
  return until;
}

/** Tỷ giá: 1 đơn vị ngoại tệ = ? đồng. Tự lấy từ open.er-api.com (miễn phí), lưu 6 giờ. */
export async function fxRates(env, force = false) {
  const cached = await getConfig(env, 'fx', null);
  if (!force && cached && Date.now() - cached.at < 6 * 3600000) return cached;
  try {
    const r = await fetch('https://open.er-api.com/v6/latest/VND', { cf: { cacheTtl: 3600 } });
    const j = await r.json();
    if (j?.result !== 'success' || !j.rates) throw new Error('fx');
    const rates = {};
    for (const c of FX_CODES) if (j.rates[c]) rates[c] = Math.round((1 / j.rates[c]) * 100) / 100;
    const v = { at: Date.now(), source: 'open.er-api.com', rates };
    await setConfig(env, 'fx', v);
    return v;
  } catch {
    return cached || { at: 0, source: '', rates: {} };
  }
}

/** GET /api/config: mọi thứ app cần tải về (không cần cập nhật app). */
export async function publicConfig(req, env, userId, h) {
  const now = Date.now();
  const q = (sql, ...b) =>
    env.DB.prepare(sql)
      .bind(...b)
      .all()
      .then((r) => r.results || [])
      .catch(() => []);
  const [dict, campaigns, catalog, notice, rates, fx, plan, unread, smart] = await Promise.all([
    q('SELECT keyword AS k, category AS c FROM dict ORDER BY length(keyword) DESC LIMIT 1000'),
    q(
      'SELECT id, kind, title, emoji, body, keywords, category, days, target, start, end FROM campaigns WHERE active = 1 AND end > ? AND start < ? ORDER BY start',
      now,
      now + 14 * DAY
    ),
    q('SELECT name, amount, cycle, category FROM catalog ORDER BY sort, name'),
    env.DB.prepare('SELECT id, title, body, level FROM notices WHERE active = 1 ORDER BY id DESC LIMIT 1')
      .first()
      .catch(() => null),
    getConfig(env, 'rates', DEFAULT_RATES),
    fxRates(env),
    planOf(env, userId),
    userId == null
      ? Promise.resolve(0)
      : env.DB.prepare("SELECT COUNT(*) AS n FROM tickets WHERE user_id = ? AND seen = 0")
          .bind(userId)
          .first()
          .then((r) => r?.n || 0)
          .catch(() => 0),
    getConfig(env, 'smart', DEFAULT_SMART),
  ]);
  const chat = await chatQuota(env, userId, req, plan);
  return h.json({ dict, campaigns, catalog, notice: notice || null, rates, fx, plan, ticketsUnread: unread, smart: { ...DEFAULT_SMART, ...smart }, chat });
}

/** POST /api/redeem {code} */
export async function redeem(req, env, userId, h) {
  if (userId == null) return h.json({ error: 'Đăng nhập để dùng mã' }, 401);
  const b = await h.readJson(req);
  const code = String(b?.code || '').trim().toUpperCase();
  if (!code) return h.json({ error: 'Chưa nhập mã' }, 400);
  const v = await env.DB.prepare('SELECT * FROM vouchers WHERE code = ?').bind(code).first();
  if (!v) return h.json({ error: 'Mã không đúng' }, 404);
  if (v.expires && v.expires < Date.now()) return h.json({ error: 'Mã đã hết hạn' }, 410);
  if (v.used >= v.max_uses) return h.json({ error: 'Mã đã được dùng hết lượt' }, 410);
  const usedBefore = await env.DB.prepare('SELECT 1 AS x FROM voucher_uses WHERE code = ? AND user_id = ?').bind(code, userId).first();
  if (usedBefore) return h.json({ error: 'Bạn đã dùng mã này rồi' }, 409);
  const upd = await env.DB.prepare('UPDATE vouchers SET used = used + 1 WHERE code = ? AND used < max_uses').bind(code).run();
  if (!upd.meta?.changes) return h.json({ error: 'Mã đã được dùng hết lượt' }, 410);
  await env.DB.prepare('INSERT INTO voucher_uses (code, user_id, created) VALUES (?, ?, ?)').bind(code, userId, Date.now()).run();
  const until = await grantPro(env, userId, v.days, 'Mã ' + code);
  return h.json({ ok: true, days: v.days, plan: { plan: 'pro', until } });
}

const FEATURES = ['doc_thong_bao', 'giong_noi', 'hoa_don', 'tro_ly', 'dong_bo', 'so_chung', 'ngan_sach', 'giao_dien', 'thanh_toan', 'khac'];

/** POST /api/ticket {feature, body, contact, app} */
export async function createTicket(req, env, userId, h) {
  const b = await h.readJson(req);
  const body = String(b?.body || '').trim().slice(0, 3000);
  if (body.length < 5) return h.json({ error: 'Viết thêm chút nội dung nhé' }, 400);
  const feature = FEATURES.includes(b?.feature) ? b.feature : 'khac';
  if (userId == null) {
    const ip = req.headers.get('cf-connecting-ip') || '?';
    const day = vnToday();
    await env.DB.prepare(`INSERT INTO ai_usage (k, day, n) VALUES (?, ?, 1) ON CONFLICT (k, day) DO UPDATE SET n = n + 1`)
      .bind('tk' + ip, day)
      .run();
    const r = await env.DB.prepare('SELECT n FROM ai_usage WHERE k = ? AND day = ?').bind('tk' + ip, day).first();
    if (r && r.n > 10) return h.json({ error: 'Gửi quá nhiều, thử lại mai nhé' }, 429);
  }
  const now = Date.now();
  await env.DB.prepare(
    'INSERT INTO tickets (user_id, contact, feature, body, app, status, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  )
    .bind(userId, String(b?.contact || '').slice(0, 120), feature, body, String(b?.app || '').slice(0, 80), 'open', now, now)
    .run();
  return h.json({ ok: true });
}

/** GET /api/tickets: phiếu của tôi + đánh dấu đã đọc phản hồi */
export async function myTickets(req, env, userId, h) {
  if (userId == null) return h.json({ tickets: [] });
  const rows =
    (
      await env.DB.prepare('SELECT id, feature, body, status, reply, created, updated, seen FROM tickets WHERE user_id = ? ORDER BY id DESC LIMIT 50')
        .bind(userId)
        .all()
    ).results || [];
  await env.DB.prepare('UPDATE tickets SET seen = 1 WHERE user_id = ? AND seen = 0').bind(userId).run();
  return h.json({ tickets: rows });
}

/** POST /api/ocr-report {ai:{amount,category,note}, fixed:{...}, comment}: không có ảnh. */
export async function ocrReport(req, env, userId, h) {
  const b = await h.readJson(req);
  const pick = (o) => ({
    amount: Number(o?.amount) || 0,
    category: String(o?.category || '').slice(0, 40),
    income: !!o?.income,
    note: String(o?.note || '').slice(0, 120),
  });
  await env.DB.prepare('INSERT INTO ocr_reports (user_id, ai, fixed, comment, created) VALUES (?, ?, ?, ?, ?)')
    .bind(userId, JSON.stringify(pick(b?.ai)), JSON.stringify(pick(b?.fixed)), String(b?.comment || '').slice(0, 500), Date.now())
    .run();
  return h.json({ ok: true });
}

/** GET /api/push?after=<id>: máy Android hỏi định kỳ. Chỉ trả tin trong 3 ngày gần nhất. */
export async function pushFeed(req, env, userId, h) {
  const url = new URL(req.url);
  const after = Number(url.searchParams.get('after'));
  const latest = (await env.DB.prepare('SELECT MAX(id) AS id FROM pushes').first().catch(() => null))?.id || 0;
  let pushes = [];
  if (after >= 0) {
    pushes =
      (
        await env.DB.prepare('SELECT id, title, body FROM pushes WHERE id > ? AND created > ? ORDER BY id LIMIT 5')
          .bind(after, Date.now() - 3 * 86400000)
          .all()
          .catch(() => ({ results: [] }))
      ).results || [];
  }
  let ticketAt = 0;
  if (userId != null) {
    ticketAt =
      (await env.DB.prepare("SELECT MAX(updated) AS t FROM tickets WHERE user_id = ? AND seen = 0 AND reply != ''").bind(userId).first().catch(() => null))?.t || 0;
  }
  return h.json({ latest, pushes, ticketAt });
}
