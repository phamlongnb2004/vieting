// Đăng nhập bằng Google + Quên mật khẩu cho VieTing. Tác giả: Phạm Thành Long (thlong)
//
// Đăng nhập Google chạy giống nhau trên Android, iPhone và Windows:
//   1. App tạo mã ngẫu nhiên (state), mở trình duyệt tới /auth/google/start?state=...
//   2. Người dùng chọn tài khoản Google, Google trả về /auth/google/callback
//   3. Server đổi mã lấy email đã xác minh, tạo phiên đăng nhập, gắn với state
//   4. App hỏi /api/auth/google/poll {state} cho tới khi nhận được phiên (một lần duy nhất)
// Cần 2 khóa (chạy dat-google.bat): GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (OAuth client loại "Web application").
//
// Quên mật khẩu: POST /api/password/forgot {email} gửi mã 6 số qua email, POST /api/password/reset
// {email, code, password} đặt mật khẩu mới. Gửi email bằng Resend (RESEND_API_KEY + MAIL_FROM) hoặc
// Gmail (SMTP_USER + SMTP_PASS là mật khẩu ứng dụng của Gmail, chạy dat-email.bat).
// POST /api/password/set {old?, password} (đã đăng nhập): đặt / đổi mật khẩu, tài khoản tạo bằng Google không cần mật khẩu cũ.

import { connect } from 'cloudflare:sockets';

let ready = false;
export async function ensureAuthSchema(env) {
  if (ready || !env.DB) return;
  await env.DB.batch([
    env.DB.prepare('CREATE TABLE IF NOT EXISTS oauth_pending (state TEXT PRIMARY KEY, created INTEGER NOT NULL, token TEXT, email TEXT)'),
    env.DB.prepare('CREATE TABLE IF NOT EXISTS pw_reset (email TEXT PRIMARY KEY, code_hash TEXT, salt TEXT, exp INTEGER, tries INTEGER DEFAULT 0, sent_at INTEGER, sent_day TEXT, sent_n INTEGER DEFAULT 0)'),
  ]);
  for (const sql of ['ALTER TABLE users ADD COLUMN google_sub TEXT', 'ALTER TABLE users ADD COLUMN nopw INTEGER DEFAULT 0', 'ALTER TABLE users ADD COLUMN full_name TEXT', 'ALTER TABLE users ADD COLUMN birth_year INTEGER']) {
    try {
      await env.DB.prepare(sql).run();
    } catch {
      /* đã có cột */
    }
  }
  ready = true;
}

const T = {
  vi: {
    ok: 'Đăng nhập thành công',
    okSub: 'Quay lại app VieTing, app sẽ tự đăng nhập trong vài giây. Bạn có thể đóng trang này.',
    back: 'Mở lại VieTing',
    fail: 'Chưa đăng nhập được',
    off: 'Server chưa bật đăng nhập Google. Chủ app cần chạy dat-google.bat.',
    bad: 'Liên kết đăng nhập không hợp lệ hoặc đã hết hạn. Quay lại app và bấm "Tiếp tục với Google" lần nữa.',
    unverified: 'Email Google này chưa được xác minh.',
    banned: 'Tài khoản đã bị khóa',
    cancel: 'Bạn đã hủy đăng nhập Google.',
  },
  en: {
    ok: 'Signed in',
    okSub: 'Go back to the VieTing app, it will sign you in within a few seconds. You can close this page.',
    back: 'Open VieTing',
    fail: "Couldn't sign in",
    off: "Google sign-in isn't enabled on the server yet.",
    bad: 'This sign-in link is invalid or expired. Go back to the app and tap "Continue with Google" again.',
    unverified: "This Google email isn't verified.",
    banned: 'This account has been locked',
    cancel: 'You cancelled Google sign-in.',
  },
};

function page(lang, ok, title, sub) {
  const t = T[lang] || T.vi;
  const color = ok ? '#1F8A4C' : '#C1272C';
  return new Response(
    `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>VieTing</title>
<style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#F4F6FB;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#152758}
.c{background:#fff;border-radius:20px;padding:36px 28px;max-width:380px;margin:20px;text-align:center;box-shadow:0 10px 40px rgba(21,39,88,.10)}
.i{width:64px;height:64px;border-radius:50%;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;background:${color}1a;color:${color};font-size:34px;font-weight:700}
h1{font-size:22px;margin:0 0 8px}p{color:#5B6785;line-height:1.5;margin:0 0 22px}
a{display:inline-block;background:#152758;color:#fff;text-decoration:none;padding:12px 22px;border-radius:12px;font-weight:600}</style></head>
<body><div class="c"><div class="i">${ok ? '✓' : '!'}</div><h1>${title}</h1><p>${sub}</p>${ok ? `<a href="vieting://login">${t.back}</a>` : ''}</div></body></html>`,
    { status: ok ? 200 : 400, headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } }
  );
}

