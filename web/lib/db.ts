import Database from "better-sqlite3";
import { Generated, Kysely, SqliteDialect } from "kysely";

interface PipelineDefinitionsTable {
  id: string;
  name: string;
  version: string;
  description: string | null;
  schedule: Generated<string>;
  trigger: Generated<string>;
  steps: string;
  timeout_ms: Generated<number>;
  created_at: Generated<string>;
}

interface PipelineRunsTable {
  id: string;
  pipeline_id: string;
  status: string;
  trigger_type: Generated<string>;
  started_at: string;
  finished_at: string | null;
  duration_ms: number | null;
  created_at: Generated<string>;
}

interface StepTracesTable {
  id: string;
  run_id: string;
  step_name: string;
  status: string;
  duration_ms: Generated<number>;
  error_msg: string | null;
  log_output: string | null;
  sequence: number;
  created_at: Generated<string>;
}

interface ArtifactsTable {
  id: string;
  run_id: string;
  name: string;
  content: string;
  created_at: Generated<string>;
}

interface ThingfactoryDB {
  pipeline_definitions: PipelineDefinitionsTable;
  pipeline_runs: PipelineRunsTable;
  step_traces: StepTracesTable;
  artifacts: ArtifactsTable;
}

const dbPath = process.env.DATABASE_PATH ?? "./db/thingfactory.db";

export const rawDb = new Database(dbPath);
rawDb.pragma("journal_mode = WAL");
rawDb.pragma("foreign_keys = ON");

// When using in-memory database (tests), auto-create schema
if (dbPath === ":memory:") {
  rawDb.exec(`
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
    CREATE TABLE IF NOT EXISTS step_traces (
      id          TEXT PRIMARY KEY,
      run_id      TEXT NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
      step_name   TEXT NOT NULL,
      status      TEXT NOT NULL,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      error_msg   TEXT,
      log_output  TEXT,
      sequence    INTEGER NOT NULL,
      created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );
    CREATE INDEX IF NOT EXISTS idx_step_traces_run_id ON step_traces(run_id);
    CREATE TABLE IF NOT EXISTS artifacts (
      id          TEXT PRIMARY KEY,
      run_id      TEXT NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
      name        TEXT NOT NULL,
      content     TEXT NOT NULL,
      created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );
    CREATE INDEX IF NOT EXISTS idx_artifacts_run_id ON artifacts(run_id);
  `);
}

export const db = new Kysely<ThingfactoryDB>({
  dialect: new SqliteDialect({ database: rawDb }),
});
