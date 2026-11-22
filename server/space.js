// Quỹ chung: kết nối nhiều tài khoản VieTing (vợ chồng, bạn bè, nhóm) vào một sổ chung trên server.
// Mỗi bản ghi là một khoản: nộp quỹ (contrib) hoặc chi từ quỹ (spend), ai ghi thì ghi tên người đó.
// Tác giả: Phạm Thành Long (thlong)

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ chữ dễ nhầm (0/O, 1/I)

function newCode() {
  const b = crypto.getRandomValues(new Uint8Array(6));
  return [...b].map((x) => CODE_CHARS[x % CODE_CHARS.length]).join('');
}

const str = (v, n) => String(v ?? '').trim().slice(0, n);

async function isMember(env, spaceId, userId) {
  return !!(await env.DB.prepare('SELECT 1 AS x FROM space_members WHERE space_id = ? AND user_id = ?').bind(spaceId, userId).first());
}

async function spaceInfo(env, spaceId) {
  const s = await env.DB.prepare('SELECT id, name, code, owner, target, created FROM spaces WHERE id = ?').bind(spaceId).first();
  if (!s) return null;
  const members =
    (
      await env.DB.prepare(
        'SELECT m.user_id AS id, m.nick, u.email FROM space_members m JOIN users u ON u.id = m.user_id WHERE m.space_id = ? ORDER BY m.joined'
      )
        .bind(spaceId)
        .all()
    ).results || [];
  // chỉ lộ phần trước @ của email cho thành viên khác
  return { ...s, members: members.map((m) => ({ id: m.id, name: m.nick || String(m.email).split('@')[0] })) };
}

