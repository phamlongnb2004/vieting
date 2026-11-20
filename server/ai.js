// Trợ lý AI của VieTing: POST /api/chat
// Dùng Google Gemini (miễn phí, cần khóa GEMINI_API_KEY) và tự chuyển sang Cloudflare Workers AI
// (miễn phí 10.000 neurons/ngày, không cần khóa) khi chưa có khóa hoặc Gemini báo lỗi / hết lượt.
// Khóa AI chỉ nằm trên server, app không bao giờ thấy.
// Tác giả: Phạm Thành Long (thlong)

const CATS = {
  an_uong: 'Ăn uống', di_lai: 'Đi lại', mua_sam: 'Mua sắm', hoa_don: 'Hóa đơn', nha_o: 'Nhà ở',
  giai_tri: 'Giải trí', suc_khoe: 'Sức khỏe', giao_duc: 'Giáo dục', gia_dinh: 'Gia đình & quà',
  chuyen_di: 'Chuyển khoản đi', khac_chi: 'Chi khác',
  luong: 'Lương (thu)', thuong: 'Thưởng (thu)', dau_tu: 'Lãi & đầu tư (thu)', nhan_tien: 'Nhận chuyển khoản (thu)', khac_thu: 'Thu khác (thu)',
};
const INCOME_CATS = new Set(['luong', 'thuong', 'dau_tu', 'nhan_tien', 'khac_thu']);
const DAILY_LIMIT = 80; // tin nhắn / người / ngày, giữ trong hạn mức miễn phí
const WORKERS_AI_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const WORKERS_AI_FALLBACK = '@cf/meta/llama-3.1-8b-instruct';

function systemPrompt(today) {
  return `Bạn là "Trợ lý VieTing", trợ lý quản lý chi tiêu cá nhân trong app VieTing. Luôn trả lời bằng tiếng Việt, thân thiện, ngắn gọn (tối đa khoảng 120 từ), dùng số liệu cụ thể. Hôm nay là ${today}. Đơn vị tiền: đồng (₫), viết số có dấu chấm ngăn cách hàng nghìn (VD 1.250.000 ₫).

Bạn nhận được TÓM TẮT dữ liệu chi tiêu thật của người dùng trong phần "DỮ LIỆU". Chỉ dựa vào dữ liệu đó, không bịa số liệu. Nếu dữ liệu không đủ để trả lời, nói rõ.

Bạn có thể đề xuất hành động để app thực hiện (người dùng sẽ bấm xác nhận):
- add_txn: ghi một giao dịch khi người dùng kể một khoản chi/thu (VD "ăn phở 45k", "nhận lương 15 triệu"). Hiểu "k" = nghìn, "tr"/"triệu"/"củ" = triệu, "1tr2" = 1.200.000.
- set_budget: đặt hạn mức chi mỗi tháng cho một danh mục, hoặc "all" cho tổng chi.
Không tự đề xuất hành động khi người dùng chỉ hỏi.

Mã danh mục hợp lệ: ${Object.entries(CATS).map(([k, v]) => `${k} (${v})`).join(', ')}.

Chỉ trả về MỘT đối tượng JSON, không thêm chữ nào khác:
{"reply":"câu trả lời","actions":[{"type":"add_txn","amount":45000,"income":false,"category":"an_uong","note":"phở","date":"YYYY-MM-DD"},{"type":"set_budget","category":"an_uong","limit":3000000}]}
"actions" là mảng rỗng nếu không có hành động. "date" bỏ trống nếu là hôm nay.`;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' },
  });
}

