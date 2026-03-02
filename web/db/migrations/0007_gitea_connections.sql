CREATE TABLE IF NOT EXISTS gitea_connections (
  id          TEXT PRIMARY KEY,
  url         TEXT NOT NULL,
  token       TEXT NOT NULL,
  repo        TEXT NOT NULL,
  branch      TEXT NOT NULL,
  pipeline_id TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
