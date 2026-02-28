CREATE TABLE IF NOT EXISTS pipeline_definitions (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  version     TEXT NOT NULL,
  description TEXT,
  schedule    TEXT NOT NULL DEFAULT 'NoSchedule',
  trigger     TEXT NOT NULL DEFAULT 'NoTrigger',
  steps       TEXT NOT NULL,
  timeout_ms  INTEGER NOT NULL DEFAULT 1800000,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  UNIQUE(name, version)
);
