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
