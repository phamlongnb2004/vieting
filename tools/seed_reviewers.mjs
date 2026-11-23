// Tạo tài khoản thử cho người duyệt Google Play / App Store, kèm dữ liệu mẫu. Tác giả: Phạm Thành Long (thlong)
// Chạy qua tao-tai-khoan-thu.bat. Mật khẩu do bạn tự gõ, script chỉ băm (PBKDF2 giống server) rồi tạo file SQL.
// Chạy lại được nhiều lần: tài khoản đã có thì chỉ đặt lại mật khẩu và làm mới dữ liệu mẫu.
import { pbkdf2Sync, randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { createInterface } from 'node:readline';

const SERVER = process.env.VIETING_SERVER || 'https://vieting.phamthanhlong-contact.workers.dev';
const OUT = process.argv[2] || 'seed-reviewers.sql';

const ACCOUNTS = [
  { email: 'reviewer@example.com', name: 'Play Reviewer', year: 1995, nick: 'Reviewer' },
  { email: 'reviewer2@example.com', name: 'Lan Nguyen', year: 1997, nick: 'Lan' },
  { email: 'reviewer3@example.com', name: 'Minh Tran', year: 1993, nick: 'Minh' },
];

function ask(q) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((r) => rl.question(q, (a) => (rl.close(), r(a))));
}

