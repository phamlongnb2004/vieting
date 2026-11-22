import { CHAT_FREE as DAILY_LIMIT, CHAT_PRO as PRO_LIMIT, chatKey, aiExtras, currentOccasions, dictText, planOf, vnToday } from './config.js';
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

const WORKERS_AI_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const WORKERS_AI_FALLBACK = '@cf/meta/llama-3.1-8b-instruct';

const TONES = {
  gentle: 'Giọng nhẹ nhàng, đồng cảm, động viên, không phán xét; khi người dùng tiêu quá tay thì gợi ý điều chỉnh nhẹ nhàng.',
  funny: 'Giọng hài hước, cà khịa nhẹ kiểu bạn thân, dùng vài emoji, nhưng vẫn đưa lời khuyên hữu ích; không xúc phạm.',
  strict: 'Giọng nghiêm khắc kiểu "mẹ mắng" khi người dùng tiêu hoang (VD chốt đơn Shopee), thẳng thắn, ngắn gọn; vẫn tôn trọng, không xúc phạm.',
  expert: 'Giọng chuyên gia tài chính: điềm tĩnh, dựa trên số liệu, đưa con số và quy tắc cụ thể (VD quy tắc 50/30/20, quỹ dự phòng 3–6 tháng), ngắn gọn, không phán xét.',
};

