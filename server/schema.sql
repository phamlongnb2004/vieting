-- Bảng dữ liệu cho server đồng bộ VieTing (Cloudflare D1)
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  salt TEXT NOT NULL,
  hash TEXT NOT NULL,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS records (
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  srv INTEGER NOT NULL,
  PRIMARY KEY (user_id, kind, id)
);

CREATE INDEX IF NOT EXISTS records_user_srv ON records (user_id, srv);

-- Đếm lượt hỏi trợ lý AI mỗi ngày (giữ trong hạn mức miễn phí)
CREATE TABLE IF NOT EXISTS ai_usage (
  k TEXT NOT NULL,
  day TEXT NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (k, day)
);

-- Quản trị: ai là admin, tài khoản bị khóa, thông báo gửi tới app
CREATE TABLE IF NOT EXISTS admins (
  user_id INTEGER PRIMARY KEY,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS banned (
  user_id INTEGER PRIMARY KEY,
  reason TEXT NOT NULL DEFAULT '',
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS notices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  level TEXT NOT NULL DEFAULT 'info',
  active INTEGER NOT NULL DEFAULT 1,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS admin_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  target TEXT NOT NULL DEFAULT '',
  created INTEGER NOT NULL
);

-- ===== Bản 0.3: trung tâm quản trị mở rộng =====
-- Từ điển nhận diện tiếng Việt (từ lóng, thương hiệu -> danh mục), dùng cho AI và app
CREATE TABLE IF NOT EXISTS dict (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  keyword TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created INTEGER NOT NULL
);
INSERT OR IGNORE INTO dict (keyword, category, note, created) VALUES
  ('a95', 'di_lai', 'đổ xăng A95', 0), ('e5', 'di_lai', 'xăng E5', 0), ('petrolimex', 'di_lai', '', 0),
  ('tóp tóp', 'mua_sam', 'TikTok Shop', 0), ('tiktok shop', 'mua_sam', '', 0), ('chốt đơn', 'mua_sam', '', 0),
  ('shopee', 'mua_sam', '', 0), ('lazada', 'mua_sam', '', 0), ('tiki', 'mua_sam', '', 0),
  ('grabfood', 'an_uong', '', 0), ('shopeefood', 'an_uong', '', 0), ('be food', 'an_uong', '', 0),
  ('trà sữa', 'an_uong', '', 0), ('highlands', 'an_uong', '', 0), ('phúc long', 'an_uong', '', 0),
  ('xanh sm', 'di_lai', 'taxi điện', 0), ('be bike', 'di_lai', '', 0), ('grabbike', 'di_lai', '', 0),
  ('bách hóa xanh', 'an_uong', 'đi chợ', 0), ('winmart', 'an_uong', 'đi chợ', 0), ('co.op', 'an_uong', 'đi chợ', 0),
  ('evn', 'hoa_don', 'tiền điện', 0), ('nước sạch', 'hoa_don', '', 0), ('fpt telecom', 'hoa_don', 'internet', 0),
  ('long châu', 'suc_khoe', 'nhà thuốc', 0), ('pharmacity', 'suc_khoe', 'nhà thuốc', 0),
  ('cgv', 'giai_tri', 'xem phim', 0), ('lotte cinema', 'giai_tri', '', 0);

-- Báo AI đọc hóa đơn sai (không lưu ảnh, chỉ lưu số AI đọc và số người dùng sửa lại)
CREATE TABLE IF NOT EXISTS ocr_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  ai TEXT NOT NULL,
  fixed TEXT NOT NULL,
  comment TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'new',
  created INTEGER NOT NULL
);

-- Cấu hình chung dạng khóa -> JSON (giọng trợ lý, dịp đặc biệt, lãi suất, tỷ giá đã lưu...)
CREATE TABLE IF NOT EXISTS config (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
);

-- Thử thách / sự kiện theo mùa do admin tạo
CREATE TABLE IF NOT EXISTS campaigns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL DEFAULT 'avoid',   -- avoid: kiêng chi | goal: gom tiền
  title TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '🎯',
  body TEXT NOT NULL DEFAULT '',
  keywords TEXT NOT NULL DEFAULT '',   -- avoid: từ khóa cách nhau dấu phẩy
  category TEXT NOT NULL DEFAULT '',   -- avoid: danh mục cần kiêng
  days INTEGER NOT NULL DEFAULT 7,
  target INTEGER NOT NULL DEFAULT 0,   -- goal: số tiền mục tiêu
  start INTEGER NOT NULL,
  end INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created INTEGER NOT NULL
);

