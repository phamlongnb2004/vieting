// Server VieTing trên Cloudflare Workers + D1 (gói miễn phí): trang tải app + đồng bộ dữ liệu.
// Tác giả: Phạm Thành Long (thlong)
//
// GET  /tai-app, /tai/<android|windows|windows-portable|ios>  trang tải + link tải (download.js)
// POST /api/register  {email, password}        -> {token}
// POST /api/login     {email, password}        -> {token}
// POST /api/chat      {messages, context, today}  -> {reply, actions}  trợ lý AI (ai.js), đăng nhập không bắt buộc
// GET  /admin                                 trang quản trị (admin.js); /api/admin/* cần quyền admin
// GET  /api/notice                             thông báo admin gửi tới app
// GET  /api/config  POST /api/redeem /api/ticket /api/ocr-report  GET /api/tickets   (config.js)
// POST /api/sync      {since, changes: [...]}  -> {now, changes: [...]}   (header Authorization: Bearer <token>)
//
// Mỗi bản ghi: {kind: txn|wallet|budget|rule, id, data, u (thời điểm sửa), del}.
// Bản nào sửa sau thì thắng (last-write-wins).

import { handleDownload } from './download.js';
import { handleChat, handleReceipt, handleParse } from './ai.js';
import { handleAdmin, adminPage, publicNotice } from './admin.js';
import { handleSpace } from './space.js';
import { publicConfig, redeem, createTicket, myTickets, ocrReport, pushFeed, grantPro } from './config.js';

const KINDS = new Set(['txn', 'wallet', 'budget', 'rule', 'goal', 'challenge', 'group', 'bill', 'wish', 'gift']);
const MAX_CHANGES = 1000;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'content-type, authorization',
    },
  });
}

const enc = new TextEncoder();

function toHex(buf) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function randomHex(bytes) {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return toHex(a);
}

async function hashPassword(password, saltHex) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const salt = new Uint8Array(saltHex.match(/../g).map((h) => parseInt(h, 16)));
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 100000 }, key, 256);
  return toHex(bits);
}

function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function readJson(req) {
  try {
    return await req.json();
  } catch {
    return null;
  }
}

async function newSession(env, userId) {
  const token = randomHex(32);
  await env.DB.prepare('INSERT INTO sessions (token, user_id, created) VALUES (?, ?, ?)')
    .bind(token, userId, Date.now())
    .run();
  return token;
}

async function register(req, env) {
  const b = await readJson(req);
  const email = String(b?.email || '').trim().toLowerCase();
  const password = String(b?.password || '');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: 'Email chưa đúng' }, 400);
  if (password.length < 6) return json({ error: 'Mật khẩu tối thiểu 6 ký tự' }, 400);
  const exists = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (exists) return json({ error: 'Email này đã có tài khoản' }, 409);
  const salt = randomHex(16);
  const hash = await hashPassword(password, salt);
  const res = await env.DB.prepare('INSERT INTO users (email, salt, hash, created) VALUES (?, ?, ?, ?)')
    .bind(email, salt, hash, Date.now())
    .run();
  const token = await newSession(env, res.meta.last_row_id);
  // tài khoản mới được dùng thử Pro 7 ngày
  await grantPro(env, res.meta.last_row_id, 7, 'Dùng thử').catch(() => {});
  return json({ token });
}

async function login(req, env) {
  const b = await readJson(req);
  const email = String(b?.email || '').trim().toLowerCase();
  const password = String(b?.password || '');
  const u = await env.DB.prepare('SELECT id, salt, hash FROM users WHERE email = ?').bind(email).first();
  if (!u) return json({ error: 'Sai email hoặc mật khẩu' }, 401);
  const hash = await hashPassword(password, u.salt);
  if (!safeEqual(hash, u.hash)) return json({ error: 'Sai email hoặc mật khẩu' }, 401);
  const ban = await env.DB.prepare('SELECT reason FROM banned WHERE user_id = ?').bind(u.id).first().catch(() => null);
  if (ban) return json({ error: 'Tài khoản đã bị khóa' + (ban.reason ? ': ' + ban.reason : '') }, 403);
  return json({ token: await newSession(env, u.id) });
}

async function auth(req, env) {
  const h = req.headers.get('authorization') || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!token) return null;
  const s = await env.DB.prepare(
    'SELECT user_id FROM sessions s WHERE token = ? AND NOT EXISTS (SELECT 1 FROM banned b WHERE b.user_id = s.user_id)'
  )
    .bind(token)
    .first();
  return s ? s.user_id : null;
}