function systemPrompt(today, tone, ex) {
  const tones = ex?.tones || TONES;
  const occ = currentOccasions(ex?.occasions, today, ex?.payday).map((o) => o.note).filter(Boolean).join(' ');
  return `Bạn là "Trợ lý VieTing", trợ lý quản lý chi tiêu cá nhân trong app VieTing. Luôn trả lời bằng tiếng Việt, ngắn gọn (tối đa khoảng 120 từ), dùng số liệu cụ thể. ${tones[tone] || tones.gentle || TONES.gentle} ${occ ? 'DỊP ĐẶC BIỆT: ' + occ + ' ' : ''}Hôm nay là ${today}. Đơn vị tiền: đồng (₫), viết số có dấu chấm ngăn cách hàng nghìn (VD 1.250.000 ₫).

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

// Google hay đổi tên model và cách gọi (khóa "auth key" mới, Interactions API). Lớp gọi Gemini ở đây tự thích nghi:
// 1) hỏi Google danh sách model khóa này dùng được, chọn model Flash mới nhất hỗ trợ generateContent;
// 2) model nào lỗi 404/400 thì thử model kế; 3) nếu generateContent không dùng được thì chuyển sang Interactions API.
// Lỗi thật của Google được lưu lại (bảng config, khóa "ai_error") để xem ở trang /admin.
// Gói miễn phí (11/2026): Flash-Lite 15 lượt/phút, 500 lượt/ngày; Flash chỉ 5 lượt/phút, 20 lượt/ngày -> ưu tiên Lite.
const GEMINI_FALLBACK = ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite', 'gemini-flash-lite-latest', 'gemini-3.8-flash', 'gemini-3.6-flash', 'gemini-flash-latest', 'gemini-2.5-flash-lite'];
const G_BASE = 'https://generativelanguage.googleapis.com';
let modelCache = { at: 0, list: null };

async function googleMsg(res) {
  try {
    const t = await res.text();
    try {
      return String(JSON.parse(t)?.error?.message || t).slice(0, 160);
    } catch {
      return t.slice(0, 160);
    }
  } catch {
    return '';
  }
}

function gHeaders(env) {
  return { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY };
}

function rankModel(n) {
  // ưu tiên: flash (không lite) mới nhất > flash-lite > còn lại; bỏ model ảnh / giọng / live / embedding
  if (/image|tts|audio|live|embed|veo|imagen|lyria|robotics|computer|aqa|learnlm/i.test(n)) return -1;
  const v = parseFloat((n.match(/gemini-(\d+(?:\.\d+)?)/) || [])[1] || '0');
  let score = v * 10;
  if (/flash/.test(n)) score += 1000;
  if (/lite/.test(n)) score -= 300;
  if (/preview|exp/.test(n)) score -= 50;
  if (/latest/.test(n)) score += 5;
  return score;
}

async function listModels(env) {
  if (modelCache.list && Date.now() - modelCache.at < 6 * 3600000) return modelCache.list;
  try {
    const res = await fetch(`${G_BASE}/v1beta/models?pageSize=200`, { headers: gHeaders(env) });
    if (!res.ok) {
      await saveAiError(env, 'models', res.status, await res.text());
      return null;
    }
    const j = await res.json();
    const list = (j.models || [])
      .filter((m) => {
        const methods = m.supportedGenerationMethods || m.supportedActions || m.supported_actions || ['generateContent'];
        return methods.includes('generateContent');
      })
      .map((m) => String(m.name || '').replace(/^models\//, ''))
      .filter((n) => rankModel(n) >= 0)
      .sort((a, b) => rankModel(b) - rankModel(a));
    modelCache = { at: Date.now(), list };
    return list;
  } catch {
    return null;
  }
}

async function saveAiError(env, where, status, text) {
  try {
    let msg = text;
    try {
      msg = JSON.parse(text)?.error?.message || text;
    } catch {}
    await env.DB.prepare('INSERT INTO config (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v')
      .bind('ai_error', JSON.stringify({ at: Date.now(), where, status, message: String(msg).slice(0, 500) }))
      .run();
  } catch {}
}

/** Đổi body kiểu generateContent sang Interactions API (system_instruction, generation_config, input là mảng nội dung). */
function toInteraction(model, body) {
  const input = [];
  const sys = (body.systemInstruction?.parts || []).map((p) => p.text).join('\n');
  const turns = body.contents || [];
  const flat = [];
  for (const c of turns) {
    for (const p of c.parts || []) {
      if (p.inline_data) input.push({ type: 'image', mime_type: p.inline_data.mime_type, data: p.inline_data.data });
      else if (p.text != null) flat.push((turns.length > 1 ? (c.role === 'model' ? 'Trợ lý: ' : 'Người dùng: ') : '') + p.text);
    }
  }
  input.push({ type: 'text', text: flat.join('\n') + (body.generationConfig?.responseMimeType === 'application/json' ? '\n\nChỉ trả về JSON hợp lệ.' : '') });
  const out = { model, input, store: false };
  if (sys) out.system_instruction = sys;
  const max = body.generationConfig?.maxOutputTokens;
  if (max) out.generation_config = { max_output_tokens: max };
  return out;
}

/** Lấy chữ trả lời của model từ phản hồi Interactions (chấp nhận nhiều dạng: output_text, outputs, steps). */
function interactionText(j) {
  if (typeof j?.output_text === 'string' && j.output_text) return j.output_text;
  const parts = [];
  const walk = (it, inModel) => {
    if (!it || typeof it !== 'object') return;
    if (Array.isArray(it)) return it.forEach((x) => walk(x, inModel));
    const t = it.type || '';
    if (/user_input|thought|function_call/.test(t)) return;
    const model = inModel || /model_output|text/.test(t) || t === '';
    if (model && typeof it.text === 'string' && (t === 'text' || t === '' || t === 'model_output')) parts.push(it.text);
    for (const k of ['content', 'contents', 'parts', 'outputs', 'steps', 'output']) if (it[k]) walk(it[k], model || /model_output/.test(t));
  };
  walk(j.outputs ?? j.steps ?? j.output ?? [], false);
  return parts.join('');
}

/** Model đang "nghỉ" vì hết lượt / không dùng được: model -> thời điểm được thử lại (ms). Dùng chung qua D1. */
let cool = { at: 0, map: {} };
let lastAttempts = []; // các lần thử gần nhất (để chẩn đoán)
let route = null; // { api: 'gen' | 'int', ver, model } lần gọi thành công gần nhất

async function loadState(env) {
  if (Date.now() - cool.at < 20000) return;
  try {
    const r = await env.DB.prepare("SELECT k, v FROM config WHERE k IN ('ai_cool3', 'ai_route3')").all();
    for (const row of r.results || []) {
      if (row.k === 'ai_cool3') cool.map = JSON.parse(row.v) || {};
      if (row.k === 'ai_route3') route = JSON.parse(row.v);
    }
  } catch {}
  cool.at = Date.now();
}

async function saveState(env, k, v) {
  try {
    await env.DB.prepare('INSERT INTO config (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v').bind(k, JSON.stringify(v)).run();
  } catch {}
}

async function coolDown(env, model, ms) {
  cool.map[model] = Date.now() + ms;
  for (const [m, t] of Object.entries(cool.map)) if (t < Date.now()) delete cool.map[m];
  await saveState(env, 'ai_cool3', cool.map);
}

function retryMs(text) {
  const m = /retry in ([\d.]+)\s*s/i.exec(text) || /"retryDelay":\s*"([\d.]+)s"/.exec(text);
  return m ? Math.ceil(parseFloat(m[1]) * 1000) + 1000 : 60000;
}

async function callRoute(env, r, body) {
  if (r.api === 'gen') {
    return fetch(`${G_BASE}/v1beta/models/${r.model}:generateContent`, { method: 'POST', headers: gHeaders(env), body: JSON.stringify(body) });
  }
  const res = await fetch(`${G_BASE}/${r.ver}/interactions`, {
    method: 'POST',
    headers: gHeaders(env),
    body: JSON.stringify(toInteraction(r.model, body)),
  });
  if (!res.ok) return res;
  const text = interactionText(await res.json());
  return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }), { headers: { 'content-type': 'application/json' } });
}

/**
 * Gọi Gemini, trả về Response kiểu generateContent ({candidates:[{content:{parts:[{text}]}}]}); lỗi thì trả Response lỗi của Google.
 * Tối đa 3 lần gọi mỗi yêu cầu (gói miễn phí chỉ vài lượt / phút). Model hết lượt được cho "nghỉ" đúng số giây Google báo.
 * prefer = 'lite' cho việc nhẹ (chat, đọc tin nhắn: hạn mức lite rộng hơn), 'flash' cho đọc ảnh.
 */
async function geminiFetch(env, body, prefer = 'flash') {
  await loadState(env);
  const found = (await listModels(env)) || [];
  const isLite = (m) => /lite/.test(m);
  // luôn ưu tiên Lite (hạn mức miễn phí rộng gấp 25 lần); Lite đọc được cả ảnh
  const models = [...new Set([env.GEMINI_MODEL, ...GEMINI_FALLBACK, ...found].filter(Boolean))];
  models.sort((a, b) => isLite(b) - isLite(a));
  const now = Date.now();
  const cands = [];
  if (route && !(cool.map[route.model] > now) && !(cool.map[route.api + ':' + route.model] > now)) cands.push(route);
  for (const m of models) {
    if (cool.map[m] > now) continue;
    // Interactions API là cách gọi mặc định mới của Google; generateContent là "legacy" -> thử Interactions trước
    if (!route || route.api === 'int') cands.push({ api: 'int', ver: route?.ver || 'v1beta', model: m });
    if (!route || route.api === 'gen') cands.push({ api: 'gen', model: m });
  }
  let last = null;
  let tries = 0;
  const seen = new Set();
  lastAttempts = [];
  for (const r of cands) {
    const key = r.api + r.model;
    if (seen.has(key) || cool.map[r.model] > Date.now() || cool.map[r.api + ':' + r.model] > Date.now()) continue;
    seen.add(key);
    if (++tries > 3) break;
    let res;
    try {
      res = await callRoute(env, r, body);
    } catch {
      continue;
    }
    if (res.ok) {
      if (!route || route.api !== r.api || route.model !== r.model) {
        route = r;
        await saveState(env, 'ai_route3', r);
      }
      return res;
    }
    last = res;
    const text = await res.clone().text();
    let gm = text;
    try {
      gm = JSON.parse(text)?.error?.message || text;
    } catch {}
    lastAttempts.push(`${r.api}:${r.model} ${res.status} ${String(gm).slice(0, 90)}`);
    await saveAiError(env, (r.api === 'gen' ? 'generateContent ' : r.ver + ' interactions ') + r.model, res.status, text);
    if (res.status === 429) await coolDown(env, r.model, retryMs(text));
    else if (/location is not supported/i.test(text)) break; // máy chủ Cloudflare đang chạy ở vùng Google chặn (VD Hồng Kông): thử model khác cũng vô ích
    else if (res.status === 404 || (res.status === 400 && /model|not found/i.test(text))) await coolDown(env, r.api + ':' + r.model, 6 * 3600000);
    else if (res.status === 401 || res.status === 403) break;
    if (route && route.model === r.model && route.api === r.api && res.status !== 429) {
      route = null;
      await saveState(env, 'ai_route3', null);
    }
  }
  return last;
}

async function askGemini(env, sys, contents) {
  const res = await geminiFetch(env, {
    systemInstruction: { parts: [{ text: sys }] },
    contents,
    generationConfig: { temperature: 0.3, maxOutputTokens: 1024, responseMimeType: 'application/json' },
  }, 'lite');
  if (!res || !res.ok) throw new Error('gemini ' + (res?.status ?? 'none') + ' | ' + lastAttempts.join(' | '));
  const j = await res.json();
  const text = (j.candidates?.[0]?.content?.parts || []).map((p) => p.text || '').join('');
  return { text, provider: 'gemini' };
}

/** Đọc ảnh bằng Cloudflare Workers AI (dự phòng khi Gemini hết lượt / lỗi). Trả về chuỗi trả lời hoặc null. */
async function visionWorkersAI(env, prompt, imgB64, mime) {
  if (!env.AI) return null;
  const url = `data:${mime || 'image/jpeg'};base64,${imgB64}`;
  const tries = [
    () =>
      env.AI.run('@cf/meta/llama-4-scout-17b-16e-instruct', {
        messages: [{ role: 'user', content: [{ type: 'text', text: prompt + '\nCHỈ trả JSON.' }, { type: 'image_url', image_url: { url } }] }],
        max_tokens: 700,
        temperature: 0.1,
      }),
    async () => {
      const bytes = [...Uint8Array.from(atob(imgB64), (c) => c.charCodeAt(0))];
      try {
        await env.AI.run('@cf/meta/llama-3.2-11b-vision-instruct', { prompt: 'agree' }); // chấp nhận giấy phép (một lần)
      } catch {}
      return env.AI.run('@cf/meta/llama-3.2-11b-vision-instruct', { prompt: prompt + '\nCHỈ trả JSON.', image: bytes, max_tokens: 700 });
    },
  ];
  for (const t of tries) {
    try {
      const r = await t();
      const text = typeof r?.response === 'string' ? r.response : r?.choices?.[0]?.message?.content || JSON.stringify(r?.response ?? '');
      if (text && extractJson(text)) return text;
    } catch {}
  }
  return null;
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

// Gói miễn phí: số lần mỗi tháng cho các tác vụ AI tốn nhiều (Pro không giới hạn, chỉ tính chung hạn mức ngày)
const FREE_MONTHLY = { receipt: 5, parse: 10 };

/** Đếm lượt dùng theo tháng cho gói miễn phí. Trả về chuỗi lỗi nếu đã hết lượt. */
async function monthlyQuota(env, kind, key, userId) {
  if (!env.DB) return null;
  if ((await planOf(env, userId ?? null)).plan === 'pro') return null;
  const month = 'M' + new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 7);
  const limit = FREE_MONTHLY[kind];
  try {
    const row = await env.DB.prepare('SELECT n FROM ai_usage WHERE k = ? AND day = ?').bind(kind + key, month).first();
    if (row && row.n >= limit) {
      return kind === 'receipt'
        ? `Bản miễn phí đọc được ${limit} ảnh hóa đơn mỗi tháng. Nâng cấp Pro để đọc không giới hạn.`
        : `Bản miễn phí nhờ AI đọc tin nhắn được ${limit} lần mỗi tháng. Nâng cấp Pro để dùng thoải mái.`;
    }
    await env.DB.prepare(`INSERT INTO ai_usage (k, day, n) VALUES (?, ?, 1) ON CONFLICT (k, day) DO UPDATE SET n = n + 1`)
      .bind(kind + key, month)
      .run();
  } catch {}
  return null;
}

let lastQuota = null; // { limit, used, pro } của lần đếm gần nhất

async function underLimit(env, key, userId) {
  if (!env.DB) return true;
  const pro = (await planOf(env, userId ?? null)).plan === 'pro';
  const limit = pro ? PRO_LIMIT : DAILY_LIMIT;
  const day = vnToday();
  try {
    await env.DB.prepare(
      `INSERT INTO ai_usage (k, day, n) VALUES (?, ?, 1)
       ON CONFLICT (k, day) DO UPDATE SET n = n + 1`
    ).bind(key, day).run();
    const row = await env.DB.prepare('SELECT n FROM ai_usage WHERE k = ? AND day = ?').bind(key, day).first();
    lastQuota = { limit, used: Math.min(row?.n || 0, limit), pro };
    return !row || row.n <= limit;
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
  lastQuota = null;
  const ok = await underLimit(env, chatKey(userId, req), userId);
  const quota = lastQuota ? { limit: lastQuota.limit, left: Math.max(0, lastQuota.limit - lastQuota.used), pro: lastQuota.pro } : null;
  if (!ok) {
    return json(
      {
        error: quota?.pro
          ? 'Hôm nay bạn đã dùng hết lượt hỏi trợ lý, mai quay lại nhé.'
          : `Bản miễn phí được ${DAILY_LIMIT} tin nhắn trợ lý mỗi ngày và hôm nay đã hết. Nâng cấp Pro để hỏi tới ${PRO_LIMIT} tin mỗi ngày.`,
        quota,
      },
      429
    );
  }

  const today = /^\d{4}-\d{2}-\d{2}$/.test(b.today || '') ? b.today : new Date().toISOString().slice(0, 10);
  const context = String(b.context || '').slice(0, 12000);
  const history = (Array.isArray(b.messages) ? b.messages : [])
    .filter((m) => m && typeof m.text === 'string' && m.text.trim())
    .slice(-12)
    .map((m) => ({ role: m.role === 'model' ? 'model' : 'user', text: m.text.slice(0, 2000) }));
  if (!history.length || history[history.length - 1].role !== 'user') return json({ error: 'Thiếu câu hỏi' }, 400);

  const ex = { ...(await aiExtras(env).catch(() => null)), payday: !!b.payday };
  const dt = dictText(ex.dict);
  const sys = systemPrompt(today, b.tone, ex) + (dt ? '\n\n' + dt : '') + '\n\nDỮ LIỆU:\n' + context;
  let out = null;
  let geminiNote = '';
  if (env.GEMINI_API_KEY) {
    try {
      out = await askGemini(env, sys, history.map((m) => ({ role: m.role, parts: [{ text: m.text }] })));
    } catch (e) {
      out = null; // hết lượt / lỗi: chuyển sang Workers AI
      geminiNote = String(e?.message || e).slice(0, 600);
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
  return json({ reply: reply.slice(0, 4000), actions: cleanActions(parsed?.actions), provider: out.provider, quota, ...(geminiNote ? { note: geminiNote } : {}) });
}

// ---------------- Đọc hóa đơn / ảnh chuyển khoản: POST /api/receipt {image: base64, mime, today} ----------------

export async function handleReceipt(req, env, userId) {
  if (!env.GEMINI_API_KEY && !env.AI) {
    return json({ error: 'Đọc ảnh hóa đơn cần khóa Gemini trên server (chạy dat-khoa-gemini.bat).' }, 503);
  }
  let b;
  try {
    b = await req.json();
  } catch {
    return json({ error: 'Dữ liệu không hợp lệ' }, 400);
  }
  const img = String(b.image || '');
  if (!img || img.length > 6_000_000) return json({ error: 'Ảnh trống hoặc quá lớn' }, 400);
  const key = userId != null ? 'u' + userId : 'ip' + (req.headers.get('cf-connecting-ip') || '?');
  if (!(await underLimit(env, key, userId))) return json({ error: 'Hôm nay bạn đã dùng hết lượt AI, mai quay lại nhé.' }, 429);
  const quota = await monthlyQuota(env, 'receipt', key, userId);
  if (quota) return json({ error: quota, pro: true }, 402);
  const dt = dictText((await aiExtras(env).catch(() => null))?.dict);
  const today = /^\d{4}-\d{2}-\d{2}$/.test(b.today || '') ? b.today : new Date().toISOString().slice(0, 10);
  const prompt = `Đây là ảnh hóa đơn, biên lai, hoặc ảnh chụp màn hình chuyển khoản / mã QR thanh toán ở Việt Nam. Hôm nay là ${today}.
Đọc và trả về MỘT đối tượng JSON:
{"found":true,"amount":125000,"income":false,"category":"an_uong","note":"tên cửa hàng hoặc nội dung ngắn","date":"YYYY-MM-DD","items":[{"amount":80000,"category":"an_uong","note":"thực phẩm"},{"amount":45000,"category":"mua_sam","note":"đồ gia dụng"}]}
- amount: TỔNG số tiền phải trả / đã chuyển (đồng, số nguyên).
- income: true chỉ khi ảnh là tiền NHẬN vào.
- category: một trong ${Object.keys(CATS).join(', ')}.
- date: ngày trên hóa đơn nếu có, không có thì để trống.
- items: nếu là hóa đơn siêu thị / đơn hàng nhiều món thuộc NHIỀU danh mục khác nhau, gộp các món theo danh mục, mỗi danh mục một phần tử (tổng các phần tử bằng amount; phân bổ giảm giá / phí ship theo tỉ lệ). Nếu chỉ một danh mục thì để mảng rỗng.
Nếu không đọc được số tiền, trả {"found":false,"reason":"lý do ngắn bằng tiếng Việt"}.${dt ? '\n' + dt : ''}`;
  try {
    const res = !env.GEMINI_API_KEY ? null : await geminiFetch(env, {
      contents: [{ role: 'user', parts: [{ inline_data: { mime_type: b.mime || 'image/jpeg', data: img } }, { text: prompt }] }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 1024, responseMimeType: 'application/json' },
    });
    let rawText = null;
    if (res && res.ok) {
      const jj = await res.json();
      rawText = (jj.candidates?.[0]?.content?.parts || []).map((x) => x.text || '').join('');
    } else {
      rawText = await visionWorkersAI(env, prompt, img, b.mime);
    }
    if (rawText == null) {
      if (!res) return json({ error: 'AI chưa đọc được ảnh, thử lại sau.' }, 502);
      const msg =
        res.status === 429
          ? 'AI đọc ảnh đã hết lượt miễn phí của Google (' + (await googleMsg(res)) + '). Thử lại sau ít phút.'
          : 'AI chưa đọc được ảnh (' + res.status + '): ' + (await googleMsg(res)) + '. Thử lại sau.';
      return json({ error: msg }, 502);
    }
    const p = extractJson(rawText);
    if (!p || !p.found) return json({ found: false, reason: (p && p.reason) || 'Không thấy số tiền trong ảnh' });
    const acts = cleanActions([{ type: 'add_txn', ...p }]);
    if (!acts.length) return json({ found: false, reason: 'Không thấy số tiền hợp lệ' });
    const items = cleanActions((Array.isArray(p.items) ? p.items : []).slice(0, 8).map((x) => ({ type: 'add_txn', income: acts[0].income, date: acts[0].date, ...x })));
    const cats = new Set(items.map((x) => x.category));
    return json({ found: true, ...acts[0], items: items.length > 1 && cats.size > 1 ? items : [] });
  } catch (e) {
    return json({ error: 'AI đang bận, thử lại sau.' }, 502);
  }
}

/** POST /api/parse {text, today}: AI bóc tách tin nhắn biến động số dư / ví điện tử (MoMo, ZaloPay, ngân hàng...)
 *  khi bộ đọc có sẵn trong app không hiểu. Có thể ra nhiều giao dịch nếu dán nhiều tin. */
export async function handleParse(req, env, userId) {
  let b;
  try {
    b = await req.json();
  } catch {
    return json({ error: 'Dữ liệu không hợp lệ' }, 400);
  }
  const text = String(b.text || '').trim().slice(0, 4000);
  if (text.length < 6) return json({ error: 'Nội dung quá ngắn' }, 400);
  const key = userId != null ? 'u' + userId : 'ip' + (req.headers.get('cf-connecting-ip') || '?');
  if (!(await underLimit(env, key, userId))) return json({ error: 'Hôm nay bạn đã dùng hết lượt AI, mai quay lại nhé.' }, 429);
  const quota = await monthlyQuota(env, 'parse', key, userId);
  if (quota) return json({ error: quota, pro: true }, 402);
  const dt = dictText((await aiExtras(env).catch(() => null))?.dict);
  const today = /^\d{4}-\d{2}-\d{2}$/.test(b.today || '') ? b.today : new Date().toISOString().slice(0, 10);
  const sys = `Bạn bóc tách tin nhắn / thông báo biến động số dư của ngân hàng và ví điện tử Việt Nam (MoMo, ZaloPay, ShopeePay, VNPay, Viettel Money...). Hôm nay là ${today}.
Trả về JSON: {"txns":[{"amount":50000,"income":false,"category":"an_uong","note":"nội dung ngắn / tên người nhận","date":"YYYY-MM-DD"}]}
- Mỗi biến động tiền là một phần tử (văn bản có thể chứa nhiều tin). Bỏ qua tin quảng cáo, mã OTP, tin không có tiền đi / đến.
- amount: số tiền giao dịch (đồng, số nguyên), KHÔNG lấy số dư.
- income: true nếu tiền vào (+, nhận, hoàn tiền), false nếu tiền ra (-, thanh toán, chuyển đi).
- category: một trong ${Object.keys(CATS).join(', ')}. Chuyển tiền cho người khác mà không rõ mục đích: chuyen_di; nhận tiền không rõ: nhan_tien.
- date: ngày trong tin, không có thì để trống.
Không thấy giao dịch nào: {"txns":[]}.${dt ? '\n' + dt : ''}`;
  try {
    let out = null;
    if (env.GEMINI_API_KEY) out = await askGemini(env, sys, [{ role: 'user', parts: [{ text }] }]).catch(() => null);
    if (!out && env.AI) out = await askWorkersAI(env, sys + '\nCHỈ trả JSON, không giải thích.', [{ role: 'user', text }]);
    if (!out) throw new Error('no ai');
    const p = extractJson(out.text) || {};
    const list = Array.isArray(p.txns) ? p.txns : Array.isArray(p) ? p : [];
    const acts = cleanActions(list.slice(0, 20).map((x) => ({ type: 'add_txn', ...x })));
    return json({ txns: acts, provider: out.provider });
  } catch {
    return json({ error: 'AI đang bận, thử lại sau.' }, 502);
  }
}
