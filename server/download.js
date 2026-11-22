// Trang tải VieTing (/tai-app) và link tải cố định /tai/<nền tảng>.
// Tác giả: Phạm Thành Long (thlong)
// Cloudflare chỉ nhận file tĩnh tối đa 25 MB, nên mỗi file cài được cắt thành phần 20 MB
// (tools/pack-cloudflare.js) và Worker ghép lại thành một luồng tải cho người dùng.

import DOWNLOAD_HTML from './download.html';

const OS = {
  android: { name: 'Android', sub: 'File APK', note: 'Mở file, cho phép "Cài ứng dụng không rõ nguồn gốc". Android 13+: nếu không bật được quyền đọc thông báo, vào Thông tin ứng dụng → ⋮ → "Cho phép cài đặt bị hạn chế".' },
  windows: { name: 'Windows', sub: 'Bộ cài (khuyên dùng)', note: 'Chạy file, bấm Cài đặt. Nếu Windows hiện SmartScreen: More info → Run anyway.' },
  'windows-portable': { name: 'Windows', sub: 'Không cần cài (.zip)', note: 'Giải nén rồi mở vieting.exe.' },
  ios: { name: 'iPhone', sub: 'IPA thử nghiệm', note: 'Cài bằng Sideloadly / AltStore với Apple ID phụ, ký lại sau 7 ngày.' },
};

async function manifest(env, req) {
  const r = await env.ASSETS.fetch(new URL('/manifest.json', req.url));
  return r.ok ? r.json() : { version: '', built: 0, files: {} };
}