function b64urlJson(s) {
  const b = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4));
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(b, (c) => c.charCodeAt(0))));
}

async function sha(s) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function handleAuth(req, env, url, h) {
  const p = url.pathname;
  if (!(p.startsWith('/auth/google/') || p.startsWith('/api/auth/google/') || p.startsWith('/api/password/') || p === '/api/profile')) return null;
  await ensureAuthSchema(env);
  const lang = /^en/i.test(url.searchParams.get('lang') || req.headers.get('accept-language') || '') ? 'en' : 'vi';
  const t = T[lang];
  const redirect = url.origin + '/auth/google/callback';

  // 1. App mở trang này trong trình duyệt
  if (req.method === 'GET' && p === '/auth/google/start') {
    if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) return page(lang, false, t.fail, t.off);
    const state = url.searchParams.get('state') || '';
    if (!/^[a-f0-9]{32,64}$/.test(state)) return page(lang, false, t.fail, t.bad);
    const now = Date.now();
    await env.DB.prepare('DELETE FROM oauth_pending WHERE created < ?').bind(now - 15 * 60_000).run();
    await env.DB.prepare('INSERT OR IGNORE INTO oauth_pending (state, created) VALUES (?, ?)').bind(state, now).run();
    const q = new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      redirect_uri: redirect,
      response_type: 'code',
      scope: 'openid email profile',
      state: state + '.' + lang,
      prompt: 'select_account',
    });
    return Response.redirect('https://accounts.google.com/o/oauth2/v2/auth?' + q, 302);
  }

  // 2. Google trả về đây
  if (req.method === 'GET' && p === '/auth/google/callback') {
    const [state, l2] = String(url.searchParams.get('state') || '').split('.');
    const tt = T[l2] || t;
    const L = T[l2] ? l2 : lang;
    if (url.searchParams.get('error')) return page(L, false, tt.fail, tt.cancel);
    const row = /^[a-f0-9]{32,64}$/.test(state || '')
      ? await env.DB.prepare('SELECT state, created, token FROM oauth_pending WHERE state = ?').bind(state).first()
      : null;
    if (!row || row.token || Date.now() - row.created > 15 * 60_000) return page(L, false, tt.fail, tt.bad);
    const code = url.searchParams.get('code') || '';
    const r = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: env.GOOGLE_CLIENT_ID,
        client_secret: env.GOOGLE_CLIENT_SECRET,
        redirect_uri: redirect,
        grant_type: 'authorization_code',
      }),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.id_token) return page(L, false, tt.fail, tt.bad);
    // id_token nhận thẳng từ Google qua HTTPS nên tin được nội dung (OpenID Connect, mục 3.1.3.7)
    let info;
    try {
      info = b64urlJson(j.id_token.split('.')[1]);
    } catch {
      return page(L, false, tt.fail, tt.bad);
    }
    if (info.aud !== env.GOOGLE_CLIENT_ID || !/accounts\.google\.com$/.test(info.iss || '')) return page(L, false, tt.fail, tt.bad);
    if (!info.email || info.email_verified === false || info.email_verified === 'false') return page(L, false, tt.fail, tt.unverified);
    const email = String(info.email).trim().toLowerCase();
    const sub = String(info.sub || '');
    let u = await env.DB.prepare('SELECT id FROM users WHERE google_sub = ?').bind(sub).first();
    if (!u) u = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
    let fresh = false;
    const gname = String(info.name || '').trim().slice(0, 80);
    if (u) {
      await env.DB.prepare("UPDATE users SET google_sub = ?, full_name = COALESCE(NULLIF(full_name, ''), ?) WHERE id = ?").bind(sub, gname, u.id).run();
    } else {
      const salt = h.randomHex(16);
      const hash = await h.hashPassword(h.randomHex(24), salt); // mật khẩu ngẫu nhiên, không ai biết
      const ins = await env.DB.prepare('INSERT INTO users (email, salt, hash, created, google_sub, nopw, full_name) VALUES (?, ?, ?, ?, ?, 1, ?)')
        .bind(email, salt, hash, Date.now(), sub, gname)
        .run();
      u = { id: ins.meta.last_row_id };
      fresh = true;
    }
    const ban = await env.DB.prepare('SELECT reason FROM banned WHERE user_id = ?').bind(u.id).first().catch(() => null);
    if (ban) return page(L, false, tt.fail, tt.banned + (ban.reason ? ': ' + ban.reason : ''));
    if (fresh && h.onNewUser) await h.onNewUser(u.id).catch(() => {});
    const token = await h.newSession(env, u.id);
    await env.DB.prepare('UPDATE oauth_pending SET token = ?, email = ? WHERE state = ?').bind(token, email, state).run();
    return page(L, true, tt.ok, tt.okSub);
  }

  // 3. App hỏi kết quả
  if (req.method === 'POST' && p === '/api/auth/google/poll') {
    const b = await h.readJson(req);
    const state = String(b?.state || '');
    if (!/^[a-f0-9]{32,64}$/.test(state)) return h.json({ error: 'state' }, 400);
    const row = await env.DB.prepare('SELECT created, token, email FROM oauth_pending WHERE state = ?').bind(state).first();
    if (!row || Date.now() - row.created > 15 * 60_000) return h.json({ expired: true });
    if (!row.token) return h.json({ pending: true });
    await env.DB.prepare('DELETE FROM oauth_pending WHERE state = ?').bind(state).run();
    return h.json({ token: row.token, email: row.email });
  }

  if (req.method === 'GET' && p === '/api/auth/google/enabled') {
    return h.json({ google: !!(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET), mail: mailReady(env) });
  }

  // ---- Quên mật khẩu ----
  if (req.method === 'POST' && p === '/api/password/forgot') {
    const b = await h.readJson(req);
    const email = String(b?.email || '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return h.json({ error: lang === 'en' ? 'Invalid email' : 'Email chưa đúng' }, 400);
    if (!mailReady(env)) {
      return h.json({
        error: lang === 'en'
          ? "The server can't send email yet. If this is a Google email, use \"Continue with Google\" to get back in."
          : 'Server chưa bật gửi email. Nếu đây là email Google, hãy bấm "Tiếp tục với Google" để vào lại tài khoản.',
        nomail: true,
      }, 503);
    }
    const u = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
    const now = Date.now();
    const day = new Date(now + 7 * 3600_000).toISOString().slice(0, 10);
    const old = await env.DB.prepare('SELECT sent_at, sent_day, sent_n FROM pw_reset WHERE email = ?').bind(email).first();
    if (old && now - (old.sent_at || 0) < 60_000) {
      return h.json({ error: lang === 'en' ? 'Please wait a minute before requesting another code' : 'Đợi 1 phút rồi hãy xin mã mới' }, 429);
    }
    const n = old && old.sent_day === day ? old.sent_n || 0 : 0;
    if (n >= 5) return h.json({ error: lang === 'en' ? 'Too many codes today, try again tomorrow' : 'Hôm nay đã gửi quá nhiều mã, mai thử lại nhé' }, 429);
    // Không tiết lộ email có tài khoản hay không: luôn trả ok, chỉ gửi khi có tài khoản
    if (u) {
      const code = String(100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000));
      const salt = h.randomHex(8);
      await env.DB.prepare(
        `INSERT INTO pw_reset (email, code_hash, salt, exp, tries, sent_at, sent_day, sent_n) VALUES (?, ?, ?, ?, 0, ?, ?, ?)
         ON CONFLICT (email) DO UPDATE SET code_hash = excluded.code_hash, salt = excluded.salt, exp = excluded.exp, tries = 0,
           sent_at = excluded.sent_at, sent_day = excluded.sent_day, sent_n = excluded.sent_n`
      ).bind(email, await sha(salt + code), salt, now + 15 * 60_000, now, day, n + 1).run();
      try {
        await sendMail(env, email, ...resetMail(lang, code));
      } catch (e) {
        return h.json({ error: (lang === 'en' ? "Couldn't send the email: " : 'Không gửi được email: ') + (e?.message || e) }, 502);
      }
    }
    return h.json({ ok: true });
  }

  if (req.method === 'POST' && p === '/api/password/reset') {
    const b = await h.readJson(req);
    const email = String(b?.email || '').trim().toLowerCase();
    const code = String(b?.code || '').replace(/\D/g, '');
    const pw = String(b?.password || '');
    if (pw.length < 6) return h.json({ error: lang === 'en' ? 'Password must be at least 6 characters' : 'Mật khẩu tối thiểu 6 ký tự' }, 400);
    const r = await env.DB.prepare('SELECT code_hash, salt, exp, tries FROM pw_reset WHERE email = ?').bind(email).first();
    const bad = lang === 'en' ? 'Wrong or expired code' : 'Mã sai hoặc đã hết hạn';
    if (!r || !r.code_hash || Date.now() > r.exp || r.tries >= 5) return h.json({ error: bad }, 400);
    if (!h.safeEqual(await sha(r.salt + code), r.code_hash)) {
      await env.DB.prepare('UPDATE pw_reset SET tries = tries + 1 WHERE email = ?').bind(email).run();
      return h.json({ error: bad }, 400);
    }
    const u = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
    if (!u) return h.json({ error: bad }, 400);
    await setPw(env, h, u.id, pw);
    await env.DB.prepare('UPDATE pw_reset SET code_hash = NULL WHERE email = ?').bind(email).run();
    // đăng xuất mọi máy cũ, cấp phiên mới cho máy này
    await env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(u.id).run();
    return h.json({ token: await h.newSession(env, u.id), email });
  }

  if (req.method === 'POST' && p === '/api/password/set') {
    const me = await h.auth(req, env);
    if (me == null) return h.json({ error: lang === 'en' ? 'Not signed in' : 'Chưa đăng nhập' }, 401);
    const b = await h.readJson(req);
    const pw = String(b?.password || '');
    if (pw.length < 6) return h.json({ error: lang === 'en' ? 'Password must be at least 6 characters' : 'Mật khẩu tối thiểu 6 ký tự' }, 400);
    const u = await env.DB.prepare('SELECT id, salt, hash, nopw FROM users WHERE id = ?').bind(me).first();
    if (!u) return h.json({ error: 'user' }, 404);
    if (!u.nopw) {
      const old = String(b?.old || '');
      if (!old || !h.safeEqual(await h.hashPassword(old, u.salt), u.hash)) {
        return h.json({ error: lang === 'en' ? 'Current password is wrong' : 'Mật khẩu hiện tại chưa đúng' }, 401);
      }
    }
    await setPw(env, h, u.id, pw);
    return h.json({ ok: true });
  }

  // ---- Thông tin cá nhân: họ và tên, năm sinh ----
  if (p === '/api/profile' && (req.method === 'GET' || req.method === 'POST')) {
    const me = await h.auth(req, env);
    if (me == null) return h.json({ error: lang === 'en' ? 'Not signed in' : 'Chưa đăng nhập' }, 401);
    if (req.method === 'POST') {
      const b = await h.readJson(req);
      const v = checkProfile(b, lang);
      if (v.error) return h.json({ error: v.error }, 400);
      await env.DB.prepare('UPDATE users SET full_name = ?, birth_year = ? WHERE id = ?').bind(v.name, v.year, me).run();
    }
    const u = await env.DB.prepare('SELECT email, full_name, birth_year, nopw, google_sub FROM users WHERE id = ?').bind(me).first();
    return h.json({ email: u?.email, name: u?.full_name || '', birthYear: u?.birth_year || null, hasPassword: !u?.nopw, google: !!u?.google_sub });
  }

  if (req.method === 'GET' && p === '/api/password/status') {
    const me = await h.auth(req, env);
    if (me == null) return h.json({ error: 'auth' }, 401);
    const u = await env.DB.prepare('SELECT nopw, google_sub FROM users WHERE id = ?').bind(me).first();
    return h.json({ hasPassword: !u?.nopw, google: !!u?.google_sub });
  }
  return null;
}