/** Lấy đối tượng JSON trong câu trả lời của mô hình (kể cả khi bị bọc trong ```json ... ```). */
export function extractJson(text) {
  if (!text) return null;
  const t = String(text).replace(/```(?:json)?/gi, '').trim();
  try {
    return JSON.parse(t);
  } catch {}
  const a = t.indexOf('{'), b = t.lastIndexOf('}');
  if (a >= 0 && b > a) {
    try {
      return JSON.parse(t.slice(a, b + 1));
    } catch {}
  }
  return null;
}

/** Kiểm tra và làm sạch hành động do AI đề xuất. */
export function cleanActions(list) {
  const out = [];
  for (const a of Array.isArray(list) ? list.slice(0, 5) : []) {
    if (!a || typeof a !== 'object') continue;
    if (a.type === 'add_txn') {
      const amount = Math.round(Number(a.amount));
      if (!(amount > 0 && amount < 1e12)) continue;
      let category = CATS[a.category] ? a.category : null;
      let income = a.income === true || (category != null && INCOME_CATS.has(category));
      if (!category) category = income ? 'khac_thu' : 'khac_chi';
      if (INCOME_CATS.has(category) !== income) income = INCOME_CATS.has(category);
      const date = /^\d{4}-\d{2}-\d{2}$/.test(a.date || '') ? a.date : '';
      out.push({ type: 'add_txn', amount, income, category, note: String(a.note || '').slice(0, 120), date });
    } else if (a.type === 'set_budget') {
      const limit = Math.round(Number(a.limit));
      const category = a.category === 'all' || (CATS[a.category] && !INCOME_CATS.has(a.category)) ? a.category : null;
      if (!category || !(limit >= 0 && limit < 1e12)) continue;
      out.push({ type: 'set_budget', category, limit });
    }
  }
  return out;
}

async function askGemini(env, sys, contents) {
  const model = env.GEMINI_MODEL || 'gemini-2.5-flash';
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: sys }] },
      contents,
      generationConfig: { temperature: 0.3, maxOutputTokens: 1024, responseMimeType: 'application/json' },
    }),
  });
  if (!res.ok) throw new Error('gemini ' + res.status);
  const j = await res.json();
  const text = (j.candidates?.[0]?.content?.parts || []).map((p) => p.text || '').join('');
  return { text, provider: 'gemini' };
}

async function askWorkersAI(env, sys, messages) {
  const msgs = [{ role: 'system', content: sys }, ...messages.map((m) => ({ role: m.role === 'model' ? 'assistant' : 'user', content: m.text }))];
  let r;
  try {
    r = await env.AI.run(WORKERS_AI_MODEL, { messages: msgs, max_tokens: 800, temperature: 0.3 });
  } catch {
    r = await env.AI.run(WORKERS_AI_FALLBACK, { messages: msgs, max_tokens: 800, temperature: 0.3 });
  }
  const text = typeof r?.response === 'string' ? r.response : JSON.stringify(r?.response ?? '');
  return { text, provider: 'workers-ai' };
}

async function underLimit(env, key) {
  if (!env.DB) return true;
  const day = new Date().toISOString().slice(0, 10);
  try {
    await env.DB.prepare(
      `INSERT INTO ai_usage (k, day, n) VALUES (?, ?, 1)
       ON CONFLICT (k, day) DO UPDATE SET n = n + 1`
    ).bind(key, day).run();
    const row = await env.DB.prepare('SELECT n FROM ai_usage WHERE k = ? AND day = ?').bind(key, day).first();
    return !row || row.n <= DAILY_LIMIT;
  } catch {
    return true; // bảng chưa tạo: không chặn
  }
}

export async function handleChat(req, env, userId) {
  if (!env.GEMINI_API_KEY && !env.AI) {
    return json({ error: 'Server chưa bật AI. Chạy dat-khoa-gemini.bat hoặc bật Workers AI.' }, 503);
  }
  let b;
  try {
    b = await req.json();
  } catch {
    return json({ error: 'Dữ liệu không hợp lệ' }, 400);
  }
  const key = userId != null ? 'u' + userId : 'ip' + (req.headers.get('cf-connecting-ip') || '?');
  if (!(await underLimit(env, key))) {
    return json({ error: `Hôm nay bạn đã dùng hết ${DAILY_LIMIT} lượt hỏi trợ lý, mai quay lại nhé.` }, 429);
  }

  const today = /^\d{4}-\d{2}-\d{2}$/.test(b.today || '') ? b.today : new Date().toISOString().slice(0, 10);
  const context = String(b.context || '').slice(0, 12000);
  const history = (Array.isArray(b.messages) ? b.messages : [])
    .filter((m) => m && typeof m.text === 'string' && m.text.trim())
    .slice(-12)
    .map((m) => ({ role: m.role === 'model' ? 'model' : 'user', text: m.text.slice(0, 2000) }));
  if (!history.length || history[history.length - 1].role !== 'user') return json({ error: 'Thiếu câu hỏi' }, 400);

  const sys = systemPrompt(today) + '\n\nDỮ LIỆU:\n' + context;
  let out = null;
  if (env.GEMINI_API_KEY) {
    try {
      out = await askGemini(env, sys, history.map((m) => ({ role: m.role, parts: [{ text: m.text }] })));
    } catch (e) {
      out = null; // hết lượt / lỗi: chuyển sang Workers AI
    }
  }
  if (!out && env.AI) {
    try {
      out = await askWorkersAI(env, sys, history);
    } catch (e) {
      return json({ error: 'Trợ lý AI đang bận, thử lại sau ít phút.' }, 502);
    }
  }
  if (!out) return json({ error: 'Trợ lý AI đang bận, thử lại sau ít phút.' }, 502);

  const parsed = extractJson(out.text);
  const reply = parsed && typeof parsed.reply === 'string' ? parsed.reply : String(out.text || '').trim();
  return json({ reply: reply.slice(0, 4000), actions: cleanActions(parsed?.actions), provider: out.provider });
}
