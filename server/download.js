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
  const svg = {
    android: '<svg viewBox="0 0 24 24"><path d="M7 9h10v8a1 1 0 0 1-1 1h-1v3h-2v-3h-2v3H9v-3H8a1 1 0 0 1-1-1zM5 9.5a1 1 0 0 1 2 0v5a1 1 0 0 1-2 0zm12 0a1 1 0 0 1 2 0v5a1 1 0 0 1-2 0zM7.2 8a5 5 0 0 1 9.6 0zM8.6 3.3l1 1.6M15.4 3.3l-1 1.6" fill="currentColor" stroke="currentColor" stroke-width=".6" stroke-linecap="round"/></svg>',
    windows: '<svg viewBox="0 0 24 24"><path d="M3 5.5 10.5 4.5v7H3zM11.5 4.4 21 3v8.5h-9.5zM3 12.5h7.5v7L3 18.5zM11.5 12.5H21V21l-9.5-1.4z" fill="currentColor"/></svg>',
    'windows-portable': '<svg viewBox="0 0 24 24"><path d="M4 4h7l2 2h7v14H4z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M12 10v6m-3-3h6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
    ios: '<svg viewBox="0 0 24 24"><rect x="6" y="2" width="12" height="20" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M10 18.5h4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
  };
  const rows = Object.keys(OS)
    .map((k) => {
      const o = OS[k], f = man.files[k];
      const left = `<span class="os-ic">${svg[k]}</span><span class="os-nm"><b>${o.name}</b><small>${o.sub}${f ? ' · ' + mb(f.size) : ''}</small></span>`;
      if (!f) return `<li class="row off"><div class="row-h">${left}<span class="soon">Sắp có</span></div></li>`;
      return `<li class="row" data-os="${k}"><div class="row-h">${left}<a class="get" href="/tai/${k}">Tải về</a></div><p>${esc(o.note)}</p></li>`;
    })
    .join('');
  const banks = ['Vietcombank', 'MB Bank', 'Techcombank', 'BIDV', 'VietinBank', 'Agribank', 'VPBank', 'TPBank', 'ACB', 'Sacombank', 'HDBank', 'VIB', 'MoMo', 'ZaloPay', 'Cake', 'Timo'];
  const chips = banks.map((b) => `<span>${b}</span>`).join('');
  return `<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tải VieTing – quản lý chi tiêu</title>
<meta name="description" content="VieTing - app quản lý chi tiêu, tự đọc thông báo biến động số dư ngân hàng. Android · iPhone · Windows">
<meta property="og:title" content="VieTing – quản lý chi tiêu"><meta property="og:image" content="/img/icon-256.png">
<link rel="icon" href="/img/favicon.png">
<script>try{if(localStorage.getItem("theme")==="dark")document.documentElement.dataset.theme="dark"}catch(e){}</script>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@500;600;700;800;900&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box}html,body{margin:0}
:root{--red:#C1272C;--red2:#9E1D22;--yellow:#FFCD00;--green:#3E8E41;--cream:#FFF8EC;--bg:#FFFDF8;--card:#fff;--text:#1d1916;--mute:#6d655c;--line:#efe6d8}
[data-theme=dark]{--bg:#141210;--card:#1f1c18;--text:#f4efe7;--mute:#ada296;--line:#36302a}
body{font-family:Montserrat,system-ui,sans-serif;color:var(--text);background:var(--bg);line-height:1.5}
a{color:inherit}
.in{max-width:1080px;margin:0 auto;padding:0 22px}
/* ---------- hero đỏ ---------- */
.hero{position:relative;background:var(--red);color:var(--cream);overflow:hidden;padding-bottom:90px}
.hero:before{content:"";position:absolute;inset:0 0 0 58%;opacity:.13;
 background:repeating-linear-gradient(90deg,transparent 0 34px,var(--cream) 34px 58px,transparent 58px 96px),
 repeating-linear-gradient(0deg,transparent 0 120px,var(--red) 120px 128px);
 -webkit-mask:linear-gradient(90deg,transparent,#000 40%);mask:linear-gradient(90deg,transparent,#000 40%)}
nav{position:relative;display:flex;align-items:center;justify-content:space-between;padding:20px 0}
.logo{display:flex;align-items:center;gap:10px;text-decoration:none;font-weight:900;font-size:22px;letter-spacing:-.4px}
.logo img{width:38px;height:38px;border-radius:10px;box-shadow:0 0 0 2px rgba(255,248,236,.35)}
.nav-r{display:flex;align-items:center;gap:18px;font-weight:600;font-size:14px}
.nav-r a{text-decoration:none;opacity:.9}
#th{border:0;background:rgba(255,248,236,.16);color:var(--cream);border-radius:999px;width:38px;height:38px;font-size:16px;cursor:pointer}
.hero-g{position:relative;display:grid;grid-template-columns:1.15fr .85fr;gap:30px;align-items:center;padding-top:34px}
.pill{display:inline-flex;gap:8px;align-items:center;background:rgba(255,248,236,.14);border-radius:999px;padding:6px 14px;font-size:13px;font-weight:600}
.pill i{width:8px;height:8px;border-radius:50%;background:var(--yellow);box-shadow:0 0 0 4px rgba(255,205,0,.25)}
h1{font-size:54px;line-height:1.04;margin:18px 0 16px;font-weight:900;letter-spacing:-1.5px}
h1 span{color:var(--yellow)}
.lead{font-size:17px;opacity:.92;max-width:520px;margin:0 0 26px;font-weight:500}
.cta{display:flex;flex-wrap:wrap;gap:12px;align-items:center}
.btn-y{display:inline-flex;flex-direction:column;background:var(--yellow);color:#2a1d00;text-decoration:none;font-weight:800;padding:13px 24px;border-radius:14px;font-size:16px;box-shadow:0 8px 0 #c79f00}
.btn-y small{font-weight:600;font-size:12px;opacity:.75}
.btn-y:active{transform:translateY(4px);box-shadow:0 4px 0 #c79f00}
.btn-o{color:var(--cream);text-decoration:none;font-weight:700;border-bottom:2px solid rgba(255,248,236,.5);padding-bottom:2px}
.ver{margin-top:22px;font-size:13px;opacity:.75}
/* điện thoại */
.ph{justify-self:center;position:relative;width:260px;height:470px;border-radius:40px;background:#16110e;padding:12px;box-shadow:0 30px 60px rgba(60,0,0,.45);transform:rotate(-4deg)}
.scr{height:100%;border-radius:30px;background:var(--cream);color:#1d1916;padding:84px 14px 16px;overflow:hidden;position:relative}
.tx{display:flex;align-items:center;gap:8px;padding:7px 0;border-top:1px solid #f0e3cf;font-size:11px}.tx i{width:24px;height:24px;border-radius:8px;flex:none}.tx span{flex:1;font-weight:600}.tx b{font-weight:800}
.scr .t{font-size:11px;color:#8a7f72;font-weight:600}.scr .b{font-size:26px;font-weight:900;margin:2px 0 12px}
.bar{height:8px;border-radius:6px;background:#f0e3cf;margin:7px 0;overflow:hidden}.bar i{display:block;height:100%;border-radius:6px}
.lab{display:flex;justify-content:space-between;font-size:11px;font-weight:600;color:#6d655c}
.toast{position:absolute;left:10px;right:10px;top:-80px;background:#fff;border-radius:16px;padding:10px 12px;box-shadow:0 10px 24px rgba(0,0,0,.18);display:flex;gap:10px;align-items:center;animation:ting 6s ease-in-out infinite}
.toast img{width:30px;height:30px;border-radius:8px}.toast b{display:block;font-size:12px}.toast small{font-size:11px;color:#6d655c}
.toast .m{color:var(--red);font-weight:800}
@keyframes ting{0%{top:-80px}8%,80%{top:12px}90%,100%{top:-80px}}
.ring{position:absolute;right:-36px;top:30px;width:90px;height:90px}
.ring path{fill:none;stroke:var(--yellow);stroke-width:7;stroke-linecap:round;animation:pulse 1.6s ease-in-out infinite}
.ring path:nth-child(2){animation-delay:.25s}
@keyframes pulse{0%,100%{opacity:.25}50%{opacity:1}}
.wave{position:absolute;left:0;right:0;bottom:-1px;width:100%;height:70px;display:block}
/* ---------- nội dung ---------- */
section{padding:56px 0 8px}
.kick{color:var(--red);font-weight:800;font-size:13px;letter-spacing:1.5px;text-transform:uppercase}
h2{font-size:34px;font-weight:900;letter-spacing:-.8px;margin:6px 0 24px;line-height:1.15}
.dl{display:grid;grid-template-columns:.9fr 1.1fr;gap:36px;align-items:start}
.dl-side p{color:var(--mute);margin:0 0 14px}
.list{list-style:none;margin:0;padding:0;border:1px solid var(--line);border-radius:22px;background:var(--card);overflow:hidden}
.row{padding:18px 20px;border-top:1px solid var(--line)}.row:first-child{border-top:0}
.row-h{display:flex;align-items:center;gap:14px}
.os-ic{width:46px;height:46px;flex:none;border-radius:14px;display:grid;place-items:center;background:rgba(193,39,44,.09);color:var(--red)}
.os-ic svg{width:24px;height:24px}
.os-nm{flex:1}.os-nm b{display:block;font-size:17px}.os-nm small{color:var(--mute);font-weight:600}
.get{background:var(--red);color:#fff;text-decoration:none;font-weight:800;padding:10px 18px;border-radius:12px;font-size:14px}
.get:hover{background:var(--red2)}
.soon{font-size:13px;font-weight:700;color:var(--mute);background:var(--line);padding:6px 12px;border-radius:999px}
.row p{margin:10px 0 0 60px;color:var(--mute);font-size:13px}
.row.off .os-ic{background:var(--line);color:var(--mute)}
.row.me{background:rgba(255,205,0,.12)}
.steps{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;counter-reset:s}
.st{position:relative;padding:22px;border-radius:22px;background:var(--card);border:1px solid var(--line)}
.st:before{counter-increment:s;content:counter(s);display:grid;place-items:center;width:40px;height:40px;border-radius:12px;background:var(--yellow);color:#2a1d00;font-weight:900;margin-bottom:12px}
.st b{display:block;font-size:17px;margin-bottom:4px}.st p{margin:0;color:var(--mute);font-size:14px}
.ios{margin-top:18px;display:flex;gap:14px;align-items:flex-start;background:var(--card);border:1px dashed var(--red);border-radius:18px;padding:16px 18px;font-size:14px;color:var(--mute)}
.ios b{color:var(--text)}
.mq{overflow:hidden;border-block:1px solid var(--line);margin-top:56px;padding:16px 0;
 -webkit-mask:linear-gradient(90deg,transparent,#000 10%,#000 90%,transparent);mask:linear-gradient(90deg,transparent,#000 10%,#000 90%,transparent)}
.mq div{display:flex;gap:12px;width:max-content;animation:mq 30s linear infinite}
.mq span{white-space:nowrap;font-weight:700;padding:8px 16px;border-radius:999px;background:var(--card);border:1px solid var(--line)}
@keyframes mq{to{transform:translateX(-50%)}}
footer{padding:36px 0 44px;text-align:center;color:var(--mute);font-size:13px}
footer .logo{justify-content:center;color:var(--text);margin-bottom:6px}
@media(max-width:820px){.hero-g,.dl{grid-template-columns:1fr}h1{font-size:40px}.ph{display:none}.steps{grid-template-columns:1fr}.nav-r a{display:none}.hero:before{inset:0}}
@media(prefers-reduced-motion:reduce){.toast,.ring path,.mq div{animation:none}.toast{top:12px}}
</style></head><body>
<header class="hero"><div class="in">
<nav><a class="logo" href="/tai-app"><img src="/img/icon-256.png" alt="">VieTing</a>
<div class="nav-r"><a href="#tai">Tải về</a><a href="#cach">Cách hoạt động</a><button id="th" aria-label="Đổi giao diện sáng/tối">🌙</button></div></nav>
<div class="hero-g"><div>
<span class="pill"><i></i>Tự đọc biến động số dư ngân hàng</span>
<h1>Tiền vào, tiền ra.<br>Nghe <span>“ting”</span> là<br>đã ghi sổ.</h1>
<p class="lead">VieTing đọc thông báo của app ngân hàng, tự ghi từng khoản thu chi, xếp danh mục và khớp số dư. Bạn chỉ việc xem.</p>
<div class="cta"><a class="btn-y" id="mb" href="#tai">Tải VieTing miễn phí<small>Android · iPhone · Windows</small></a><a class="btn-o" href="#cach">Xem cách hoạt động</a></div>
<div class="ver">${man.version ? 'Phiên bản ' + esc(man.version) + (built ? ' · cập nhật ' + esc(built) : '') : 'Bản đầu tiên sắp ra mắt'}</div>
</div>
<div class="ph"><svg class="ring" viewBox="0 0 90 90"><path d="M20 60a30 30 0 0 0 40-40"/><path d="M14 80a52 52 0 0 0 66-66"/></svg>
<div class="scr"><div class="toast"><img src="/img/icon-256.png" alt=""><div><b>Đã ghi tự động</b><small><span class="m">−55.000 ₫</span> · Ăn uống · Highlands</small></div></div>
<div class="t">Tổng số dư</div><div class="b">12.450.000 ₫</div>
<div class="lab"><span>Ăn uống</span><span>2,1 tr</span></div><div class="bar"><i style="width:72%;background:#E8710A"></i></div>
<div class="lab"><span>Đi lại</span><span>860k</span></div><div class="bar"><i style="width:38%;background:#1E88E5"></i></div>
<div class="lab"><span>Mua sắm</span><span>1,4 tr</span></div><div class="bar"><i style="width:55%;background:#D81B60"></i></div>
<div class="lab"><span>Hóa đơn</span><span>640k</span></div><div class="bar"><i style="width:26%;background:#6D4C41"></i></div>
<div class="lab" style="margin-top:12px"><span>Ngân sách tháng</span><span>68%</span></div><div class="bar"><i style="width:68%;background:#3E8E41"></i></div>
<div style="margin-top:10px">
<div class="tx"><i style="background:#E8710A33"></i><span>Highlands</span><b style="color:#C1272C">−55k</b></div>
<div class="tx"><i style="background:#2E7D3233"></i><span>Lương tháng 11</span><b style="color:#2E7D32">+15 tr</b></div>
<div class="tx"><i style="background:#1E88E533"></i><span>Grab</span><b style="color:#C1272C">−42k</b></div>
</div></div></div>
</div></div>
<svg class="wave" viewBox="0 0 1440 70" preserveAspectRatio="none"><path d="M0 40C240 80 480 0 720 22s480 48 720 8V70H0z" fill="var(--bg)"/></svg>
</header>
<main class="in">
<section id="tai"><div class="dl"><div class="dl-side"><div class="kick">Tải về</div><h2>Chọn bản cho máy của bạn</h2>
<p>Một tài khoản dùng chung cho mọi máy: điện thoại Android tự ghi giao dịch, iPhone và máy tính xem lại ngay khi đăng nhập.</p>
<p>Link tải cố định để chia sẻ: <b>/tai/android</b>, <b>/tai/windows</b>, <b>/tai/ios</b>.</p></div>
<ul class="list">${rows}</ul></div></section>
<section id="cach"><div class="kick">Cách hoạt động</div><h2>Ba bước, sau đó app tự làm</h2>
<div class="steps"><div class="st"><b>Bật đọc thông báo</b><p>Cho VieTing quyền đọc thông báo một lần. OTP, tin nhắn chat và quảng cáo đều bị bỏ qua.</p></div>
<div class="st"><b>Có biến động là tự ghi</b><p>Số tiền +/−, số dư, nội dung chuyển khoản được ghi thành giao dịch, xếp đúng danh mục.</p></div>
<div class="st"><b>Xem và đặt ngân sách</b><p>Biểu đồ chi theo danh mục, 7 ngày qua, hạn mức tháng và gợi ý chi mỗi ngày.</p></div></div>
<div class="ios"><span>📱</span><div><b>Dùng iPhone?</b> Apple không cho app đọc thông báo của app khác. Trên iPhone, VieTing ghi tự động qua Phím tắt khi có SMS ngân hàng, hoặc bạn bấm "Dán thông báo".</div></div>
</section>
<div class="mq" aria-label="Ngân hàng và ví hỗ trợ"><div>${chips}${chips}</div></div>
</main>
<footer><a class="logo" href="/tai-app"><img src="/img/icon-256.png" alt="">VieTing</a>© 2026 VieTing · Phạm Thành Long (thlong)</footer>
<script>(function(){var d=document.documentElement,t=document.getElementById('th');function set(v){if(v==='dark')d.dataset.theme='dark';else delete d.dataset.theme;t.textContent=v==='dark'?'☀':'🌙';try{localStorage.setItem('theme',v)}catch(e){}}set(d.dataset.theme==='dark'?'dark':'light');t.onclick=function(){set(d.dataset.theme==='dark'?'light':'dark')};})();
(function(){var u=navigator.userAgent,k=/Android/i.test(u)?'android':/iPhone|iPad|iPod/i.test(u)?'ios':/Windows/i.test(u)?'windows':'';
var r=k&&document.querySelector('.row[data-os="'+k+'"]'),b=document.getElementById('mb');
if(r){r.classList.add('me');b.href=r.querySelector('a.get').getAttribute('href');b.innerHTML='Tải cho '+r.querySelector('b').textContent+'<small>'+r.querySelector('small').textContent+'</small>';}})();</script>
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