/** Họ tên 2–80 ký tự, năm sinh 1900..(năm nay - 18), cả hai có thể để trống. */
export function checkProfile(b, lang = 'vi') {
  const en = lang === 'en';
  const name = String(b?.name ?? '').replace(/\s+/g, ' ').trim().slice(0, 80);
  const raw = b?.birthYear;
  const year = raw === null || raw === undefined || raw === '' ? null : Number(raw);
  const max = new Date().getFullYear() - 18; // VieTing chỉ dành cho người từ 18 tuổi
  if (name && name.length < 2) return { error: en ? 'Full name is too short' : 'Họ và tên quá ngắn' };
  if (year !== null && (!Number.isInteger(year) || year < 1900)) {
    return { error: en ? 'Invalid birth year' : 'Năm sinh chưa đúng' };
  }
  if (year !== null && year > max) {
    return { error: en ? 'VieTing is only for people aged 18 and over' : 'VieTing chỉ dành cho người từ 18 tuổi trở lên' };
  }
  return { name, year };
}

async function setPw(env, h, id, pw) {
  const salt = h.randomHex(16);
  await env.DB.prepare('UPDATE users SET salt = ?, hash = ?, nopw = 0 WHERE id = ?').bind(salt, await h.hashPassword(pw, salt), id).run();
}