async function sync(req, env) {
  const userId = await auth(req, env);
  if (userId == null) return json({ error: 'Chưa đăng nhập' }, 401);
  const b = await readJson(req);
  if (!b) return json({ error: 'Dữ liệu không hợp lệ' }, 400);
  const since = Number(b.since) || 0;
  const changes = Array.isArray(b.changes) ? b.changes.slice(0, MAX_CHANGES) : [];
  const now = Date.now();

  const stmts = [];
  for (const c of changes) {
    if (!c || !KINDS.has(c.kind) || typeof c.id !== 'string' || c.id.length > 200) continue;
    const data = JSON.stringify(c.data ?? {});
    if (data.length > 200000) continue;
    stmts.push(
      env.DB.prepare(
        `INSERT INTO records (user_id, kind, id, data, updated_at, deleted, srv)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (user_id, kind, id) DO UPDATE SET
           data = excluded.data, updated_at = excluded.updated_at, deleted = excluded.deleted, srv = excluded.srv
         WHERE excluded.updated_at > records.updated_at`
      ).bind(userId, c.kind, c.id, data, Number(c.u) || 0, c.del ? 1 : 0, now)
    );
  }
  for (let i = 0; i < stmts.length; i += 100) {
    await env.DB.batch(stmts.slice(i, i + 100));
  }

  const LIMIT = 5000;
  const rows = await env.DB.prepare(
    'SELECT kind, id, data, updated_at, deleted, srv FROM records WHERE user_id = ? AND srv > ? AND srv < ? ORDER BY srv LIMIT ?'
  )
    .bind(userId, since, now, LIMIT)
    .all();
  const list = rows.results || [];
  const more = list.length >= LIMIT;
  const cursor = more ? list[list.length - 1].srv - 1 : now - 1;
  const out = list.map((r) => ({
    kind: r.kind,
    id: r.id,
    data: JSON.parse(r.data),
    u: r.updated_at,
    del: !!r.deleted,
  }));
  return json({ now: cursor, more, changes: out });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return json({});
    try {
      if (req.method === 'POST' && url.pathname === '/api/register') return await register(req, env);
      if (req.method === 'POST' && url.pathname === '/api/login') return await login(req, env);
      if (req.method === 'POST' && url.pathname === '/api/sync') return await sync(req, env);
      if (req.method === 'POST' && url.pathname === '/api/chat') return await handleChat(req, env, await auth(req, env));
      if (req.method === 'POST' && url.pathname === '/api/receipt') return await handleReceipt(req, env, await auth(req, env));
      if (url.pathname.startsWith('/api/admin/')) {
        return await handleAdmin(req, env, url, await auth(req, env), { json, readJson, randomHex, hashPassword });
      }
      if (req.method === 'GET' && url.pathname === '/api/notice') return await publicNotice(env, { json });
      const h = { json, readJson };
      if (req.method === 'GET' && url.pathname === '/api/config') return await publicConfig(req, env, await auth(req, env), h);
      if (req.method === 'POST' && url.pathname === '/api/redeem') return await redeem(req, env, await auth(req, env), h);
      if (req.method === 'POST' && url.pathname === '/api/ticket') return await createTicket(req, env, await auth(req, env), h);
      if (req.method === 'GET' && url.pathname === '/api/tickets') return await myTickets(req, env, await auth(req, env), h);
      if (req.method === 'POST' && url.pathname === '/api/parse') return await handleParse(req, env, await auth(req, env));
      if (url.pathname === '/api/spaces' || url.pathname.startsWith('/api/space/')) {
        return await handleSpace(req, env, url, await auth(req, env), { json, readJson });
      }
      if (req.method === 'GET' && url.pathname === '/api/push') return await pushFeed(req, env, await auth(req, env), h);
      if (req.method === 'POST' && url.pathname === '/api/ocr-report') return await ocrReport(req, env, await auth(req, env), h);
      if (url.pathname === '/admin' || url.pathname === '/admin/') return adminPage();
      if (url.pathname === '/api') return json({ app: 'VieTing', ok: true, v: 'ai8' });
      const p = url.pathname.replace(/\/+$/, '') || '/';
      if (env.ASSETS) {
        const r = await handleDownload(req, env, p);
        if (r) return r;
        return env.ASSETS.fetch(req);
      }
      return json({ error: 'Không tìm thấy' }, 404);
    } catch (e) {
      return json({ error: 'Lỗi server: ' + (e && e.message ? e.message : e) }, 500);
    }
  },
};