// Ghép các phần thành một luồng; hỗ trợ tải tiếp (Range) để mạng yếu không phải tải lại từ đầu.
async function serveFile(env, req, key, f) {
  const total = f.size, PART = f.partSize;
  let start = 0, end = total - 1, status = 200;
  const m = /^bytes=(\d*)-(\d*)$/.exec(req.headers.get('Range') || '');
  if (m) {
    if (m[1] === '') start = Math.max(0, total - Number(m[2]));
    else {
      start = Number(m[1]);
      if (m[2] !== '') end = Math.min(total - 1, Number(m[2]));
    }
    if (start > end || start >= total) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${total}` } });
    status = 206;
  }
  const headers = {
    'Content-Type': f.type || 'application/octet-stream',
    'Content-Disposition': `attachment; filename="${f.name}"`,
    'Content-Length': String(end - start + 1),
    'Accept-Ranges': 'bytes',
    'Cache-Control': 'no-cache',
  };
  if (status === 206) headers['Content-Range'] = `bytes ${start}-${end}/${total}`;
  if (req.method === 'HEAD') return new Response(null, { status, headers });

  const { readable, writable } = new TransformStream();
  (async () => {
    const w = writable.getWriter();
    try {
      for (let i = Math.floor(start / PART); i * PART <= end; i++) {
        const pStart = i * PART, pEnd = Math.min(total, pStart + PART) - 1;
        const r = await env.ASSETS.fetch(new URL(`/files/${key}/${String(i).padStart(3, '0')}.bin`, req.url));
        if (!r.ok) throw new Error('thiếu phần ' + i);
        let buf = new Uint8Array(await r.arrayBuffer());
        const a = Math.max(start, pStart) - pStart, b = Math.min(end, pEnd) - pStart + 1;
        if (a > 0 || b < buf.length) buf = buf.subarray(a, b);
        await w.write(buf);
      }
      await w.close();
    } catch (e) {
      await w.abort(e);
    }
  })();
  return new Response(readable, { status, headers });
}

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const mb = (n) => (n / 1048576).toFixed(1) + ' MB';

const SVG = {
  android:
    '<svg viewBox="0 0 24 24" fill="#3DDC84"><path d="M17.6 9.48l1.84-3.18a.38.38 0 0 0-.66-.38l-1.86 3.22a11.5 11.5 0 0 0-9.84 0L5.22 5.92a.38.38 0 0 0-.66.38L6.4 9.48A10.8 10.8 0 0 0 1 18h22a10.8 10.8 0 0 0-5.4-8.52zM7 15.25a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm10 0a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5z"/></svg>',
  ios: '<svg viewBox="0 0 24 24" fill="#1C1B19"><path d="M16.4 12.6c0-2.3 1.9-3.4 2-3.5a4.3 4.3 0 0 0-3.4-1.8c-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8a4.5 4.5 0 0 0-3.8 2.3c-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.6s-2.5-1-2.5-3.7zM14.1 5.8c.6-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.6 2.8-1.4z"/></svg>',
  windows: '<svg viewBox="0 0 24 24" fill="#0078D4"><path d="M3 5.5 10.5 4.5v7H3zM11.5 4.4 21 3v8.5h-9.5zM3 12.5h7.5v7L3 18.5zM11.5 12.5H21V21l-9.5-1.4z"/></svg>',
  'windows-portable':
    '<svg viewBox="0 0 24 24" fill="none" stroke="#6E6A63" stroke-width="2" stroke-linejoin="round"><path d="M4 5h6l2 2h8v12H4z"/><path d="M12 10v6m-3-3h6" stroke-linecap="round"/></svg>',
};

const TEMPLATE = DOWNLOAD_HTML;

function page(man) {
  const built = man.built ? new Date(man.built).toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }) : '';
  const rows = Object.keys(OS)
    .map((k) => {
      const o = OS[k], f = man.files[k];
      const left = `<span class="os-ic">${SVG[k]}</span><span class="os-nm"><b>${o.name}</b><small>${o.sub}${f ? ' · ' + mb(f.size) : ''}</small></span>`;
      if (!f) return `<li class="row off"><div class="row-h">${left}<span class="soon">Sắp có</span></div></li>`;
      return `<li class="row" data-os="${k}"><div class="row-h">${left}<a class="get" href="/tai/${k}">Tải về</a></div><p>${esc(o.note)}</p></li>`;
    })
    .join('');
  const banks = ['Vietcombank', 'MB Bank', 'Techcombank', 'BIDV', 'VietinBank', 'Agribank', 'VPBank', 'TPBank', 'ACB', 'Sacombank', 'HDBank', 'VIB', 'MoMo', 'ZaloPay', 'ShopeePay', 'Cake', 'Timo', 'VNPay'];
  const chips = banks.map((b) => `<span>${b}</span>`).join('');
  const version = man.version ? 'Bản ' + esc(man.version) + (built ? ' · cập nhật ' + esc(built) : '') : 'Bản đầu tiên sắp ra mắt';
  return TEMPLATE.replaceAll('{{ROWS}}', rows).replaceAll('{{CHIPS}}', chips).replaceAll('{{VERSION}}', version);
}

/** Trả về Response nếu là đường dẫn của trang tải, ngược lại null. */
export async function handleDownload(req, env, p) {
  if (p === '/' || p === '/tai-app' || p === '/tai') {
    return new Response(page(await manifest(env, req)), {
      headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache' },
    });
  }
  const m = /^\/tai\/([a-z-]+)$/.exec(p);
  if (m) {
    const man = await manifest(env, req), f = man.files[m[1]];
    if (!f) return new Response('Chưa có bản này. Xem trang /tai-app', { status: 404, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    return serveFile(env, req, m[1], f);
  }
  if (p === '/api/latest') return Response.json(await manifest(env, req));
  if (p.startsWith('/files/') || p === '/manifest.json') return new Response('Not found', { status: 404 });
  if (p.startsWith('/img/')) {
    const r = await env.ASSETS.fetch(req);
    const h = new Headers(r.headers);
    h.set('Cache-Control', 'public, max-age=86400');
    return new Response(r.body, { status: r.status, headers: h });
  }
  return null;
}
