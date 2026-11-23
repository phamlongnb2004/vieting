// Thời tiết cho VieTing. Tác giả: Phạm Thành Long (thlong)
//
// GET  /api/weather?lat=..&lon=..&tz=420     dự báo đã gọn: hiện tại, 24 giờ tới, 7 ngày, cảnh báo thời tiết xấu
// POST /api/weather/advice {place, lang, summary}   AI gợi ý nên làm gì (lưu đệm 3 giờ theo nội dung)
//
// Nguồn: MET Norway Locationforecast 2.0 (api.met.no), miễn phí kể cả dùng thương mại, giấy phép CC BY 4.0
// (app phải ghi nguồn "MET Norway"). Yêu cầu của họ: User-Agent nhận diện được và có lưu đệm.
// Tọa độ làm tròn 2 chữ số (~1 km) trước khi gửi đi; server không lưu vị trí người dùng.

import { textJson, aiAllowed } from './ai.js';

const UA = 'VieTing/1.0 (+https://vieting.phamthanhlong-contact.workers.dev/privacy)';

// Ngưỡng cảnh báo (theo cấp gió / lượng mưa thường dùng ở Việt Nam)
const RAIN_HEAVY_H = 10; // mm/giờ: mưa rất to
const RAIN_HEAVY_DAY = 50; // mm/ngày: mưa to
const WIND_STORM = 17.2; // m/s ≈ cấp 8: gió bão
const WIND_STRONG = 10.8; // m/s ≈ cấp 6: gió mạnh
const HOT = 37;
const COLD = 10;

const r2 = (x) => Math.round(Number(x) * 100) / 100;

