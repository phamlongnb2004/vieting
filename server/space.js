// Quỹ chung: kết nối nhiều tài khoản VieTing (vợ chồng, bạn bè, nhóm) vào một sổ chung trên server.
// VieTing không giữ tiền: tiền nằm trong tài khoản của thủ quỹ / tài khoản chung. Sổ trên server có thêm
// các lớp kiểm chứng: thủ quỹ xác nhận đã nhận, khoản chi lớn cần người khác duyệt, ảnh chứng từ,
// nhật ký sửa / xóa không ai xóa được, và đối chiếu số dư thật với số trên sổ.
// Tác giả: Phạm Thành Long (thlong)

import { visionJson, aiAllowed } from './ai.js';
import { sepayList, syncBank, syncAllBanks } from './bank.js';

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
    linked: await isLinked(env, spaceId),
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

const bankH = () => ({ getSettings, putSettings, logStmt });

async function isLinked(env, spaceId) {
  return !!(await env.DB.prepare('SELECT 1 AS x FROM space_bank WHERE space_id = ?').bind(spaceId).first().catch(() => null));
}

/** Thử thách số dư quá 10 phút chưa xong: ghi nhật ký một lần. */
async function expireChallenge(env, spaceId) {
  const st = await getSettings(env, spaceId);
  const c = st.challenge;
  if (!c || c.passed || c.failed || Date.now() < c.exp) return;
  st.challenge = { ...c, failed: true };
  await putSettings(env, spaceId, st);
  const who = st.holder ? await nameOf(env, spaceId, st.holder) : 'Thủ quỹ';
  await logStmt(env, spaceId, 0, '', 'challengefail', `${who} KHÔNG chứng minh được số dư trong 10 phút (mã ${c.code})`).run();
}

/** Cron mỗi 10 phút: đọc ngân hàng các quỹ đã nối + hết hạn thử thách. */
export async function spaceCron(env) {
  await syncAllBanks(env, bankH());
  const rows = (await env.DB.prepare("SELECT space_id FROM space_settings WHERE data LIKE '%\"challenge\"%'").all().catch(() => ({ results: [] }))).results || [];
  for (const r of rows) await expireChallenge(env, r.space_id).catch(() => {});
}

/** Người được xác nhận tiền vào quỹ: thủ quỹ, chưa chọn thủ quỹ thì là người tạo quỹ. */
function holderOf(info) {
  return Number(info.settings?.holder) || 0;
}


const fold = (t) =>
  String(t || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toUpperCase();

async function sha(t) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
}

/** Giờ Việt Nam từ chuỗi "YYYY-MM-DD HH:mm" AI đọc trên ảnh. */
function vnTime(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):(\d{2}))?/.exec(String(s || '').trim());
  if (!m) return null;
  return Date.UTC(+m[1], +m[2] - 1, +m[3], m[4] ? +m[4] : 12, m[5] ? +m[5] : 0) - 7 * 3600000;
}