const q = (v) => (v === null || v === undefined ? 'NULL' : typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`);
const uid = (email) => `(SELECT id FROM users WHERE email = ${q(email)})`;

const pw = (await ask('Mat khau cho cac tai khoan thu (it nhat 6 ky tu): ')).trim();
if (pw.length < 6) {
  console.error('Mat khau qua ngan.');
  process.exit(1);
}

// cho server tạo các cột mới (họ tên, năm sinh...) trước khi ghi
try {
  await fetch(SERVER + '/api/auth/google/enabled');
} catch {
  console.error('Canh bao: khong goi duoc server ' + SERVER + ' (nen chay tai-len-cloudflare.bat truoc).');
}

const now = Date.now();
const DAY = 86400000;
const sql = [];

for (const a of ACCOUNTS) {
  const salt = randomBytes(16).toString('hex');
  const hash = pbkdf2Sync(pw, Buffer.from(salt, 'hex'), 100000, 32, 'sha256').toString('hex');
  sql.push(
    `INSERT INTO users (email, salt, hash, created, full_name, birth_year, nopw) VALUES (${q(a.email)}, ${q(salt)}, ${q(hash)}, ${now}, ${q(a.name)}, ${a.year}, 0)
     ON CONFLICT (email) DO UPDATE SET salt = excluded.salt, hash = excluded.hash, full_name = excluded.full_name, birth_year = excluded.birth_year, nopw = 0;`
  );
  // Pro 1 năm để người duyệt thấy đủ tính năng
  sql.push(
    `INSERT INTO plans (user_id, plan, until, note) VALUES (${uid(a.email)}, 'pro', ${now + 365 * DAY}, 'Tai khoan duyet app')
     ON CONFLICT (user_id) DO UPDATE SET plan = 'pro', until = excluded.until, note = excluded.note;`
  );
  sql.push(`DELETE FROM records WHERE user_id = ${uid(a.email)};`);
}

// ---- Dữ liệu cá nhân mẫu: ví, giao dịch 45 ngày, ngân sách, mục tiêu ----
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
function rec(email, kind, id, data) {
  data.id = id;
  data.u = now;
  data.del = false;
  sql.push(
    `INSERT INTO records (user_id, kind, id, data, updated_at, deleted, srv) VALUES (${uid(email)}, ${q(kind)}, ${q(id)}, ${q(JSON.stringify(data))}, ${now}, 0, ${now})
     ON CONFLICT (user_id, kind, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at, deleted = 0, srv = excluded.srv;`
  );
}

const SPEND = [
  ['an_uong', 'Phở bò', 45000, 'cash'],
  ['an_uong', 'Cà phê sữa', 29000, 'cash'],
  ['an_uong', 'Cơm trưa văn phòng', 40000, 'cash'],
  ['an_uong', 'Trà sữa', 35000, 'bank'],
  ['di_lai', 'Grab đi làm', 52000, 'bank'],
  ['di_lai', 'Đổ xăng', 80000, 'cash'],
  ['mua_sam', 'Shopee: áo thun', 189000, 'bank'],
  ['giai_tri', 'Vé xem phim', 110000, 'bank'],
  ['suc_khoe', 'Thuốc cảm', 65000, 'cash'],
  ['an_uong', 'Bún chả', 50000, 'cash'],
];

for (const a of ACCOUNTS) {
  rec(a.email, 'wallet', 'w_cash', { name: 'Tiền mặt', kind: 'cash', initial: 1500000, bank: '', color: 0xff3e8e41 });
  rec(a.email, 'wallet', 'w_bank', { name: 'Vietcombank', kind: 'bank', initial: 8000000, bank: 'vcb', color: 0xff152758 });
  rec(a.email, 'budget', 'all', { limit: 9000000 });
  rec(a.email, 'budget', 'an_uong', { limit: 3000000 });
  rec(a.email, 'goal', 'g_laptop', { name: 'Laptop mới', emoji: 'laptop', target: 20000000, saved: 6500000, deadline: now + 120 * DAY });
  let n = 0;
  for (let d = 44; d >= 0; d--) {
    const day = new Date(now - d * DAY);
    if (day.getDate() === 5) {
      rec(a.email, 'txn', `t_${n++}`, {
        amount: 15000000, income: true, cat: 'luong', wallet: 'w_bank', date: day.setHours(9, 0, 0, 0), note: 'Lương tháng', source: 'manual', raw: '',
      });
    }
    const k = 1 + Math.floor(rnd() * 3);
    for (let i = 0; i < k; i++) {
      const [cat, note, amt, w] = SPEND[Math.floor(rnd() * SPEND.length)];
      const t = new Date(now - d * DAY);
      t.setHours(8 + Math.floor(rnd() * 13), Math.floor(rnd() * 60), 0, 0);
      if (t.getTime() > now) continue;
      rec(a.email, 'txn', `t_${n++}`, {
        amount: amt, income: false, cat, wallet: w === 'cash' ? 'w_cash' : 'w_bank', date: t.getTime(), note, source: 'manual', raw: '',
      });
    }
  }
  rec(a.email, 'txn', `t_${n++}`, {
    amount: 1200000, income: false, cat: 'hoa_don', wallet: 'w_bank', date: now - 3 * DAY, note: 'Tiền điện', source: 'manual', raw: '',
  });
}

// ---- Quỹ chung mẫu: 3 người, mã mời REVIEW ----
const owner = ACCOUNTS[0].email;
sql.push(`DELETE FROM space_records WHERE space_id IN (SELECT id FROM spaces WHERE code = 'REVIEW');`);
sql.push(`DELETE FROM space_marks WHERE space_id IN (SELECT id FROM spaces WHERE code = 'REVIEW');`);
sql.push(`DELETE FROM space_log WHERE space_id IN (SELECT id FROM spaces WHERE code = 'REVIEW');`);
sql.push(`DELETE FROM space_members WHERE space_id IN (SELECT id FROM spaces WHERE code = 'REVIEW');`);
sql.push(`DELETE FROM space_settings WHERE space_id IN (SELECT id FROM spaces WHERE code = 'REVIEW');`);
sql.push(`DELETE FROM spaces WHERE code = 'REVIEW';`);
sql.push(`INSERT INTO spaces (name, code, owner, target, created) VALUES ('Quỹ nhà mình', 'REVIEW', ${uid(owner)}, 5000000, ${now - 30 * DAY});`);
const SID = `(SELECT id FROM spaces WHERE code = 'REVIEW')`;
ACCOUNTS.forEach((a, i) => {
  sql.push(`INSERT INTO space_members (space_id, user_id, nick, joined) VALUES (${SID}, ${uid(a.email)}, ${q(a.nick)}, ${now - (30 - i) * DAY});`);
});
sql.push(`INSERT INTO space_log (space_id, at, by_user, rec_id, action, text) VALUES (${SID}, ${now - 30 * DAY}, ${uid(owner)}, '', 'create', 'Reviewer tạo quỹ "Quỹ nhà mình"');`);
const FUND = [
  [0, 'contrib', 1000000, 'Góp quỹ tháng này', '', 20],
  [1, 'contrib', 1000000, 'Góp quỹ tháng này', '', 19],
  [2, 'contrib', 1000000, 'Góp quỹ tháng này', '', 18],
  [1, 'spend', 650000, 'Đi chợ cuối tuần', 'an_uong', 12],
  [2, 'spend', 420000, 'Tiền điện nước', 'hoa_don', 6],
  [0, 'spend', 280000, 'Mua đồ dùng nhà', 'gia_dinh', 2],
];
FUND.forEach(([who, type, amount, note, cat, ago], i) => {
  const at = now - ago * DAY;
  const data = { type, amount, note, cat, date: at };
  sql.push(
    `INSERT INTO space_records (space_id, id, by_user, data, u, deleted, srv) VALUES (${SID}, 'r${i}', ${uid(ACCOUNTS[who].email)}, ${q(JSON.stringify(data))}, ${at}, 0, ${now})`.concat(';')
  );
  sql.push(
    `INSERT INTO space_log (space_id, at, by_user, rec_id, action, text) VALUES (${SID}, ${at}, ${uid(ACCOUNTS[who].email)}, 'r${i}', 'add', ${q(`${ACCOUNTS[who].nick} ${type === 'contrib' ? 'nộp' : 'chi'} ${amount.toLocaleString('vi-VN')} ₫: ${note}`)});`
  );
});

writeFileSync(OUT, sql.join('\n') + '\n', 'utf8');
console.log(`Da tao ${OUT}: ${ACCOUNTS.length} tai khoan, ma moi quy chung: REVIEW`);