async function metForecast(lat, lon) {
  const url = `https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=${lat}&lon=${lon}`;
  const key = new Request(url);
  let res = await caches.default.match(key);
  if (!res) {
    const r = await fetch(url, { headers: { 'user-agent': UA, accept: 'application/json' } });
    if (!r.ok) throw new Error('MET Norway ' + r.status);
    res = new Response(await r.text(), { headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=1800' } });
    await caches.default.put(key, res.clone());
  }
  return res.json();
}

const base = (s) => String(s || '').replace(/_(day|night|polartwilight)$/, '');
const thunder = (s) => /thunder/.test(s || '');

/** Gom dữ liệu MET thành dạng gọn cho app. tzMin: độ lệch múi giờ của máy (phút). */
export function shapeForecast(j, tzMin = 420, now = Date.now()) {
  const ts = j?.properties?.timeseries || [];
  const dayKey = (t) => new Date(t + tzMin * 60000).toISOString().slice(0, 10);
  const hours = [];
  const days = new Map();
  let n6Until = 0; // phần dự báo 6 giờ đã cộng vào lượng mưa tới thời điểm này
  for (const p of ts) {
    const t = Date.parse(p.time);
    const d = p.data || {};
    const inst = d.instant?.details || {};
    const n1 = d.next_1_hours;
    const n6 = d.next_6_hours;
    const sym = n1?.summary?.symbol_code || n6?.summary?.symbol_code || '';
    const h = {
      t,
      temp: Math.round(Number(inst.air_temperature ?? 0)),
      sym,
      rain: n1 ? Number(n1.details?.precipitation_amount || 0) : null,
      pop: n1?.details?.probability_of_precipitation ?? n6?.details?.probability_of_precipitation ?? null,
      wind: Math.round(Number(inst.wind_speed || 0) * 10) / 10,
      gust: Math.round(Number(inst.wind_speed_of_gust ?? inst.wind_speed ?? 0) * 10) / 10,
      hum: Math.round(Number(inst.relative_humidity || 0)),
    };
    if (n1 && t >= now - 3600_000 && hours.length < 48) hours.push(h);
    const k = dayKey(t);
    if (!days.has(k)) days.set(k, { date: k, min: 99, max: -99, rain: 0, wind: 0, syms: {}, hourly: false });
    const dd = days.get(k);
    dd.min = Math.min(dd.min, h.temp);
    dd.max = Math.max(dd.max, h.temp);
    dd.wind = Math.max(dd.wind, h.gust);
    if (n1) {
      dd.rain += h.rain;
      n6Until = t + 3600_000;
    } else if (n6 && t >= n6Until) {
      dd.rain += Number(n6.details?.precipitation_amount || 0);
      n6Until = t + 6 * 3600_000;
    }
    if (sym) dd.syms[base(sym)] = (dd.syms[base(sym)] || 0) + 1;
  }
  const daily = [...days.values()]
    .filter((d) => d.date >= dayKey(now))
    .slice(0, 8)
    .map((d) => {
      const keys = Object.entries(d.syms).sort((a, b) => b[1] - a[1]).map((e) => e[0]);
      const pick = keys.find((k) => /thunder/.test(k)) || keys.find((k) => /heavyrain/.test(k)) || keys.find((k) => /rain/.test(k)) || keys[0] || '';
      return { date: d.date, min: d.min, max: d.max, rain: Math.round(d.rain * 10) / 10, wind: d.wind, sym: pick };
    });

  // Cảnh báo trong 48 giờ tới; cùng loại cách nhau dưới 3 giờ thì gộp
  const alerts = [];
  const add = (a) => {
    const same = alerts.find((x) => x.kind === a.kind && a.start - x.end <= 3 * 3600_000);
    if (same) {
      same.end = Math.max(same.end, a.end);
      same.peak = Math.max(same.peak, a.peak);
    } else alerts.push(a);
  };
  for (const h of hours) {
    if (h.t > now + 48 * 3600_000) continue;
    const end = h.t + 3600_000;
    if (h.gust >= WIND_STORM) add({ kind: 'storm', level: 3, start: h.t, end, peak: h.gust });
    else if (h.gust >= WIND_STRONG) add({ kind: 'wind', level: 1, start: h.t, end, peak: h.gust });
    if (thunder(h.sym) && (h.rain || 0) >= 2) add({ kind: 'thunder', level: 2, start: h.t, end, peak: h.rain });
    if ((h.rain || 0) >= RAIN_HEAVY_H) add({ kind: 'heavyrain', level: 2, start: h.t, end, peak: h.rain });
    if (h.temp >= HOT) add({ kind: 'heat', level: 1, start: h.t, end, peak: h.temp });
    if (h.temp <= COLD) add({ kind: 'cold', level: 1, start: h.t, end, peak: h.temp });
  }
  for (const d of daily.slice(0, 3)) {
    if (d.rain >= RAIN_HEAVY_DAY && !alerts.some((a) => (a.kind === 'heavyrain' || a.kind === 'storm') && dayKey(a.start) === d.date)) {
      const t0 = Date.parse(d.date + 'T00:00:00Z') - tzMin * 60000;
      if (t0 + 86400_000 > now) add({ kind: 'rainday', level: 2, start: Math.max(t0, now), end: t0 + 86400_000, peak: d.rain });
    }
  }
  // Có bão thì gộp mưa / dông / gió cùng lúc vào cảnh báo bão cho khỏi báo trùng
  const storms = alerts.filter((a) => a.kind === 'storm');
  const merged = alerts.filter((a) => {
    if (a.kind === 'storm') return true;
    const s = storms.find((x) => a.start < x.end && a.end > x.start);
    if (s && a.kind !== 'heat' && a.kind !== 'cold') {
      if (a.kind === 'heavyrain' || a.kind === 'thunder') s.rain = Math.max(s.rain || 0, a.peak);
      return false;
    }
    return true;
  });
  alerts.length = 0;
  alerts.push(...merged);
  alerts.sort((a, b) => b.level - a.level || a.start - b.start);
  return { at: now, current: hours[0] || null, hourly: hours.slice(0, 24), daily, alerts: alerts.slice(0, 5), source: 'MET Norway' };
}

const ADVICE_PROMPT = (lang) =>
  lang === 'en'
    ? 'You are the friendly assistant of VieTing, a personal expense app. Given the weather forecast below, write 2 to 4 short, practical tips in casual English: what to prepare or avoid (safety first if there is a storm, heavy rain, heat or cold), and at least one money-related tip (e.g. food delivery costs more when it rains so cook at home, keep a small budget for supplies). No markdown. Return JSON {"title":"short headline","tips":["...","..."]}.'
    : 'Bạn là trợ lý thân thiện của VieTing, app quản lý chi tiêu. Dựa vào dự báo thời tiết dưới đây, viết 2 đến 4 gợi ý ngắn, thiết thực bằng tiếng Việt, giọng thân mật: nên chuẩn bị gì, tránh gì (an toàn là trên hết nếu có bão, mưa to, nắng nóng hay rét), và ít nhất một gợi ý về tiền bạc (VD trời mưa đặt đồ ăn tốn phí ship hơn nên nấu ở nhà, để riêng một khoản nhỏ mua đồ dự phòng). Không dùng markdown. Trả JSON {"title":"tiêu đề ngắn","tips":["...","..."]}.';

export async function handleWeather(req, env, url, userId, h) {
  const p = url.pathname;
  if (req.method === 'GET' && p === '/api/weather') {
    const lat = r2(url.searchParams.get('lat'));
    const lon = r2(url.searchParams.get('lon'));
    if (!(Math.abs(lat) <= 90 && Math.abs(lon) <= 180) || (lat === 0 && lon === 0)) return h.json({ error: 'Vị trí không hợp lệ' }, 400);
    const tz = Math.max(-720, Math.min(840, Number(url.searchParams.get('tz')) || 420));
    try {
      return h.json(shapeForecast(await metForecast(lat, lon), tz));
    } catch (e) {
      return h.json({ error: 'Không lấy được dự báo thời tiết: ' + (e?.message || e) }, 502);
    }
  }
  if (req.method === 'POST' && p === '/api/weather/advice') {
    const b = await h.readJson(req);
    const lang = b?.lang === 'en' ? 'en' : 'vi';
    const place = String(b?.place || '').slice(0, 60);
    const summary = String(b?.summary || '').slice(0, 1500);
    if (!summary) return h.json({ error: 'Thiếu dự báo' }, 400);
    const day = new Date(Date.now() + 7 * 3600_000).toISOString().slice(0, 10);
    let hash = 7;
    for (const c of place + summary) hash = (hash * 31 + c.charCodeAt(0)) >>> 0;
    const key = new Request(`https://vieting.cache/weather-advice/${lang}/${day}/${hash.toString(36)}`);
    const hit = await caches.default.match(key);
    if (hit) return h.json(await hit.json());
    if (userId != null && !(await aiAllowed(env, userId).catch(() => true))) {
      return h.json({ error: lang === 'en' ? "You've used today's AI messages" : 'Hôm nay đã hết lượt AI' }, 429);
    }
    const out = await textJson(env, ADVICE_PROMPT(lang) + `\n\n${lang === 'en' ? 'Place' : 'Địa điểm'}: ${place}\n${summary}`).catch(() => null);
    const tips = Array.isArray(out?.tips) ? out.tips.map((x) => String(x).slice(0, 220)).filter(Boolean).slice(0, 4) : [];
    if (!tips.length) return h.json({ error: lang === 'en' ? 'AI is busy, try again later' : 'AI đang bận, thử lại sau' }, 502);
    const body = { title: String(out.title || '').slice(0, 80), tips };
    await caches.default.put(key, new Response(JSON.stringify(body), { headers: { 'cache-control': 'public, max-age=10800', 'content-type': 'application/json' } }));
    return h.json(body);
  }
  return null;
}
