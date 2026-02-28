CREATE TABLE IF NOT EXISTS artifacts (
  id          TEXT PRIMARY KEY,
  run_id      TEXT NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  content      TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_artifacts_run_id ON artifacts(run_id);