const VERIFY_PROMPT = `Bạn là người kiểm tra chứng từ cho một quỹ chung. Nhìn ảnh và trả về MỘT đối tượng JSON, chỉ ghi điều THẤY TRONG ẢNH, không đoán:
{"kind":"transfer|receipt|cash|other","success":true,"direction":"out|in|unknown","amount":0,"to_account":"","to_name":"","memo":"","datetime":"YYYY-MM-DD HH:mm","merchant":"","app":"","suspicious":""}
- kind: transfer = ảnh màn hình chuyển khoản / thanh toán thành công trong app ngân hàng hoặc ví; receipt = hóa đơn, bill, biên lai cửa hàng; cash = ảnh tiền mặt; other = ảnh khác (ảnh tự chế, ảnh chụp chữ, ảnh không liên quan...).
- success: chỉ true khi ảnh ghi rõ giao dịch THÀNH CÔNG / đã thanh toán. Lệnh đang chờ, thất bại, màn hình nhập số tiền chưa bấm chuyển thì false.
- direction: out nếu là tiền chuyển đi / trả tiền, in nếu là tiền nhận vào.
- amount: số tiền giao dịch (đồng, số nguyên), KHÔNG lấy số dư, phí.
- to_account, to_name: số tài khoản và tên NGƯỜI NHẬN đúng như trên ảnh (giữ dấu * nếu bị che).
- memo: nội dung / lời nhắn chuyển khoản đúng như trên ảnh.
- datetime: thời gian giao dịch trên ảnh, không có thì "".
- suspicious: nếu ảnh có dấu hiệu bị sửa (chữ lệch font, số chồng lên nhau, cắt ghép) thì mô tả ngắn, không thì "".`;

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
    // Mã mời ngẫu nhiên 6 ký tự (32^6 ≈ 1 tỷ mã). Cột code là UNIQUE: nếu trùng quỹ đã có thì sinh mã khác,
    // kể cả khi hai người tạo quỹ cùng lúc ra cùng một mã.
    const now = Date.now();
    let res = null;
    let code = '';
    for (let i = 0; i < 20 && !res; i++) {
      code = newCode();
      if (await env.DB.prepare('SELECT 1 AS x FROM spaces WHERE code = ?').bind(code).first()) continue;
      try {
        res = await env.DB.prepare('INSERT INTO spaces (name, code, owner, target, created) VALUES (?, ?, ?, ?, ?)')
          .bind(name, code, userId, int(b?.target), now)
          .run();
      } catch (e) {
        if (!/UNIQUE/i.test(String(e?.message || e))) throw e;
      }
    }
    if (!res) return h.json({ error: 'Chưa tạo được mã mời, thử lại nhé' }, 503);
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
        st.holderSince = Date.now();
        // bàn giao: người mới phải xác nhận đã nhận đủ số tiền quỹ
        if (holder && nh) st.handover = { from: holder, to: nh, amount: Math.round(Number(b?.book) || 0), at: Date.now() };
        else delete st.handover;
        if (await isLinked(env, id)) {
          await env.DB.prepare('DELETE FROM space_bank WHERE space_id = ?').bind(id).run();
          delete st.bankLink;
          notes.push('ngắt kết nối ngân hàng của thủ quỹ cũ');
        }
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
        if (await isLinked(env, id)) {
          await env.DB.prepare('DELETE FROM space_bank WHERE space_id = ?').bind(id).run();
          delete st.bankLink;
          notes.push('ngắt kết nối ngân hàng (vì đổi tài khoản)');
        }
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
    if (b?.maxHold != null) {
      const v = int(b.maxHold);
      if (v !== (st.maxHold || 0)) {
        st.maxHold = v;
        notes.push(v ? `đặt trần ${vnd(v)} cho một người giữ` : 'bỏ trần tiền giữ');
      }
    }
    if (b?.rotateDays != null) {
      const v = Math.min(365, int(b.rotateDays));
      if (v !== (st.rotateDays || 0)) {
        st.rotateDays = v;
        notes.push(v ? `nhắc đổi thủ quỹ mỗi ${v} ngày` : 'tắt nhắc đổi thủ quỹ');
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
    if (!['confirm', 'reject', 'approve', 'deny', 'clear', 'sent'].includes(kind)) return h.json({ error: 'Sai thao tác' }, 400);
    const r = await env.DB.prepare('SELECT by_user, data, deleted FROM space_records WHERE space_id = ? AND id = ?').bind(id, rec).first();
    if (!r || r.deleted) return h.json({ error: 'Không thấy khoản này' }, 404);
    const d = JSON.parse(r.data || '{}');
    const info = await spaceInfo(env, id);
    const holder = holderOf(info) || info.owner;
    if ((kind === 'confirm' || kind === 'reject') && (d.type !== 'contrib' || userId !== holder)) {
      return h.json({ error: 'Chỉ thủ quỹ xác nhận được tiền nộp vào' }, 403);
    }
    if (kind === 'confirm' && (await isLinked(env, id))) {
      return h.json({ error: 'Quỹ đã nối ngân hàng: tiền về tài khoản quỹ sẽ được ngân hàng tự xác nhận' }, 403);
    }
    if (kind === 'sent' && userId !== r.by_user) return h.json({ error: 'Chỉ người nộp mới gửi được' }, 403);
    if ((kind === 'approve' || kind === 'deny') && userId === r.by_user) {
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
      sent: `Máy của ${who} báo ngân hàng đã trừ ${vnd(d.amount)} cho khoản nộp này (thông báo ngân hàng trên máy người nộp)`,
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

  // ---------- Nối ngân hàng (SePay API v2) ----------
  if (req.method === 'POST' && path === '/bank-link') {
    const info = await spaceInfo(env, id);
    if (userId !== holderOf(info)) return h.json({ error: 'Chỉ thủ quỹ nối được tài khoản của mình' }, 403);
    const acct = info.settings?.bank?.acct;
    if (!acct) return h.json({ error: 'Nhập tài khoản nhận quỹ trước' }, 400);
    const token = str(b?.token, 200).replace(/\s+/g, '');
    if (token.length < 20) return h.json({ error: 'Khóa API không hợp lệ' }, 400);
    let list;
    try {
      list = await sepayList(token, { fromMs: Date.now() - 60 * 86400000, maxPages: 2 });
    } catch (e) {
      return h.json({ error: e.message }, 400);
    }
    const accts = [...new Set(list.map((t) => t.acct).filter(Boolean))];
    if (accts.length && !accts.includes(acct)) {
      return h.json({ error: `Khóa này không đọc được tài khoản ${acct} (chỉ thấy ${accts.slice(0, 3).join(', ')}). Hãy liên kết đúng tài khoản quỹ trên SePay.` }, 400);
    }
    const now = Date.now();
    await env.DB.prepare(
      'INSERT INTO space_bank (space_id, provider, token, linked_by, at) VALUES (?, ?, ?, ?, ?) ON CONFLICT (space_id) DO UPDATE SET provider = excluded.provider, token = excluded.token, linked_by = excluded.linked_by, at = excluded.at'
    )
      .bind(id, 'sepay', token, userId, now)
      .run();
    const st = await getSettings(env, id);
    // lấy cả giao dịch 2 ngày trước khi nối, để khớp các khoản vừa nộp
    st.bankLink = { provider: 'sepay', since: now - 2 * 86400000, linkedAt: now, lastId: '', lastSync: 0 };
    await putSettings(env, id, st);
    await logStmt(env, id, userId, '', 'banklink', `${await nameOf(env, id, userId)} nối tài khoản quỹ ${info.settings.bank.name} ${acct} với ngân hàng (SePay). Từ giờ tiền vào / ra được ngân hàng xác thực`).run();
    await syncBank(env, id, bankH(), { force: true });
    return h.json({ space: await spaceInfo(env, id), note: accts.length ? '' : 'Chưa thấy giao dịch nào của tài khoản trong 60 ngày qua, hãy kiểm tra lại sau khi có giao dịch đầu tiên.' });
  }

  if (req.method === 'POST' && path === '/bank-unlink') {
    const info = await spaceInfo(env, id);
    if (userId !== holderOf(info) && userId !== info.owner) return h.json({ error: 'Chỉ thủ quỹ hoặc người tạo quỹ' }, 403);
    await env.DB.prepare('DELETE FROM space_bank WHERE space_id = ?').bind(id).run();
    const st = await getSettings(env, id);
    delete st.bankLink;
    await putSettings(env, id, st);
    await logStmt(env, id, userId, '', 'bankoff', `${await nameOf(env, id, userId)} NGẮT kết nối ngân hàng của quỹ`).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  if (req.method === 'GET' && path === '/bank-txns') {
    await syncBank(env, id, bankH());
    const rows =
      (await env.DB.prepare('SELECT bid, dir, amount, content, balance, at, rec_id FROM space_bank_txns WHERE space_id = ? ORDER BY at DESC LIMIT 100').bind(id).all()).results || [];
    return h.json({ txns: rows.map((r) => ({ dir: r.dir, amount: r.amount, content: r.content, balance: r.balance, at: r.at, rec: r.rec_id })), space: await spaceInfo(env, id) });
  }

  // ---------- Thử thách số dư: thành viên yêu cầu, thủ quỹ có 10 phút để chứng minh ----------
  if (req.method === 'POST' && path === '/challenge') {
    const info = await spaceInfo(env, id);
    const holder = holderOf(info);
    if (!holder) return h.json({ error: 'Quỹ chưa có thủ quỹ' }, 400);
    if (userId === holder) return h.json({ error: 'Thủ quỹ không tự thử thách mình được' }, 400);
    const old = info.settings?.challenge;
    if (old && !old.passed && !old.failed && Date.now() < old.exp) return h.json({ error: 'Đang có một thử thách chưa xong' }, 400);
    const bk = b?.bank && typeof b.bank === 'object' ? b.bank : {};
    if (!str(bk.acct, 30)) return h.json({ error: 'Nhập tài khoản của bạn để thủ quỹ chuyển 1.000 ₫' }, 400);
    const code = newCode();
    const st = { ...info.settings };
    st.challenge = {
      by: userId,
      code,
      at: Date.now(),
      exp: Date.now() + 10 * 60000,
      bank: { bin: str(bk.bin, 10), name: str(bk.name, 40), acct: str(bk.acct, 30).replace(/\s+/g, ''), owner: str(bk.owner, 60).toUpperCase() },
    };
    await putSettings(env, id, st);
    await logStmt(env, id, userId, '', 'challenge', `${await nameOf(env, id, userId)} yêu cầu thủ quỹ ${await nameOf(env, id, holder)} chứng minh số dư trong 10 phút (mã ${code})`).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  if (req.method === 'POST' && path === '/challenge-done') {
    const info = await spaceInfo(env, id);
    const c = info.settings?.challenge;
    if (!c || c.by !== userId) return h.json({ error: 'Chỉ người yêu cầu mới xác nhận được' }, 403);
    const st = { ...info.settings, challenge: { ...c } };
    const who = await nameOf(env, id, userId);
    let text;
    if (b?.kind === 'transfer') {
      if (Date.now() > c.exp + 5 * 60000) return h.json({ error: 'Thử thách đã hết hạn' }, 400);
      st.challenge.passed = true;
      st.challenge.passedAt = Date.now();
      st.challenge.how = b?.auto ? 'auto' : 'manual';
      text = `${who} xác nhận đã nhận 1.000 ₫ từ tài khoản quỹ với mã ${c.code}${b?.auto ? ' (tự khớp thông báo ngân hàng trên máy người yêu cầu)' : ''}: thủ quỹ đang giữ đúng tài khoản`;
    } else if (b?.kind === 'witness') {
      const actual = Math.round(Number(b?.actual) || 0);
      const book = Math.round(Number(b?.book) || 0);
      st.challenge.witness = { actual, book, at: Date.now() };
      st.recon = { actual, book, at: Date.now(), by: userId, witness: true };
      const diff = actual - book;
      text =
        diff >= 0
          ? `${who} tận mắt xem app ngân hàng của thủ quỹ: số dư ${vnd(actual)}, đủ so với sổ ${vnd(book)}`
          : `${who} tận mắt xem app ngân hàng của thủ quỹ: số dư ${vnd(actual)}, THIẾU ${vnd(-diff)} so với sổ ${vnd(book)}`;
    } else return h.json({ error: 'Sai thao tác' }, 400);
    await putSettings(env, id, st);
    await logStmt(env, id, userId, '', b?.kind === 'witness' && Number(b?.actual) < Number(b?.book) ? 'flag' : 'challengeok', text).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  // ---------- Bàn giao thủ quỹ ----------
  if (req.method === 'POST' && path === '/handover') {
    const info = await spaceInfo(env, id);
    const ho = info.settings?.handover;
    if (!ho || ho.to !== userId) return h.json({ error: 'Không có bàn giao nào chờ bạn' }, 400);
    const actual = Math.round(Number(b?.actual) || 0);
    const st = { ...info.settings };
    delete st.handover;
    await putSettings(env, id, st);
    const who = await nameOf(env, id, userId);
    const from = await nameOf(env, id, ho.from);
    const diff = actual - ho.amount;
    await logStmt(
      env,
      id,
      userId,
      '',
      diff < 0 ? 'flag' : 'handover',
      diff < 0
        ? `${who} nhận bàn giao từ ${from}: chỉ nhận được ${vnd(actual)}, THIẾU ${vnd(-diff)} so với ${vnd(ho.amount)} phải bàn giao`
        : `${who} xác nhận đã nhận đủ ${vnd(actual)} tiền quỹ từ ${from}`
    ).run();
    return h.json({ space: await spaceInfo(env, id) });
  }

  // Kiểm tra ảnh chứng từ: AI đọc loại ảnh, số tiền, người nhận, nội dung, thời gian rồi so với khoản đang khai.
  // Chỉ "khớp" khi đúng là ảnh chuyển khoản / hóa đơn thành công, đúng số tiền, đúng người nhận + nội dung
  // (nộp cho thủ quỹ), còn mới, và chưa dùng cho khoản khác.
  if (req.method === 'POST' && path === '/verify') {
    const rec = str(b?.rec, 64);
    const img = String(b?.img || '');
    if (!rec || !img || img.length > 600000) return h.json({ error: 'Ảnh trống hoặc quá lớn' }, 400);
    if (!(await aiAllowed(env, userId))) return h.json({ error: 'Hôm nay đã hết lượt AI, mai thử lại nhé.' }, 429);
    const info = await spaceInfo(env, id);
    const type = b?.type === 'contrib' ? 'contrib' : 'spend';
    const holder = holderOf(info);
    const bank = info.settings?.bank;
    const toHolder = type === 'contrib' && holder && holder !== userId;
    const p = await visionJson(env, VERIFY_PROMPT, img).catch(() => null);
    if (!p) return h.json({ error: 'AI chưa đọc được ảnh, thử lại sau ít phút.' }, 502);
    const ai = {
      kind: ['transfer', 'receipt', 'cash', 'other'].includes(p.kind) ? p.kind : 'other',
      success: p.success === true,
      direction: ['out', 'in'].includes(p.direction) ? p.direction : 'unknown',
      amount: int(p.amount) || null,
      to_account: str(p.to_account, 40),
      to_name: str(p.to_name, 80),
      memo: str(p.memo, 160),
      datetime: str(p.datetime, 20),
      merchant: str(p.merchant, 80),
      suspicious: str(p.suspicious, 160),
    };
    const checks = [];
    const add = (cid, ok, text) => checks.push({ id: cid, ok: !!ok, text });
    // 1) loại ảnh
    if (type === 'contrib') {
      add('kind', ai.kind === 'transfer' || (!bank && ai.kind === 'cash'), ai.kind === 'transfer' ? 'Ảnh chuyển khoản' : ai.kind === 'cash' ? 'Ảnh tiền mặt' : 'Không phải ảnh chuyển khoản');
    } else {
      add('kind', ai.kind === 'transfer' || ai.kind === 'receipt', ai.kind === 'receipt' ? 'Hóa đơn / bill' : ai.kind === 'transfer' ? 'Ảnh chuyển khoản' : 'Không phải hóa đơn hay ảnh chuyển khoản');
    }
    if (ai.kind === 'transfer') {
      add('success', ai.success, ai.success ? 'Giao dịch thành công' : 'Không thấy chữ giao dịch thành công');
      if (ai.direction === 'in') add('dir', false, 'Đây là ảnh tiền NHẬN vào, không phải tiền chuyển đi');
    }
    // 2) số tiền: app so lại theo số người dùng nhập cuối cùng
    add('amount', ai.amount != null && ai.amount === int(b?.amount), ai.amount != null ? `AI đọc được ${vnd(ai.amount)}` : 'Không đọc được số tiền');
    // 3) đúng người nhận + nội dung khi nộp cho thủ quỹ
    if (toHolder && bank?.acct && ai.kind === 'transfer') {
      const digits = ai.to_account.replace(/\D/g, '');
      const acctOk = digits.length >= 3 && String(bank.acct).endsWith(digits.slice(-Math.min(digits.length, 6)));
      const nameOk = !!bank.owner && !!ai.to_name && fold(ai.to_name).replace(/[^A-Z]/g, '').includes(fold(bank.owner).replace(/[^A-Z]/g, '').slice(0, 12));
      add('to', acctOk || nameOk, acctOk || nameOk ? `Đúng người nhận (${bank.name} ${bank.acct})` : `Người nhận trên ảnh (${ai.to_name || ai.to_account || 'không rõ'}) không phải tài khoản quỹ`);
      const memoOk = fold(ai.memo).replace(/[^A-Z0-9]/g, '').includes(('VT' + info.code + str(b?.tag, 8)).toUpperCase());
      add('memo', memoOk, memoOk ? 'Đúng nội dung chuyển khoản' : `Nội dung chuyển khoản không có mã "VT ${info.code} ${str(b?.tag, 8)}"`);
    }
    if (type === 'spend' && ai.kind === 'transfer' && bank?.acct) {
      const digits = ai.to_account.replace(/\D/g, '');
      if (digits.length >= 4 && String(bank.acct).endsWith(digits.slice(-6)) || fold(ai.memo).replace(/[^A-Z0-9]/g, '').includes('VT' + info.code)) {
        add('dir', false, 'Đây là ảnh chuyển tiền VÀO quỹ, không phải khoản chi');
      }
    }
    // 4) còn mới
    const t = vnTime(ai.datetime);
    const maxAge = type === 'contrib' ? 2 : 7;
    if (t) {
      const age = (Date.now() - t) / 86400000;
      add('time', age < maxAge && age > -0.1, age < maxAge && age > -0.1 ? 'Thời gian giao dịch mới' : `Giao dịch từ ${ai.datetime}, đã cũ`);
    } else if (ai.kind === 'transfer') {
      add('time', false, 'Không thấy thời gian giao dịch trên ảnh');
    }
    // 5) dấu hiệu sửa ảnh
    if (ai.suspicious) add('edit', false, 'Ảnh có dấu hiệu chỉnh sửa: ' + ai.suspicious);
    // 6) ảnh / giao dịch đã dùng cho khoản khác
    const keys = ['h:' + (await sha(img))];
    if (ai.amount && ai.datetime) keys.push('f:' + (await sha([ai.amount, ai.datetime, ai.to_account, fold(ai.memo)].join('|'))));
    let reused = null;
    for (const k of keys) {
      const r = await env.DB.prepare('SELECT rec_id FROM space_proof_keys WHERE space_id = ? AND k = ?').bind(id, k).first().catch(() => null);
      if (!r || r.rec_id === rec) continue;
      const live = await env.DB.prepare('SELECT deleted FROM space_records WHERE space_id = ? AND id = ?').bind(id, r.rec_id).first();
      if (live && !live.deleted) reused = r.rec_id;
    }
    add('reuse', !reused, reused ? 'Ảnh / giao dịch này đã được dùng cho một khoản khác trong quỹ' : 'Chưa dùng cho khoản nào khác');
    if (!reused) {
      await env.DB.batch(
        keys.map((k) =>
          env.DB.prepare('INSERT INTO space_proof_keys (space_id, k, rec_id, at) VALUES (?, ?, ?, ?) ON CONFLICT (space_id, k) DO UPDATE SET rec_id = excluded.rec_id, at = excluded.at').bind(id, k, rec, Date.now())
        )
      ).catch(() => {});
    }
    return h.json({ ai, checks, ok: checks.every((c) => c.ok) });
  }

  // Ảnh chứng từ: người ghi khoản tải lên, cả nhóm xem được.
  if (path === '/proof') {
    const rec = str(b?.rec ?? url.searchParams.get('rec'), 64);
    if (req.method === 'GET') {
      const p = await env.DB.prepare('SELECT img FROM space_proofs WHERE space_id = ? AND rec_id = ?').bind(id, rec).first();
      return p ? h.json({ img: p.img }) : h.json({ error: 'Chưa có ảnh' }, 404);
    }
    // ảnh được tải lên trước khi ghi khoản (khoản chưa có) hoặc người ghi khoản đổi ảnh
    const r = await env.DB.prepare('SELECT by_user FROM space_records WHERE space_id = ? AND id = ?').bind(id, rec).first();
    if (r && r.by_user !== userId) return h.json({ error: 'Chỉ người ghi khoản mới thêm ảnh' }, 403);
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
    await syncBank(env, id, bankH()).catch(() => {});
    await expireChallenge(env, id).catch(() => {});
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
          let extra = d.type === 'spend' && d.ask ? ' (cần duyệt)' : d.type === 'contrib' && d.pending ? ' (chờ thủ quỹ xác nhận)' : '';
          const ai = d.proofAi == null ? null : int(d.proofAi);
          const off = d.proofOk === false || (ai != null && Math.abs(ai - amt) > Math.max(1000, amt * 0.02));
          extra += d.img || ai != null
            ? off
              ? `, ẢNH CHỨNG TỪ KHÔNG KHỚP${d.proofWhy ? ': ' + str(d.proofWhy, 160) : ''}`
              : d.proofOk
                ? ', ảnh chứng từ đã được AI kiểm tra khớp'
                : ', có ảnh chứng từ'
            : ', KHÔNG có ảnh chứng từ';
          stmts.push(logStmt(env, id, userId, c.id, off ? 'flag' : d.type === 'contrib' ? 'contrib' : 'spend', `${who} ${label} ${vnd(amt)}${note}${extra}`, now));
        }
      } else {
        const od = JSON.parse(old.data || '{}');
        if (c.del && !old.deleted) {
          stmts.push(logStmt(env, id, userId, c.id, 'delete', `${who} XÓA khoản ${label} ${vnd(od.amount)}${od.note ? ' · ' + str(od.note, 60) : ''}`, now));
        } else if (!c.del && int(od.amount) !== amt) {
          stmts.push(logStmt(env, id, userId, c.id, 'edit', `${who} SỬA khoản ${label} ${vnd(od.amount)} → ${vnd(amt)}${note}`, now));
          // đổi số tiền thì các xác nhận / duyệt cũ hết hiệu lực
          stmts.push(env.DB.prepare('DELETE FROM space_marks WHERE space_id = ? AND rec_id = ?').bind(id, c.id));
        } else if (!c.del && (d.proofAi != null || d.img) && od.proofAi == null && !od.img) {
          const ai = d.proofAi == null ? null : int(d.proofAi);
          const off = ai != null && Math.abs(ai - amt) > Math.max(1000, amt * 0.02);
          stmts.push(
            logStmt(
              env,
              id,
              userId,
              c.id,
              off ? 'flag' : 'proof',
              off
                ? `Ảnh chứng từ khoản ${label} ${vnd(amt)} của ${who}: AI đọc được ${vnd(ai)}, LỆCH ${vnd(Math.abs(ai - amt))}`
                : `${who} thêm ảnh chứng từ cho khoản ${label} ${vnd(amt)}${ai != null ? ' (AI đọc khớp)' : ''}`,
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
    const warn = new Set(['delete', 'edit', 'flag', 'reject', 'deny', 'settings', 'bankout', 'bankerr', 'bankoff', 'challengefail', 'challenge']);
    return rows.map((r) => ({ at: r.at, title: (warn.has(r.action) ? 'Chú ý · ' : '') + r.space, body: r.text }));
  } catch {
    return [];
  }
}
