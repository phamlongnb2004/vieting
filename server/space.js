// Quỹ chung: kết nối nhiều tài khoản VieTing (vợ chồng, bạn bè, nhóm) vào một sổ chung trên server.
// VieTing không giữ tiền: tiền nằm trong tài khoản của thủ quỹ / tài khoản chung. Sổ trên server có thêm
// các lớp kiểm chứng: thủ quỹ xác nhận đã nhận, khoản chi lớn cần người khác duyệt, ảnh chứng từ,
// nhật ký sửa / xóa không ai xóa được, và đối chiếu số dư thật với số trên sổ.
// Tác giả: Phạm Thành Long (thlong)

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ chữ dễ nhầm (0/O, 1/I)

function newCode() {
  const b = crypto.getRandomValues(new Uint8Array(6));
  return [...b].map((x) => CODE_CHARS[x % CODE_CHARS.length]).join('');
}

const str = (v, n) => String(v ?? '').trim().slice(0, n);
const vnd = (n) => Number(n || 0).toLocaleString('vi-VN') + ' ₫';
const int = (v) => Math.max(0, Math.round(Number(v) || 0));

async function isMember(env, spaceId, userId) {
  return !!(await env.DB.prepare('SELECT 1 AS x FROM space_members WHERE space_id = ? AND user_id = ?').bind(spaceId, userId).first());
}

async function getSettings(env, spaceId) {
  const r = await env.DB.prepare('SELECT data FROM space_settings WHERE space_id = ?').bind(spaceId).first().catch(() => null);
  try {
    return r ? JSON.parse(r.data) : {};
  } catch {
    return {};
  }
}

async function putSettings(env, spaceId, data) {
  await env.DB.prepare('INSERT INTO space_settings (space_id, data) VALUES (?, ?) ON CONFLICT (space_id) DO UPDATE SET data = excluded.data')
    .bind(spaceId, JSON.stringify(data))
    .run();
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
  return {
    ...s,
    settings: await getSettings(env, spaceId),
    members: members.map((m) => ({ id: m.id, name: m.nick || String(m.email).split('@')[0] })),
  };
}

async function nameOf(env, spaceId, userId) {
  const r = await env.DB.prepare('SELECT m.nick, u.email FROM space_members m JOIN users u ON u.id = m.user_id WHERE m.space_id = ? AND m.user_id = ?')
    .bind(spaceId, userId)
    .first()
    .catch(() => null);
  return r ? r.nick || String(r.email).split('@')[0] : 'Ai đó';
}

function logStmt(env, spaceId, userId, recId, action, text, at = Date.now()) {
  return env.DB.prepare('INSERT INTO space_log (space_id, at, by_user, rec_id, action, text) VALUES (?, ?, ?, ?, ?, ?)').bind(
    spaceId,
    at,
    userId,
    recId || '',
    action,
    String(text).slice(0, 300)
  );
}