-- Danh sách gói định kỳ phổ biến để app gợi ý (giá tham khảo, admin cập nhật)
CREATE TABLE IF NOT EXISTS catalog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  amount INTEGER NOT NULL,
  cycle TEXT NOT NULL DEFAULT 'month',
  category TEXT NOT NULL DEFAULT 'giai_tri',
  sort INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO catalog (name, amount, cycle, category, sort) VALUES
  ('Netflix', 260000, 'month', 'giai_tri', 1), ('Spotify', 59000, 'month', 'giai_tri', 2),
  ('YouTube Premium', 79000, 'month', 'giai_tri', 3), ('iCloud 50GB', 25000, 'month', 'hoa_don', 4),
  ('Google One 100GB', 45000, 'month', 'hoa_don', 5), ('Gói 4G tháng', 120000, 'month', 'hoa_don', 6),
  ('Internet gia đình', 220000, 'month', 'hoa_don', 7), ('FPT Play', 80000, 'month', 'giai_tri', 8),
  ('Gym', 500000, 'month', 'suc_khoe', 9), ('Tiền nhà', 3000000, 'month', 'nha_o', 10),
  ('ChatGPT Plus', 520000, 'month', 'giao_duc', 11), ('Apple Music', 65000, 'month', 'giai_tri', 12);

-- Gói Free / Pro, mã khuyến mãi
CREATE TABLE IF NOT EXISTS plans (
  user_id INTEGER PRIMARY KEY,
  plan TEXT NOT NULL DEFAULT 'pro',
  until INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS vouchers (
  code TEXT PRIMARY KEY,
  days INTEGER NOT NULL,
  max_uses INTEGER NOT NULL DEFAULT 1,
  used INTEGER NOT NULL DEFAULT 0,
  expires INTEGER NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  created INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS voucher_uses (
  code TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  created INTEGER NOT NULL,
  PRIMARY KEY (code, user_id)
);

-- Góp ý / báo lỗi
CREATE TABLE IF NOT EXISTS tickets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  contact TEXT NOT NULL DEFAULT '',
  feature TEXT NOT NULL DEFAULT 'khac',
  body TEXT NOT NULL,
  app TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  reply TEXT NOT NULL DEFAULT '',
  seen INTEGER NOT NULL DEFAULT 1,
  created INTEGER NOT NULL,
  updated INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS tickets_user ON tickets (user_id);

-- Thông báo đẩy tới máy người dùng (máy tự hỏi server khoảng 30 phút / lần, không cần mở app)
CREATE TABLE IF NOT EXISTS pushes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  created INTEGER NOT NULL
);

-- Quỹ chung: nhiều tài khoản (vợ chồng, bạn bè, phòng trọ...) cùng ghi vào một sổ
CREATE TABLE IF NOT EXISTS spaces (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  owner INTEGER NOT NULL,
  target INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS space_members (
  space_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  nick TEXT NOT NULL DEFAULT '',
  joined INTEGER NOT NULL,
  PRIMARY KEY (space_id, user_id)
);
CREATE INDEX IF NOT EXISTS space_members_user ON space_members (user_id);
CREATE TABLE IF NOT EXISTS space_records (
  space_id INTEGER NOT NULL,
  id TEXT NOT NULL,
  by_user INTEGER NOT NULL,
  data TEXT NOT NULL,
  u INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  srv INTEGER NOT NULL,
  PRIMARY KEY (space_id, id)
);
CREATE INDEX IF NOT EXISTS space_records_srv ON space_records (space_id, srv);

-- Quỹ chung: thủ quỹ, tài khoản nhận, ngưỡng cần duyệt, lần đối chiếu gần nhất (JSON)
CREATE TABLE IF NOT EXISTS space_settings (
  space_id INTEGER PRIMARY KEY,
  data TEXT NOT NULL DEFAULT '{}'
);
-- Xác nhận đã nhận tiền (thủ quỹ) / duyệt khoản chi (thành viên khác): mỗi người một dấu trên mỗi khoản
CREATE TABLE IF NOT EXISTS space_marks (
  space_id INTEGER NOT NULL,
  rec_id TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (space_id, rec_id, user_id)
);
CREATE INDEX IF NOT EXISTS space_marks_at ON space_marks (space_id, at);
-- Nhật ký quỹ: ai ghi / sửa / xóa / xác nhận / đối chiếu, không ai xóa được
CREATE TABLE IF NOT EXISTS space_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  space_id INTEGER NOT NULL,
  at INTEGER NOT NULL,
  by_user INTEGER NOT NULL,
  rec_id TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,
  text TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS space_log_space ON space_log (space_id, at);
-- Ảnh chứng từ của khoản chi / nộp quỹ
CREATE TABLE IF NOT EXISTS space_proofs (
  space_id INTEGER NOT NULL,
  rec_id TEXT NOT NULL,
  img TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (space_id, rec_id)
);
-- Dấu vân tay ảnh chứng từ: phát hiện một ảnh / một giao dịch bị dùng lại cho nhiều khoản
CREATE TABLE IF NOT EXISTS space_proof_keys (
  space_id INTEGER NOT NULL,
  k TEXT NOT NULL,
  rec_id TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (space_id, k)
);
