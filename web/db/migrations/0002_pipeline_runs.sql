CREATE TABLE IF NOT EXISTS pipeline_runs (
  id            TEXT PRIMARY KEY,
  pipeline_id   TEXT NOT NULL REFERENCES pipeline_definitions(id),
  status        TEXT NOT NULL,
  trigger_type  TEXT NOT NULL DEFAULT 'manual',
  started_at    TEXT NOT NULL,
  finished_at   TEXT,
  duration_ms   INTEGER,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_pipeline_id ON pipeline_runs(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_status ON pipeline_runs(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started_at ON pipeline_runs(started_at DESC);
