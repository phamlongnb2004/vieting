// Trang tải VieTing (/tai-app) và link tải cố định /tai/<nền tảng>.
// Tác giả: Phạm Thành Long (thlong)
// Cloudflare chỉ nhận file tĩnh tối đa 25 MB, nên mỗi file cài được cắt thành phần 20 MB
// (tools/pack-cloudflare.js) và Worker ghép lại thành một luồng tải cho người dùng.

const OS = {
  android: { name: 'Android', sub: 'File APK', icon: '🤖', note: 'Mở file, cho phép "Cài ứng dụng không rõ nguồn gốc". Android 13+: nếu không bật được quyền đọc thông báo, vào Thông tin ứng dụng → ⋮ → "Cho phép cài đặt bị hạn chế".' },
  windows: { name: 'Windows', sub: 'Bộ cài (khuyên dùng)', icon: '🪟', note: 'Chạy file, bấm Cài đặt. Nếu Windows hiện SmartScreen: More info → Run anyway.' },
  'windows-portable': { name: 'Windows', sub: 'Không cần cài (.zip)', icon: '🗂️', note: 'Giải nén rồi mở vieting.exe.' },
  ios: { name: 'iPhone', sub: 'IPA thử nghiệm', icon: '🍎', note: 'Cài bằng Sideloadly / AltStore với Apple ID phụ, ký lại sau 7 ngày.' },
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

function page(man) {
  const built = man.built ? new Date(man.built).toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }) : '';
  const cards = Object.keys(OS)
    .map((k) => {
      const o = OS[k], f = man.files[k];
      const head = `<div class="ic">${o.icon}</div><div class="nm"><b>${o.name}</b><span>${o.sub}</span></div>`;
      if (!f) return `<div class="card off">${head}<div class="meta">Sắp có</div></div>`;
      return `<a class="card" href="/tai/${k}" data-os="${k}">${head}<div class="meta">${mb(f.size)}</div><p>${esc(o.note)}</p><span class="btn">Tải xuống</span></a>`;
    })
    .join('');
  return `<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tải VieTing – quản lý chi tiêu</title>
<meta name="description" content="VieTing - app quản lý chi tiêu, tự đọc thông báo biến động số dư ngân hàng. Android · iPhone · Windows">
<meta property="og:title" content="VieTing – quản lý chi tiêu"><meta property="og:image" content="/img/icon-256.png">
<link rel="icon" href="/img/favicon.png">
<script>try{if(localStorage.getItem("theme")==="dark")document.documentElement.dataset.theme="dark"}catch(e){}</script>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@500;600;700;800;900&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box}html,body{margin:0}
:root{--red:#C1272C;--yellow:#FFCD00;--green:#3E8E41;--bg:#FBF8F3;--card:#fff;--text:#1f1b18;--mute:#6f665e;--line:#ece4d8}
[data-theme=dark]{--bg:#15130f;--card:#221f1a;--text:#f3eee6;--mute:#b3a99c;--line:#3a342c}
body{font-family:Montserrat,system-ui,sans-serif;color:var(--text);background:var(--bg);line-height:1.5}
.wrap{max-width:1040px;margin:0 auto;padding:0 20px 40px}
.top{display:flex;align-items:center;justify-content:space-between;padding:18px 0}
.brand{display:flex;align-items:center;gap:10px;font-weight:900;font-size:24px;letter-spacing:-.5px;text-decoration:none;color:var(--text)}
.brand img{width:40px;height:40px}.brand .v{color:var(--red)}.brand .t{color:var(--green)}
#th{border:1px solid var(--line);background:var(--card);color:var(--text);border-radius:999px;width:40px;height:40px;font-size:18px;cursor:pointer}
.hero{display:grid;grid-template-columns:1.2fr .8fr;gap:28px;align-items:center;padding:28px 0 18px}
.hero h1{font-size:44px;line-height:1.1;margin:0 0 14px;font-weight:900;letter-spacing:-1px}
.hero h1 em{font-style:normal;color:var(--red)}
.hero p{color:var(--mute);font-size:17px;margin:0 0 22px;font-weight:500}
.main-btn{display:inline-flex;align-items:center;gap:8px;background:var(--red);color:#fff;text-decoration:none;font-weight:800;padding:15px 26px;border-radius:14px;box-shadow:0 10px 24px rgba(193,39,44,.28)}
.main-btn small{font-weight:600;opacity:.85}
.ver{display:block;margin-top:12px;color:var(--mute);font-size:13px}
.phone{justify-self:center;width:250px;border-radius:34px;background:var(--card);border:8px solid #1f1b18;padding:16px;box-shadow:0 20px 50px rgba(0,0,0,.15)}
.bal{background:linear-gradient(135deg,var(--red),#8e1b1f);color:#fff;border-radius:18px;padding:16px}
.bal small{opacity:.85}.bal b{display:block;font-size:24px;font-weight:900;margin:2px 0 10px}
.bal .r{display:flex;justify-content:space-between;font-size:12px}
.noti{margin-top:12px;background:var(--bg);border:1px solid var(--line);border-radius:14px;padding:10px 12px;font-size:12px}
.noti b{color:var(--green)}.noti .m{color:var(--red);font-weight:800}
h2{font-size:24px;margin:36px 0 14px;font-weight:800}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px}
.card{display:flex;flex-direction:column;gap:8px;background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px;text-decoration:none;color:var(--text);transition:transform .15s,box-shadow .15s}
a.card:hover{transform:translateY(-3px);box-shadow:0 12px 26px rgba(0,0,0,.08)}
.card .ic{font-size:30px}.card .nm b{display:block;font-size:18px}.card .nm span{color:var(--mute);font-size:13px}
.card .meta{color:var(--mute);font-size:13px;font-weight:600}.card p{margin:0;color:var(--mute);font-size:13px;flex:1}
.card .btn{align-self:flex-start;background:var(--red);color:#fff;font-weight:700;padding:8px 14px;border-radius:10px;font-size:14px}
.card.off{opacity:.55}
.feat{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px}
.f{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px;color:var(--mute);font-size:14px}
.f b{display:block;color:var(--text);font-size:16px;margin-bottom:4px}.f i{font-style:normal;font-size:22px;display:block;margin-bottom:6px}
.note{background:rgba(255,205,0,.16);border:1px solid rgba(255,205,0,.5);border-radius:14px;padding:14px 16px;font-size:14px;margin-top:14px}
footer{margin-top:40px;color:var(--mute);font-size:13px;text-align:center}
@media(max-width:760px){.hero{grid-template-columns:1fr}.hero h1{font-size:34px}.phone{display:none}}
</style></head><body><div class="wrap">
<div class="top"><a class="brand" href="/tai-app"><img src="/img/icon-256.png" alt=""><span><span class="v">Vie</span><span class="t">Ting</span></span></a><button id="th" aria-label="Đổi giao diện sáng/tối">🌙</button></div>
<section class="hero"><div>
<h1>Có tiền vào ra là <em>ting</em> – VieTing tự ghi sổ.</h1>
<p>App quản lý chi tiêu đọc thông báo biến động số dư của ngân hàng, tự ghi giao dịch, xếp danh mục và tính số dư. Android · iPhone · Windows.</p>
<a class="main-btn" id="mb" href="#tai">⬇ Tải VieTing</a>
<span class="ver">${man.version ? 'Phiên bản ' + esc(man.version) + (built ? ' · ' + esc(built) : '') : 'Bản đầu tiên đang được dựng'}</span>
</div>
<div class="phone"><div class="bal"><small>Tổng số dư</small><b>12.450.000 ₫</b><div class="r"><span>↙ Thu 15,2 tr</span><span>↗ Chi 6,8 tr</span></div></div>
<div class="noti">🔔 <b>Đã ghi tự động</b><br><span class="m">−55.000 ₫</span> · Ăn uống · Highlands</div>
<div class="noti">🔔 <b>Đã ghi tự động</b><br><span style="color:var(--green);font-weight:800">+5.000.000 ₫</span> · Lương</div></div>
</section>
<h2 id="tai">Chọn bản cho máy của bạn</h2><div class="grid">${cards}</div>
<div class="note">📱 <b>iPhone:</b> Apple không cho app đọc thông báo của app khác, nên trên iPhone VieTing ghi tự động qua Phím tắt (với SMS ngân hàng) hoặc nút Dán thông báo. Đăng nhập để xem giao dịch điện thoại Android đã ghi.</div>
<h2>Có gì trong VieTing</h2><div class="feat">
<div class="f"><i>🔔</i><b>Tự đọc biến động số dư</b>Vietcombank, MB, Techcombank, BIDV, VietinBank, Agribank, VPBank, TPBank, ACB, MoMo, ZaloPay…</div>
<div class="f"><i>🎋</i><b>Tự xếp danh mục</b>Highlands vào Ăn uống, Grab vào Đi lại. Sửa một lần là app nhớ.</div>
<div class="f"><i>📊</i><b>Biểu đồ & ngân sách</b>Chi theo danh mục, 7 ngày qua, hạn mức tháng, gợi ý chi mỗi ngày.</div>
<div class="f"><i>🔒</i><b>Riêng tư</b>Xử lý ngay trên máy, bỏ qua OTP và tin nhắn chat. Đồng bộ chỉ khi bạn đăng nhập.</div>
</div>
<footer>© 2026 VieTing · Phạm Thành Long (thlong)</footer></div>
<script>(function(){var d=document.documentElement,t=document.getElementById('th');function set(v){if(v==='dark')d.dataset.theme='dark';else delete d.dataset.theme;t.textContent=v==='dark'?'☀':'🌙';try{localStorage.setItem('theme',v)}catch(e){}}set(d.dataset.theme==='dark'?'dark':'light');t.onclick=function(){set(d.dataset.theme==='dark'?'light':'dark')};})();
(function(){var u=navigator.userAgent,k=/Android/i.test(u)?'android':/iPhone|iPad|iPod/i.test(u)?'ios':/Windows/i.test(u)?'windows':'';
var a=k&&document.querySelector('a.card[data-os="'+k+'"]'),b=document.getElementById('mb');
if(a){b.href=a.getAttribute('href');b.innerHTML='⬇ Tải cho '+a.querySelector('b').textContent+' <small>'+a.querySelector('.meta').textContent+'</small>';}})();</script>
</body></html>`;
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
