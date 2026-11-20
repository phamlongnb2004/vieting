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