function resetMail(lang, code) {
  const en = lang === 'en';
  const subject = en ? `VieTing: your password reset code ${code}` : `VieTing: mã đặt lại mật khẩu ${code}`;
  const line1 = en ? 'Your code to reset the VieTing password:' : 'Mã đặt lại mật khẩu VieTing của bạn:';
  const line2 = en
    ? 'The code expires in 15 minutes. If you did not ask for it, ignore this email: your password stays the same.'
    : 'Mã có hiệu lực 15 phút. Nếu bạn không yêu cầu, cứ bỏ qua email này: mật khẩu vẫn giữ nguyên.';
  const html = `<div style="font-family:Arial,sans-serif;max-width:460px;margin:auto;padding:24px;color:#152758">
<h2 style="margin:0 0 12px">Vie<span style="color:#C1272C">Ting</span></h2><p>${line1}</p>
<p style="font-size:32px;letter-spacing:8px;font-weight:700;margin:18px 0">${code}</p><p style="color:#5B6785;font-size:13px">${line2}</p></div>`;
  const text = `${line1} ${code}\n\n${line2}`;
  return [subject, html, text];
}

function mailReady(env) {
  return !!((env.RESEND_API_KEY && env.MAIL_FROM) || (env.SMTP_USER && env.SMTP_PASS));
}

