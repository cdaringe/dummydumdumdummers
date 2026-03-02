CREATE TABLE IF NOT EXISTS github_connections (
  id          TEXT PRIMARY KEY,
  token       TEXT NOT NULL,
  org         TEXT NOT NULL,
  repo        TEXT NOT NULL,
  branch      TEXT NOT NULL,
  pipeline_id TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
