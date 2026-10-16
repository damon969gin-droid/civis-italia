-- Database di Civis (Cloudflare D1, SQLite).
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL DEFAULT '',
  pass_hash   TEXT NOT NULL,
  created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  pages        INTEGER NOT NULL,
  status       TEXT NOT NULL DEFAULT 'draft',   -- draft | analyzed | failed
  analysis     TEXT,                            -- JSON dell'analisi
  created_at   TEXT NOT NULL,
  analyzed_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_documents_user ON documents(user_id, created_at);

CREATE TABLE IF NOT EXISTS deadlines (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_id      TEXT REFERENCES documents(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  date        TEXT NOT NULL,                    -- YYYY-MM-DD
  note        TEXT NOT NULL DEFAULT '',
  done        INTEGER NOT NULL DEFAULT 0,
  auto        INTEGER NOT NULL DEFAULT 0,       -- 1 = creata dall'analisi
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_deadlines_user ON deadlines(user_id, date);

CREATE TABLE IF NOT EXISTS usage (
  user_id  TEXT NOT NULL,
  month    TEXT NOT NULL,                       -- YYYY-MM
  docs     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, month)
);

CREATE TABLE IF NOT EXISTS login_attempts (
  email  TEXT NOT NULL,
  ts     INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_login_attempts ON login_attempts(email, ts);

-- Foto delle pagine (base64), private per utente. Sostituisce R2.
CREATE TABLE IF NOT EXISTS pages (
  doc_id  TEXT NOT NULL,
  n       INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  type    TEXT NOT NULL,
  data    TEXT NOT NULL,
  PRIMARY KEY (doc_id, n)
);
CREATE INDEX IF NOT EXISTS idx_pages_user ON pages(user_id);