async function sendMail(env, to, subject, html, text) {
  if (env.RESEND_API_KEY && env.MAIL_FROM) {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { authorization: 'Bearer ' + env.RESEND_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ from: env.MAIL_FROM, to: [to], subject, html, text }),
    });
    if (!r.ok) throw new Error('Resend ' + r.status + ' ' + (await r.text()).slice(0, 200));
    return;
  }
  await smtpSend(env, to, subject, html, text);
}

// Gửi qua Gmail SMTP (smtp.gmail.com:465, TLS) bằng mật khẩu ứng dụng
async function smtpSend(env, to, subject, html, text) {
  const host = env.SMTP_HOST || 'smtp.gmail.com';
  const port = Number(env.SMTP_PORT || 465);
  const user = env.SMTP_USER;
  const from = env.MAIL_FROM || `VieTing <${user}>`;
  const sock = connect({ hostname: host, port }, { secureTransport: 'on' });
  const w = sock.writable.getWriter();
  const rd = sock.readable.getReader();
  const te = new TextEncoder();
  const td = new TextDecoder();
  let buf = '';
  const read = async () => {
    // đọc tới khi có dòng trả lời cuối (mã 3 số + dấu cách)
    for (;;) {
      const lines = buf.split('\r\n');
      for (let i = 0; i < lines.length - 1; i++) {
        if (/^\d{3} /.test(lines[i])) {
          const out = lines.slice(0, i + 1).join('\n');
          buf = lines.slice(i + 1).join('\r\n');
          return out;
        }
      }
      const { value, done } = await rd.read();
      if (done) throw new Error('SMTP đóng kết nối');
      buf += td.decode(value);
    }
  };
  const cmd = async (line, ok) => {
    if (line != null) await w.write(te.encode(line + '\r\n'));
    const r = await read();
    if (!r.split('\n').pop().startsWith(String(ok))) throw new Error('SMTP: ' + r.slice(0, 160));
    return r;
  };
  const b64 = (s) => btoa(String.fromCharCode(...te.encode(s)));
  try {
    await cmd(null, 220);
    await cmd('EHLO vieting', 250);
    await cmd('AUTH LOGIN', 334);
    await cmd(b64(user), 334);
    await cmd(b64(env.SMTP_PASS), 235);
    await cmd(`MAIL FROM:<${user}>`, 250);
    await cmd(`RCPT TO:<${to}>`, 250);
    await cmd('DATA', 354);
    const bnd = 'vt' + Date.now().toString(36);
    const wrap = (s) => b64(s).replace(/.{76}/g, '$&\r\n');
    const msg = [
      `From: ${from}`,
      `To: <${to}>`,
      `Subject: =?UTF-8?B?${b64(subject)}?=`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${bnd}"`,
      '',
      `--${bnd}`,
      'Content-Type: text/plain; charset=UTF-8',
      'Content-Transfer-Encoding: base64',
      '',
      wrap(text),
      `--${bnd}`,
      'Content-Type: text/html; charset=UTF-8',
      'Content-Transfer-Encoding: base64',
      '',
      wrap(html),
      `--${bnd}--`,
      '.',
    ].join('\r\n');
    await cmd(msg, 250);
    await w.write(te.encode('QUIT\r\n')).catch(() => {});
  } finally {
    await sock.close().catch(() => {});
  }
}
