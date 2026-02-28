CREATE TABLE IF NOT EXISTS step_traces (
  id          TEXT PRIMARY KEY,
  run_id      TEXT NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
  step_name   TEXT NOT NULL,
  status      TEXT NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  error_msg   TEXT,
  sequence    INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_step_traces_run_id ON step_traces(run_id);
