// Trang quản trị VieTing (/admin) + API /api/admin/*. Tác giả: Phạm Thành Long (thlong)
//
// Admin đăng nhập bằng chính tài khoản VieTing của mình; tài khoản phải nằm trong bảng `admins`
// (chạy dat-admin.bat ở thư mục gốc để cấp quyền lần đầu).
// Admin chỉ xem số liệu tổng hợp (số giao dịch, lần đồng bộ cuối...), KHÔNG xem nội dung chi tiêu của người dùng.

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
      await env.DB.prepare('SELECT day, SUM(n) AS n, COUNT(*) AS people FROM ai_usage WHERE day >= ? GROUP BY day ORDER BY day')
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
                EXISTS (SELECT 1 FROM admins a WHERE a.user_id = u.id) AS admin
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
  await env.DB.prepare('INSERT INTO notices (title, body, level, active, created) VALUES (?, ?, ?, 1, ?)')
    .bind(title, body, level, Date.now())
    .run();
  await log(env, adminId, 'notice', title);
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

const PAGE = `<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>VieTing · Quản trị</title>
<link rel="icon" href="/icon.png">
<style>
  :root{--red:#C1272C;--navy:#152758;--bamboo:#3E8E41;--yellow:#FFCD00;--bg:#F6F4EF;--card:#fff;--line:#E7E2D8;--muted:#6B6A66;--ink:#1C1B19}
  *{box-sizing:border-box}
  body{margin:0;font-family:"Be Vietnam Pro",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--ink);font-size:14.5px}
  button,input,select,textarea{font:inherit}
  .hidden{display:none!important}
  /* login */
  #login{min-height:100vh;display:grid;place-items:center;padding:20px;background:var(--navy)}
  .lbox{width:100%;max-width:360px;background:#fff;border-radius:20px;padding:28px}
  .lbox h1{margin:10px 0 2px;font-size:22px}
  .lbox p{margin:0 0 18px;color:var(--muted)}
  label{display:block;font-size:12.5px;color:var(--muted);margin:12px 0 4px}
  input,select,textarea{width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:#fff}
  textarea{min-height:90px;resize:vertical}
  .btn{border:0;border-radius:10px;padding:10px 16px;font-weight:700;cursor:pointer;background:var(--red);color:#fff}
  .btn.ghost{background:transparent;color:var(--ink);border:1px solid var(--line)}
  .btn.navy{background:var(--navy)}
  .btn.sm{padding:6px 10px;font-size:12.5px;font-weight:600}
  .err{color:var(--red);min-height:20px;margin-top:10px;font-size:13px}
  /* layout */
  header{background:var(--navy);color:#fff;display:flex;align-items:center;gap:12px;padding:12px 20px;position:sticky;top:0;z-index:5}
  header b{font-size:17px}
  header .sp{flex:1}
  header small{opacity:.75}
  nav{display:flex;gap:4px;padding:10px 20px 0;max-width:1180px;margin:0 auto;flex-wrap:wrap}
  nav button{border:0;background:transparent;padding:10px 14px;border-radius:10px 10px 0 0;cursor:pointer;color:var(--muted);font-weight:600;border-bottom:3px solid transparent}
  nav button.on{color:var(--red);border-bottom-color:var(--red)}
  main{max-width:1180px;margin:0 auto;padding:16px 20px 60px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:12px}
  .card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px}
  .kpi .n{font-size:28px;font-weight:800;letter-spacing:-.5px}
  .kpi .l{color:var(--muted);font-size:12.5px;margin-top:2px}
  .row{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:12px}
  @media (max-width:820px){.row{grid-template-columns:1fr}}
  h3{margin:0 0 10px;font-size:15px}
  .bars{display:flex;align-items:flex-end;gap:3px;height:140px;padding-top:6px}
  .bars div{flex:1;background:var(--red);border-radius:4px 4px 0 0;min-height:2px;position:relative}
  .bars.navy div{background:var(--navy)}
  .bars div:hover::after{content:attr(data-t);position:absolute;bottom:100%;left:50%;transform:translateX(-50%);background:#000;color:#fff;font-size:11px;padding:3px 6px;border-radius:6px;white-space:nowrap;margin-bottom:4px}
  .axis{display:flex;justify-content:space-between;color:var(--muted);font-size:11px;margin-top:6px}
  table{width:100%;border-collapse:collapse}
  th,td{text-align:left;padding:10px 8px;border-bottom:1px solid var(--line);vertical-align:middle}
  th{font-size:12px;color:var(--muted);font-weight:600;white-space:nowrap}
  .tw{overflow-x:auto}
  .pill{display:inline-block;padding:2px 8px;border-radius:99px;font-size:11.5px;font-weight:700}
  .pill.red{background:#FBE3E3;color:var(--red)}
  .pill.navy{background:#E3E8F5;color:var(--navy)}
  .pill.green{background:#E2F1E2;color:var(--bamboo)}
  .pill.gray{background:#EEECE7;color:var(--muted)}
  .tools{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}
  .tools input{max-width:320px}
  .menu{position:relative;display:inline-block}
  .menu .list{position:absolute;right:0;top:100%;background:#fff;border:1px solid var(--line);border-radius:12px;box-shadow:0 8px 24px #0002;min-width:200px;z-index:4;padding:4px}
  .menu .list button{display:block;width:100%;text-align:left;border:0;background:none;padding:9px 12px;border-radius:8px;cursor:pointer}
  .menu .list button:hover{background:var(--bg)}
  .menu .list button.danger{color:var(--red)}
  .muted{color:var(--muted)}
  .note{background:#FFF8E1;border:1px solid #F5E2A8;border-radius:12px;padding:10px 14px;font-size:13px;margin-bottom:12px}
  .toast{position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:var(--ink);color:#fff;padding:12px 18px;border-radius:12px;z-index:20;max-width:90vw}
  .nl{display:flex;gap:12px;align-items:flex-start;padding:12px 0;border-bottom:1px solid var(--line)}
  .nl:last-child{border-bottom:0}
  .nl .t{font-weight:700}
  .preview{border-radius:14px;padding:12px 14px;margin-top:12px}
  .preview.info{background:#E3E8F5}.preview.success{background:#E2F1E2}.preview.warning{background:#FFF1D6}
  dialog{border:0;border-radius:16px;padding:22px;max-width:420px;width:92vw}
  dialog::backdrop{background:#0006}
</style>
</head>
<body>
<section id="login">
  <form class="lbox" id="lf">
    <svg width="48" height="48" viewBox="0 0 64 64"><rect width="64" height="64" rx="16" fill="#C1272C"/><path d="M18 18 L32 46 L46 18" stroke="#FFF8EC" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle cx="32" cy="14" r="4" fill="#FFCD00"/></svg>
    <h1>Quản trị VieTing</h1>
    <p>Đăng nhập bằng tài khoản VieTing có quyền admin.</p>
    <label>Email</label><input id="em" type="email" autocomplete="username" required>
    <label>Mật khẩu</label><input id="pw" type="password" autocomplete="current-password" required>
    <div class="err" id="lerr"></div>
    <button class="btn" style="width:100%;margin-top:6px">Đăng nhập</button>
  </form>
</section>

<section id="app" class="hidden">
  <header><b>VieTing</b><small>Quản trị</small><span class="sp"></span><small id="me"></small><button class="btn sm ghost" style="color:#fff;border-color:#fff4" id="out">Đăng xuất</button></header>
  <nav id="tabs">
    <button data-t="dash" class="on">Tổng quan</button>
    <button data-t="users">Người dùng</button>
    <button data-t="notice">Thông báo tới app</button>
    <button data-t="log">Nhật ký</button>
  </nav>
  <main>
    <div id="dash">
      <div class="grid" id="kpis"></div>
      <div class="row">
        <div class="card"><h3>Đăng ký mới · 30 ngày</h3><div class="bars" id="b1"></div><div class="axis" id="a1"></div></div>
        <div class="card"><h3>Giao dịch được đồng bộ · 30 ngày</h3><div class="bars navy" id="b2"></div><div class="axis" id="a2"></div></div>
      </div>
      <div class="row">
        <div class="card"><h3>Trợ lý AI · 14 ngày</h3><div id="ai"></div></div>
        <div class="card"><h3>Hệ thống</h3><div id="sys"></div></div>
      </div>
    </div>

    <div id="users" class="hidden">
      <div class="note">Vì quyền riêng tư, trang quản trị chỉ hiện số lượng (số giao dịch, lần đồng bộ cuối…), không hiện nội dung chi tiêu của người dùng.</div>
      <div class="tools">
        <input id="q" placeholder="Tìm theo email…">
        <select id="sort" style="max-width:200px"><option value="new">Mới đăng ký</option><option value="active">Hoạt động gần nhất</option></select>
        <span class="sp"></span>
      </div>
      <div class="card tw"><table><thead><tr><th>Email</th><th>Đăng ký</th><th>Đồng bộ cuối</th><th>Giao dịch</th><th>Thiết bị</th><th>Trạng thái</th><th></th></tr></thead><tbody id="ub"></tbody></table>
      <div style="display:flex;gap:8px;justify-content:space-between;align-items:center;margin-top:12px"><span class="muted" id="ucount"></span><span><button class="btn sm ghost" id="prev">‹ Trước</button> <button class="btn sm ghost" id="next">Sau ›</button></span></div></div>
    </div>

    <div id="notice" class="hidden">
      <div class="row" style="margin-top:0">
        <div class="card">
          <h3>Gửi thông báo mới</h3>
          <p class="muted" style="margin-top:0">Hiện ở đầu trang Tổng quan trong app của mọi người dùng (người dùng có thể tắt). Chỉ thông báo mới nhất đang bật được hiện.</p>
          <label>Tiêu đề</label><input id="nt" maxlength="120" placeholder="VD: Đã có bản 0.2 – tách hóa đơn siêu thị">
          <label>Nội dung</label><textarea id="nb" maxlength="1000"></textarea>
          <label>Kiểu</label><select id="nlv"><option value="info">Thông tin</option><option value="success">Tin vui</option><option value="warning">Cảnh báo / bảo trì</option></select>
          <div class="preview info" id="npv"><b>Tiêu đề</b><div class="muted">Nội dung</div></div>
          <button class="btn" style="margin-top:12px" id="nsend">Gửi tới app</button>
        </div>
        <div class="card"><h3>Đã gửi</h3><div id="nlist"></div></div>
      </div>
    </div>

    <div id="log" class="hidden"><div class="card tw"><table><thead><tr><th>Thời gian</th><th>Admin</th><th>Thao tác</th><th>Đối tượng</th></tr></thead><tbody id="lb"></tbody></table></div></div>
  </main>
</section>

<dialog id="dlg"><div id="dlgc"></div><div style="display:flex;gap:8px;justify-content:flex-end;margin-top:16px"><button class="btn ghost" id="dno">Hủy</button><button class="btn" id="dok">Đồng ý</button></div></dialog>

<script>
const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let token=sessionStorage.getItem('vt_admin')||'';
const fmt=n=>Number(n||0).toLocaleString('vi-VN');
const ago=ms=>{if(!ms)return '<span class="muted">chưa</span>';const m=(Date.now()-ms)/60000;if(m<60)return Math.max(1,Math.round(m))+' phút trước';if(m<1440)return Math.round(m/60)+' giờ trước';const d=Math.round(m/1440);return d<60?d+' ngày trước':new Date(ms).toLocaleDateString('vi-VN')};
const date=ms=>new Date(ms).toLocaleDateString('vi-VN');
function toast(t){const e=document.createElement('div');e.className='toast';e.textContent=t;document.body.append(e);setTimeout(()=>e.remove(),3500)}
async function api(path,body){
  const r=await fetch('/api'+path,{method:body?'POST':'GET',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:body?JSON.stringify(body):undefined});
  const j=await r.json().catch(()=>({error:'Lỗi mạng'}));
  if(r.status===401||r.status===403){if(path.startsWith('/admin')){logout(j.error);}throw new Error(j.error||'Không có quyền')}
  if(!r.ok)throw new Error(j.error||'Lỗi');
  return j;
}
function ask(html,okText='Đồng ý'){return new Promise(res=>{$('#dlgc').innerHTML=html;$('#dok').textContent=okText;const d=$('#dlg');d.showModal();$('#dok').onclick=()=>{d.close();res(true)};$('#dno').onclick=()=>{d.close();res(false)}})}
function logout(msg){token='';sessionStorage.removeItem('vt_admin');$('#app').classList.add('hidden');$('#login').classList.remove('hidden');if(msg)$('#lerr').textContent=msg}
$('#out').onclick=()=>logout();
$('#lf').onsubmit=async e=>{e.preventDefault();$('#lerr').textContent='';
  try{const r=await fetch('/api/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:$('#em').value,password:$('#pw').value})});const j=await r.json();if(!r.ok)throw new Error(j.error||'Sai thông tin');token=j.token;sessionStorage.setItem('vt_admin',token);await start()}catch(err){$('#lerr').textContent=err.message}};
async function start(){const me=await api('/admin/me');$('#me').textContent=me.email;$('#login').classList.add('hidden');$('#app').classList.remove('hidden');show('dash')}
$('#tabs').onclick=e=>{const t=e.target.dataset.t;if(t)show(t)};
function show(t){for(const b of document.querySelectorAll('#tabs button'))b.classList.toggle('on',b.dataset.t===t);for(const s of ['dash','users','notice','log'])$('#'+s).classList.toggle('hidden',s!==t);({dash:loadDash,users:loadUsers,notice:loadNotices,log:loadLog})[t]()}
function bars(el,ax,days,vals){const max=Math.max(1,...vals);$(el).innerHTML=vals.map((v,i)=>'<div style="height:'+(v/max*100)+'%" data-t="'+days[i].slice(8)+'/'+days[i].slice(5,7)+': '+v+'"></div>').join('');$(ax).innerHTML='<span>'+days[0].slice(8)+'/'+days[0].slice(5,7)+'</span><span>hôm nay</span>'}
async function loadDash(){
  const s=await api('/admin/stats');
  const k=[[s.users,'Người dùng'],[s.new7,'Mới trong 7 ngày'],[s.active1,'Hoạt động hôm nay'],[s.active7,'Hoạt động 7 ngày'],[s.active30,'Hoạt động 30 ngày'],[s.txns,'Giao dịch đang lưu'],[s.banned,'Tài khoản bị khóa'],[s.admins,'Admin']];
  $('#kpis').innerHTML=k.map(([n,l])=>'<div class="card kpi"><div class="n">'+fmt(n)+'</div><div class="l">'+l+'</div></div>').join('');
  bars('#b1','#a1',s.days,s.signups);bars('#b2','#a2',s.days,s.txnDays);
  $('#ai').innerHTML=s.ai.length?'<table><tr><th>Ngày</th><th>Lượt hỏi</th><th>Số người</th></tr>'+s.ai.slice().reverse().map(r=>'<tr><td>'+esc(r.day)+'</td><td>'+fmt(r.n)+'</td><td>'+fmt(r.people)+'</td></tr>').join('')+'</table>':'<p class="muted">Chưa có lượt hỏi nào.</p>';
  $('#sys').innerHTML='<p>Trợ lý AI đang dùng: <b>'+esc(s.ai_provider)+'</b></p><p class="muted">Giới hạn 80 lượt AI / người / ngày để nằm trong gói miễn phí.</p><p><a href="/tai-app" target="_blank">Mở trang tải app ↗</a></p>';
}
let off=0,timer;
$('#q').oninput=()=>{clearTimeout(timer);timer=setTimeout(()=>{off=0;loadUsers()},300)};
$('#sort').onchange=()=>{off=0;loadUsers()};
$('#prev').onclick=()=>{off=Math.max(0,off-50);loadUsers()};
$('#next').onclick=()=>{off+=50;loadUsers()};
async function loadUsers(){
  const j=await api('/admin/users?q='+encodeURIComponent($('#q').value)+'&sort='+$('#sort').value+'&offset='+off);
  $('#ucount').textContent=j.total?('Hiển thị '+(off+1)+'–'+(off+j.users.length)+' / '+fmt(j.total)):'Không có ai';
  $('#prev').disabled=off===0;$('#next').disabled=off+50>=j.total;
  $('#ub').innerHTML=j.users.map(u=>'<tr><td><b>'+esc(u.email)+'</b>'+(u.admin?' <span class="pill navy">admin</span>':'')+'</td><td>'+date(u.created)+'</td><td>'+ago(u.last)+'</td><td>'+fmt(u.txn)+'</td><td>'+fmt(u.devices)+'</td><td>'+(u.banned!==null&&u.banned!==undefined?'<span class="pill red">Đã khóa</span>':(u.last&&Date.now()-u.last<7*864e5?'<span class="pill green">Đang dùng</span>':'<span class="pill gray">Ít dùng</span>'))+'</td><td style="text-align:right"><div class="menu"><button class="btn sm ghost" data-m="'+u.id+'">⋯</button><div class="list hidden" id="m'+u.id+'">'
    +(u.banned!==null&&u.banned!==undefined?'<button data-a="unban" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Mở khóa tài khoản</button>':'<button data-a="ban" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Khóa tài khoản</button>')
    +'<button data-a="logout" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Đăng xuất mọi thiết bị</button>'
    +'<button data-a="reset" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Đặt lại mật khẩu</button>'
    +(u.admin?'<button data-a="unadmin" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Bỏ quyền admin</button>':'<button data-a="admin" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Cấp quyền admin</button>')
    +'<button class="danger" data-a="delete" data-id="'+u.id+'" data-e="'+esc(u.email)+'">Xóa tài khoản + dữ liệu</button></div></div></td></tr>').join('');
}
document.addEventListener('click',async e=>{
  const m=e.target.closest('[data-m]');
  for(const l of document.querySelectorAll('.menu .list'))if(!m||l.id!=='m'+m.dataset.m)l.classList.add('hidden');
  if(m){$('#m'+m.dataset.m).classList.toggle('hidden');return}
  const a=e.target.closest('[data-a]');if(!a)return;
  const id=a.dataset.id,em=a.dataset.e,act=a.dataset.a;
  const txt={ban:['Khóa tài khoản <b>'+esc(em)+'</b>?','Người này bị đăng xuất và không đăng nhập / đồng bộ được nữa. Dữ liệu vẫn giữ.<label>Lý do (không bắt buộc)</label><input id="why">','Khóa'],
    unban:['Mở khóa <b>'+esc(em)+'</b>?','','Mở khóa'],
    logout:['Đăng xuất <b>'+esc(em)+'</b> khỏi mọi thiết bị?','Họ cần đăng nhập lại, dữ liệu không mất.','Đăng xuất'],
    reset:['Đặt lại mật khẩu cho <b>'+esc(em)+'</b>?','Mật khẩu mới sẽ hiện một lần để bạn gửi cho họ. Các thiết bị đang đăng nhập sẽ bị đăng xuất.','Đặt lại'],
    admin:['Cấp quyền admin cho <b>'+esc(em)+'</b>?','Người này sẽ vào được trang quản trị này.','Cấp quyền'],
    unadmin:['Bỏ quyền admin của <b>'+esc(em)+'</b>?','','Bỏ quyền'],
    delete:['Xóa vĩnh viễn <b>'+esc(em)+'</b>?','Toàn bộ giao dịch, ví, ngân sách… của tài khoản này trên server bị xóa và <b>không khôi phục được</b>.<label>Gõ <b>XOA</b> để xác nhận</label><input id="cf">','Xóa vĩnh viễn']}[act];
  if(!await ask('<h3>'+txt[0]+'</h3><p class="muted">'+txt[1]+'</p>',txt[2]))return;
  if(act==='delete'&&($('#cf')?.value||'').trim().toUpperCase()!=='XOA'){toast('Chưa gõ XOA, không xóa');return}
  try{const r=await api('/admin/user',{id:Number(id),action:act,reason:$('#why')?.value||''});
    if(r.password){await ask('<h3>Mật khẩu mới của '+esc(em)+'</h3><p style="font-size:22px;font-weight:800;letter-spacing:1px">'+esc(r.password)+'</p><p class="muted">Gửi riêng cho người dùng và nhắc họ đổi lại. Mật khẩu này không hiện lại nữa.</p>','Đã chép');}
    else toast('Xong');loadUsers()}catch(err){toast(err.message)}
});
function pv(){const p=$('#npv');p.className='preview '+$('#nlv').value;p.innerHTML='<b>'+esc($('#nt').value||'Tiêu đề')+'</b><div class="muted">'+esc($('#nb').value||'Nội dung')+'</div>'}
['#nt','#nb','#nlv'].forEach(s=>$(s).addEventListener('input',pv));
$('#nsend').onclick=async()=>{try{await api('/admin/notice',{title:$('#nt').value,body:$('#nb').value,level:$('#nlv').value});$('#nt').value='';$('#nb').value='';pv();toast('Đã gửi tới app');loadNotices()}catch(e){toast(e.message)}};
async function loadNotices(){const j=await api('/admin/notices');$('#nlist').innerHTML=j.notices.length?j.notices.map(n=>'<div class="nl"><div style="flex:1"><div class="t">'+esc(n.title)+' '+(n.active?'<span class="pill green">đang hiện</span>':'<span class="pill gray">đã tắt</span>')+'</div><div class="muted">'+esc(n.body)+'</div><small class="muted">'+date(n.created)+'</small></div><button class="btn sm ghost" data-nt="'+n.id+'">'+(n.active?'Tắt':'Bật lại')+'</button><button class="btn sm ghost" data-nd="'+n.id+'">Xóa</button></div>').join(''):'<p class="muted">Chưa gửi thông báo nào.</p>'}
$('#nlist').onclick=async e=>{const t=e.target.dataset.nt,d=e.target.dataset.nd;try{if(t)await api('/admin/notice',{id:Number(t),toggle:true});if(d&&await ask('<h3>Xóa thông báo này?</h3>','Xóa'))await api('/admin/notice',{id:Number(d),remove:true});loadNotices()}catch(err){toast(err.message)}};
const ACT={ban:'Khóa',unban:'Mở khóa',logout:'Đăng xuất mọi thiết bị',reset:'Đặt lại mật khẩu',admin:'Cấp admin',unadmin:'Bỏ admin',delete:'Xóa tài khoản',notice:'Gửi thông báo','notice-toggle':'Bật/tắt thông báo','notice-delete':'Xóa thông báo'};
async function loadLog(){const j=await api('/admin/log');$('#lb').innerHTML=j.log.map(l=>'<tr><td>'+new Date(l.created).toLocaleString('vi-VN')+'</td><td>'+esc(l.admin)+'</td><td>'+esc(ACT[l.action]||l.action)+'</td><td>'+esc(l.target)+'</td></tr>').join('')||'<tr><td colspan="4" class="muted">Chưa có thao tác nào.</td></tr>'}
if(token)start().catch(()=>logout());
</script>
</body>
</html>`;