/** Người được xác nhận tiền vào quỹ: thủ quỹ, chưa chọn thủ quỹ thì là người tạo quỹ. */
function holderOf(info) {
  return Number(info.settings?.holder) || 0;
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
      .bind(name, code, userId, int(b?.target), now)
      .run();
    const id = res.meta.last_row_id;
    await env.DB.batch([
      env.DB.prepare('INSERT INTO space_members (space_id, user_id, nick, joined) VALUES (?, ?, ?, ?)').bind(id, userId, str(b?.nick, 30), now),
      logStmt(env, id, userId, '', 'create', `${str(b?.nick, 30) || 'Người tạo'} tạo quỹ "${name}"`, now),
    ]);
    return h.json({ space: await spaceInfo(env, id) });
  }

  if (req.method === 'POST' && path === '/join') {
    const code = str(b?.code, 12).toUpperCase().replace(/[^A-Z0-9]/g, '');
    const s = await env.DB.prepare('SELECT id FROM spaces WHERE code = ?').bind(code).first();
    if (!s) return h.json({ error: 'Mã mời không đúng' }, 404);
    const n = (await env.DB.prepare('SELECT COUNT(*) AS n FROM space_members WHERE space_id = ?').bind(s.id).first())?.n || 0;
    if (n >= 20) return h.json({ error: 'Quỹ này đã đủ 20 thành viên' }, 400);
    const already = await isMember(env, s.id, userId);
    await env.DB.prepare('INSERT OR IGNORE INTO space_members (space_id, user_id, nick, joined) VALUES (?, ?, ?, ?)')
      .bind(s.id, userId, str(b?.nick, 30), Date.now())
      .run();
    if (!already) await logStmt(env, s.id, userId, '', 'join', `${await nameOf(env, s.id, userId)} vừa vào quỹ`).run();
    return h.json({ space: await spaceInfo(env, s.id) });
  }

  const id = Number(b?.space ?? url.searchParams.get('space'));
  if (!id || !(await isMember(env, id, userId))) return h.json({ error: 'Bạn không ở trong quỹ này' }, 403);

  if (req.method === 'POST' && path === '/update') {
    if (b?.name != null) await env.DB.prepare('UPDATE spaces SET name = ? WHERE id = ?').bind(str(b.name, 60) || 'Quỹ chung', id).run();
    if (b?.target != null) await env.DB.prepare('UPDATE spaces SET target = ? WHERE id = ?').bind(int(b.target), id).run();
    if (b?.nick != null) await env.DB.prepare('UPDATE space_members SET nick = ? WHERE space_id = ? AND user_id = ?').bind(str(b.nick, 30), id, userId).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  // Thủ quỹ, tài khoản nhận quỹ, ngưỡng cần duyệt. Chỉ người tạo quỹ hoặc thủ quỹ hiện tại được đổi,
  // và mọi thay đổi đều ghi nhật ký + báo cả nhóm (để không ai lén đổi số tài khoản nhận tiền).
  if (req.method === 'POST' && path === '/settings') {
    const info = await spaceInfo(env, id);
    const holder = holderOf(info);
    if (userId !== info.owner && userId !== holder) return h.json({ error: 'Chỉ người tạo quỹ hoặc thủ quỹ được đổi cài đặt' }, 403);
    const st = { ...info.settings };
    const who = await nameOf(env, id, userId);
    const notes = [];
    if (b?.holder != null) {
      const nh = Number(b.holder) || 0;
      if (nh && !info.members.some((m) => m.id === nh)) return h.json({ error: 'Thủ quỹ phải là thành viên' }, 400);
      if (nh !== holder) {
        st.holder = nh;
        notes.push(nh ? `chọn ${info.members.find((m) => m.id === nh)?.name} làm thủ quỹ` : 'bỏ thủ quỹ (ai khai nấy chịu)');
      }
    }
    if (b?.bank !== undefined) {
      const bk = b.bank && typeof b.bank === 'object' ? b.bank : null;
      const nb = bk && str(bk.acct, 30)
        ? { bin: str(bk.bin, 10), name: str(bk.name, 40), acct: str(bk.acct, 30).replace(/\s+/g, ''), owner: str(bk.owner, 60).toUpperCase() }
        : null;
      if (JSON.stringify(nb) !== JSON.stringify(st.bank || null)) {
        st.bank = nb;
        notes.push(nb ? `đổi tài khoản nhận quỹ sang ${nb.name} ${nb.acct} (${nb.owner})` : 'xóa tài khoản nhận quỹ');
      }
    }
    if (b?.approveOver != null) {
      const v = int(b.approveOver);
      if (v !== (st.approveOver || 0)) {
        st.approveOver = v;
        notes.push(v ? `đặt khoản chi trên ${vnd(v)} phải có người duyệt` : 'tắt duyệt khoản chi');
      }
    }
    if (notes.length) {
      await putSettings(env, id, st);
      await logStmt(env, id, userId, '', 'settings', `${who} ${notes.join(', ')}`).run();
    }
    return h.json({ space: await spaceInfo(env, id) });
  }

  // Xác nhận đã nhận tiền (thủ quỹ) hoặc duyệt / từ chối khoản chi (thành viên khác người ghi).
  if (req.method === 'POST' && path === '/mark') {
    const rec = str(b?.rec, 64);
    const kind = str(b?.kind, 10);
    if (!['confirm', 'reject', 'approve', 'deny', 'clear'].includes(kind)) return h.json({ error: 'Sai thao tác' }, 400);
    const r = await env.DB.prepare('SELECT by_user, data, deleted FROM space_records WHERE space_id = ? AND id = ?').bind(id, rec).first();
    if (!r || r.deleted) return h.json({ error: 'Không thấy khoản này' }, 404);
    const d = JSON.parse(r.data || '{}');
    const info = await spaceInfo(env, id);
    const holder = holderOf(info) || info.owner;
    if ((kind === 'confirm' || kind === 'reject') && (d.type !== 'contrib' || userId !== holder)) {
      return h.json({ error: 'Chỉ thủ quỹ xác nhận được tiền nộp vào' }, 403);
    }
    if ((kind === 'approve' || kind === 'deny') && (d.type !== 'spend' || userId === r.by_user)) {
      return h.json({ error: 'Người khác (không phải người chi) mới duyệt được' }, 403);
    }
    const now = Date.now();
    const who = await nameOf(env, id, userId);
    const author = await nameOf(env, id, r.by_user);
    const what = `${d.type === 'contrib' ? 'khoản nộp' : 'khoản chi'} ${vnd(d.amount)} của ${author}${d.note ? ' (' + str(d.note, 60) + ')' : ''}`;
    const text = {
      confirm: `${who} xác nhận đã nhận ${what}${b?.auto ? ' (tự khớp từ thông báo ngân hàng)' : ''}`,
      reject: `${who} báo CHƯA nhận được ${what}`,
      approve: `${who} duyệt ${what}`,
      deny: `${who} từ chối ${what}`,
      clear: `${who} bỏ đánh dấu ${what}`,
    }[kind];
    await env.DB.batch([
      kind === 'clear'
        ? env.DB.prepare('DELETE FROM space_marks WHERE space_id = ? AND rec_id = ? AND user_id = ?').bind(id, rec, userId)
        : env.DB.prepare(
            'INSERT INTO space_marks (space_id, rec_id, user_id, kind, at) VALUES (?, ?, ?, ?, ?) ON CONFLICT (space_id, rec_id, user_id) DO UPDATE SET kind = excluded.kind, at = excluded.at'
          ).bind(id, rec, userId, kind, now),
      // đẩy khoản này lên lại trong lần đồng bộ tới của mọi người
      env.DB.prepare('UPDATE space_records SET srv = ? WHERE space_id = ? AND id = ?').bind(now, id, rec),
      logStmt(env, id, userId, rec, kind, text, now),
    ]);
    return h.json({ ok: true, at: now });
  }

  // Đối chiếu: số dư thật trong tài khoản / két so với số trên sổ.
  if (req.method === 'POST' && path === '/recon') {
    const info = await spaceInfo(env, id);
    const actual = Math.round(Number(b?.actual) || 0);
    const book = Math.round(Number(b?.book) || 0);
    const st = { ...info.settings, recon: { actual, book, at: Date.now(), by: userId } };
    await putSettings(env, id, st);
    const who = await nameOf(env, id, userId);
    const diff = actual - book;
    const text =
      diff === 0
        ? `${who} đối chiếu: số dư thật ${vnd(actual)}, khớp với sổ`
        : `${who} đối chiếu: số dư thật ${vnd(actual)}, sổ ghi ${vnd(book)}, ${diff > 0 ? 'dư' : 'THIẾU'} ${vnd(Math.abs(diff))}`;
    await logStmt(env, id, userId, '', 'recon', text).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  // Ảnh chứng từ: người ghi khoản tải lên, cả nhóm xem được.
  if (path === '/proof') {
    const rec = str(b?.rec ?? url.searchParams.get('rec'), 64);
    if (req.method === 'GET') {
      const p = await env.DB.prepare('SELECT img FROM space_proofs WHERE space_id = ? AND rec_id = ?').bind(id, rec).first();
      return p ? h.json({ img: p.img }) : h.json({ error: 'Chưa có ảnh' }, 404);
    }
    const r = await env.DB.prepare('SELECT by_user FROM space_records WHERE space_id = ? AND id = ?').bind(id, rec).first();
    if (!r || r.by_user !== userId) return h.json({ error: 'Chỉ người ghi khoản mới thêm ảnh' }, 403);
    const img = String(b?.img || '');
    if (!img || img.length > 600000) return h.json({ error: 'Ảnh quá lớn' }, 400);
    await env.DB.prepare(
      'INSERT INTO space_proofs (space_id, rec_id, img, at) VALUES (?, ?, ?, ?) ON CONFLICT (space_id, rec_id) DO UPDATE SET img = excluded.img, at = excluded.at'
    )
      .bind(id, rec, img, Date.now())
      .run();
    return h.json({ ok: true });
  }

  if (req.method === 'GET' && path === '/log') {
    const rows =
      (
        await env.DB.prepare('SELECT at, by_user, rec_id, action, text FROM space_log WHERE space_id = ? ORDER BY at DESC LIMIT 300')
          .bind(id)
          .all()
      ).results || [];
    return h.json({ log: rows.map((r) => ({ at: r.at, by: r.by_user, rec: r.rec_id, action: r.action, text: r.text })) });
  }

  if (req.method === 'POST' && path === '/leave') {
    const who = await nameOf(env, id, userId);
    await env.DB.prepare('DELETE FROM space_members WHERE space_id = ? AND user_id = ?').bind(id, userId).run();
    const left = (await env.DB.prepare('SELECT COUNT(*) AS n FROM space_members WHERE space_id = ?').bind(id).first())?.n || 0;
    if (!left) {
      await env.DB.batch([
        env.DB.prepare('DELETE FROM space_records WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM space_marks WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM space_log WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM space_proofs WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM space_settings WHERE space_id = ?').bind(id),
        env.DB.prepare('DELETE FROM spaces WHERE id = ?').bind(id),
      ]);
    } else {
      await logStmt(env, id, userId, '', 'leave', `${who} đã rời quỹ`).run();
    }
    return h.json({ ok: true });
  }

  if (req.method === 'POST' && path === '/sync') {
    const since = Number(b?.since) || 0;
    const now = Date.now();
    const changes = Array.isArray(b?.changes) ? b.changes.slice(0, 500) : [];
    const stmts = [];
    let who = null;
    for (const c of changes) {
      if (!c || typeof c.id !== 'string' || c.id.length > 64) continue;
      const d = c.data && typeof c.data === 'object' ? c.data : {};
      const data = JSON.stringify(d);
      if (data.length > 20000) continue;
      const old = await env.DB.prepare('SELECT by_user, data, u, deleted FROM space_records WHERE space_id = ? AND id = ?').bind(id, c.id).first();
      if (old && (old.by_user !== userId || !(Number(c.u) > old.u))) continue; // chỉ người tạo mới sửa / xóa được khoản của mình
      who ??= await nameOf(env, id, userId);
      const label = d.type === 'contrib' ? 'nộp' : 'chi';
      const amt = int(d.amount);
      stmts.push(
        env.DB.prepare(
          `INSERT INTO space_records (space_id, id, by_user, data, u, deleted, srv) VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT (space_id, id) DO UPDATE SET data = excluded.data, u = excluded.u, deleted = excluded.deleted, srv = excluded.srv
           WHERE excluded.u > space_records.u AND space_records.by_user = excluded.by_user`
        ).bind(id, c.id, userId, data, Number(c.u) || now, c.del ? 1 : 0, now)
      );
      const note = d.note ? ' · ' + str(d.note, 60) : '';
      if (!old) {
        if (!c.del) {
          const extra = d.type === 'spend' && d.ask ? ' (cần duyệt)' : d.type === 'contrib' && d.pending ? ' (chờ thủ quỹ xác nhận)' : '';
          stmts.push(logStmt(env, id, userId, c.id, d.type === 'contrib' ? 'contrib' : 'spend', `${who} ${label} ${vnd(amt)}${note}${extra}`, now));
        }
      } else {
        const od = JSON.parse(old.data || '{}');
        if (c.del && !old.deleted) {
          stmts.push(logStmt(env, id, userId, c.id, 'delete', `${who} XÓA khoản ${label} ${vnd(od.amount)}${od.note ? ' · ' + str(od.note, 60) : ''}`, now));
        } else if (!c.del && int(od.amount) !== amt) {
          stmts.push(logStmt(env, id, userId, c.id, 'edit', `${who} SỬA khoản ${label} ${vnd(od.amount)} → ${vnd(amt)}${note}`, now));
          // đổi số tiền thì các xác nhận / duyệt cũ hết hiệu lực
          stmts.push(env.DB.prepare('DELETE FROM space_marks WHERE space_id = ? AND rec_id = ?').bind(id, c.id));
        } else if (!c.del && d.proofAi != null && od.proofAi == null) {
          const ai = int(d.proofAi);
          const off = Math.abs(ai - amt) > Math.max(1000, amt * 0.02);
          stmts.push(
            logStmt(
              env,
              id,
              userId,
              c.id,
              off ? 'flag' : 'proof',
              off
                ? `Ảnh chứng từ khoản ${label} ${vnd(amt)} của ${who}: AI đọc được ${vnd(ai)}, LỆCH ${vnd(Math.abs(ai - amt))}`
                : `${who} thêm ảnh chứng từ cho khoản ${label} ${vnd(amt)} (AI đọc khớp)`,
              now
            )
          );
        }
      }
    }
    if (stmts.length) await env.DB.batch(stmts);
    const rows =
      (
        await env.DB.prepare('SELECT id, by_user, data, u, deleted, srv FROM space_records WHERE space_id = ? AND srv > ? ORDER BY srv LIMIT 1000')
          .bind(id, since)
          .all()
      ).results || [];
    // các khoản trả về: gửi kèm toàn bộ dấu xác nhận hiện tại (kể cả dấu đã bị gỡ)
    const ids = new Set(rows.map((r) => r.id));
    const all = new Map();
    if (ids.size) {
      const cur =
        (
          await env.DB.prepare('SELECT rec_id, user_id, kind FROM space_marks WHERE space_id = ?')
            .bind(id)
            .all()
            .catch(() => ({ results: [] }))
        ).results || [];
      for (const m of cur) {
        if (!ids.has(m.rec_id)) continue;
        if (!all.has(m.rec_id)) all.set(m.rec_id, {});
        all.get(m.rec_id)[m.user_id] = m.kind;
      }
    }
    return h.json({
      space: await spaceInfo(env, id),
      records: rows.map((r) => ({ id: r.id, by: r.by_user, data: JSON.parse(r.data), u: r.u, del: !!r.deleted, marks: all.get(r.id) || {} })),
      cursor: rows.length ? rows[rows.length - 1].srv : since,
      more: rows.length >= 1000,
    });
  }

  return h.json({ error: 'Không tìm thấy' }, 404);
}

/** Việc người khác vừa làm trong các quỹ chung của tôi (cho thông báo trên máy, kể cả khi app đóng). */
export async function spaceNews(env, userId, after) {
  if (userId == null) return [];
  try {
    const rows =
      (
        await env.DB.prepare(
          `SELECT l.at, l.text, l.action, s.name AS space
           FROM space_log l
           JOIN space_members m ON m.space_id = l.space_id AND m.user_id = ?
           JOIN spaces s ON s.id = l.space_id
           WHERE l.by_user != ? AND l.at > ? AND l.at > ?
           ORDER BY l.at LIMIT 8`
        )
          .bind(userId, userId, after, Date.now() - 2 * 86400000)
          .all()
      ).results || [];
    const warn = new Set(['delete', 'edit', 'flag', 'reject', 'deny', 'settings']);
    return rows.map((r) => ({ at: r.at, title: (warn.has(r.action) ? 'Chú ý · ' : '') + r.space, body: r.text }));
  } catch {
    return [];
  }
}