/** Tất cả /api/space/* — cần đăng nhập. */
export async function handleSpace(req, env, url, userId, h) {
  if (userId == null) return h.json({ error: 'Đăng nhập để dùng Quỹ chung' }, 401);
  const path = url.pathname.slice('/api/space'.length);
  const b = req.method === 'POST' ? await h.readJson(req) : null;

  if (req.method === 'GET' && (path === '' || path === 's')) {
    const ids = (await env.DB.prepare('SELECT space_id FROM space_members WHERE user_id = ?').bind(userId).all()).results || [];
    const out = [];
    for (const r of ids.slice(0, 20)) {
      const info = await spaceInfo(env, r.space_id);
      if (info) out.push(info);
    }
    return h.json({ spaces: out, me: userId });
  }

  if (req.method === 'POST' && path === '/create') {
    const name = str(b?.name, 60) || 'Quỹ chung';
    const count = (await env.DB.prepare('SELECT COUNT(*) AS n FROM space_members WHERE user_id = ?').bind(userId).first())?.n || 0;
    if (count >= 20) return h.json({ error: 'Tối đa 20 quỹ chung mỗi tài khoản' }, 400);
    let code = newCode();
    for (let i = 0; i < 5; i++) {
      if (!(await env.DB.prepare('SELECT 1 AS x FROM spaces WHERE code = ?').bind(code).first())) break;
      code = newCode();
    }
    const now = Date.now();
    const res = await env.DB.prepare('INSERT INTO spaces (name, code, owner, target, created) VALUES (?, ?, ?, ?, ?)')
      .bind(name, code, userId, Math.max(0, Math.round(Number(b?.target) || 0)), now)
      .run();
    const id = res.meta.last_row_id;
    await env.DB.prepare('INSERT INTO space_members (space_id, user_id, nick, joined) VALUES (?, ?, ?, ?)').bind(id, userId, str(b?.nick, 30), now).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  if (req.method === 'POST' && path === '/join') {
    const code = str(b?.code, 12).toUpperCase().replace(/[^A-Z0-9]/g, '');
    const s = await env.DB.prepare('SELECT id FROM spaces WHERE code = ?').bind(code).first();
    if (!s) return h.json({ error: 'Mã mời không đúng' }, 404);
    const n = (await env.DB.prepare('SELECT COUNT(*) AS n FROM space_members WHERE space_id = ?').bind(s.id).first())?.n || 0;
    if (n >= 20) return h.json({ error: 'Quỹ này đã đủ 20 thành viên' }, 400);
    await env.DB.prepare('INSERT OR IGNORE INTO space_members (space_id, user_id, nick, joined) VALUES (?, ?, ?, ?)')
      .bind(s.id, userId, str(b?.nick, 30), Date.now())
      .run();
    return h.json({ space: await spaceInfo(env, s.id) });
  }

  const id = Number(b?.space ?? url.searchParams.get('space'));
  if (!id || !(await isMember(env, id, userId))) return h.json({ error: 'Bạn không ở trong quỹ này' }, 403);

  if (req.method === 'POST' && path === '/update') {
    if (b?.name != null) await env.DB.prepare('UPDATE spaces SET name = ? WHERE id = ?').bind(str(b.name, 60) || 'Quỹ chung', id).run();
    if (b?.target != null) await env.DB.prepare('UPDATE spaces SET target = ? WHERE id = ?').bind(Math.max(0, Math.round(Number(b.target) || 0)), id).run();
    if (b?.nick != null) await env.DB.prepare('UPDATE space_members SET nick = ? WHERE space_id = ? AND user_id = ?').bind(str(b.nick, 30), id, userId).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  if (req.method === 'POST' && path === '/leave') {
    await env.DB.prepare('DELETE FROM space_members WHERE space_id = ? AND user_id = ?').bind(id, userId).run();
    const left = (await env.DB.prepare('SELECT COUNT(*) AS n FROM space_members WHERE space_id = ?').bind(id).first())?.n || 0;
    if (!left) {
      await env.DB.batch([
        env.DB.prepare('DELETE FROM space_records WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM spaces WHERE id = ?').bind(id),
      ]);
    }
    return h.json({ ok: true });
  }

  if (req.method === 'POST' && path === '/sync') {
    const since = Number(b?.since) || 0;
    const now = Date.now();
    const changes = Array.isArray(b?.changes) ? b.changes.slice(0, 500) : [];
    const stmts = [];
    for (const c of changes) {
      if (!c || typeof c.id !== 'string' || c.id.length > 64) continue;
      const data = JSON.stringify(c.data ?? {});
      if (data.length > 20000) continue;
      // chỉ người tạo mới sửa / xóa được khoản của mình (giữ nguyên by_user cũ)
      stmts.push(
        env.DB.prepare(
          `INSERT INTO space_records (space_id, id, by_user, data, u, deleted, srv) VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT (space_id, id) DO UPDATE SET data = excluded.data, u = excluded.u, deleted = excluded.deleted, srv = excluded.srv
           WHERE excluded.u > space_records.u AND space_records.by_user = excluded.by_user`
        ).bind(id, c.id, userId, data, Number(c.u) || now, c.del ? 1 : 0, now)
      );
    }
    if (stmts.length) await env.DB.batch(stmts);
    const rows =
      (
        await env.DB.prepare('SELECT id, by_user, data, u, deleted, srv FROM space_records WHERE space_id = ? AND srv > ? ORDER BY srv LIMIT 1000')
          .bind(id, since)
          .all()
      ).results || [];
    return h.json({
      space: await spaceInfo(env, id),
      records: rows.map((r) => ({ id: r.id, by: r.by_user, data: JSON.parse(r.data), u: r.u, del: !!r.deleted })),
      cursor: rows.length ? rows[rows.length - 1].srv : since,
      more: rows.length >= 1000,
    });
  }

  return h.json({ error: 'Không tìm thấy' }, 404);
}

/** Khoản mới người khác ghi vào các quỹ chung của tôi (cho thông báo trên máy). */
export async function spaceNews(env, userId, after) {
  if (userId == null) return [];
  try {
    const rows =
      (
        await env.DB.prepare(
          `SELECT r.space_id, r.by_user, r.data, r.srv, s.name AS space, m2.nick, u.email
           FROM space_records r
           JOIN space_members m ON m.space_id = r.space_id AND m.user_id = ?
           JOIN spaces s ON s.id = r.space_id
           LEFT JOIN space_members m2 ON m2.space_id = r.space_id AND m2.user_id = r.by_user
           LEFT JOIN users u ON u.id = r.by_user
           WHERE r.by_user != ? AND r.srv > ? AND r.deleted = 0 AND r.srv > ?
           ORDER BY r.srv LIMIT 5`
        )
          .bind(userId, userId, after, Date.now() - 2 * 86400000)
          .all()
      ).results || [];
    return rows.map((r) => {
      const d = JSON.parse(r.data || '{}');
      const who = r.nick || String(r.email || '').split('@')[0] || 'Ai đó';
      const amt = Number(d.amount || 0).toLocaleString('vi-VN') + ' ₫';
      return {
        at: r.srv,
        title: r.space,
        body: d.type === 'contrib' ? `${who} vừa nộp ${amt} vào quỹ${d.note ? ' · ' + d.note : ''}` : `${who} vừa chi ${amt} từ quỹ${d.note ? ' · ' + d.note : ''}`,
      };
    });
  } catch {
    return [];
  }
}
