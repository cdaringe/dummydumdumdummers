import type DatabaseConstructor from "better-sqlite3";
import { Generated, Kysely, SqliteDialect } from "kysely";
import { config } from "./config";

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

interface GitHubConnectionsTable {
  id: string;
  token: string;
  org: string;
  repo: string;
  branch: string;
  pipeline_id: string | null;
  created_at: Generated<string>;
}

interface ThingfactoryDB {
  pipeline_definitions: PipelineDefinitionsTable;
  pipeline_runs: PipelineRunsTable;
  step_traces: StepTracesTable;
  artifacts: ArtifactsTable;
  github_connections: GitHubConnectionsTable;
}

let _rawDb: DatabaseConstructor.Database | undefined;
let _db: Kysely<ThingfactoryDB> | undefined;

function initRawDb(): DatabaseConstructor.Database {
  if (!_rawDb) {
    // Dynamic require so the native module is not loaded at import time.
    // This is critical for Docker cross-platform builds where next build
    // evaluates route modules during "Collecting page data" but the native
    // binary may not match the build host architecture.
    const Database = require("better-sqlite3") as typeof DatabaseConstructor;
    const dbPath = config.databasePath;
    _rawDb = new Database(dbPath);
    _rawDb.pragma("journal_mode = WAL");
    _rawDb.pragma("foreign_keys = ON");

    // When using in-memory database (tests), auto-create schema
    if (dbPath === ":memory:") {
      _rawDb.exec(`
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
    CREATE TABLE IF NOT EXISTS github_connections (
      id          TEXT PRIMARY KEY,
      token       TEXT NOT NULL,
      org         TEXT NOT NULL,
      repo        TEXT NOT NULL,
      branch      TEXT NOT NULL,
      pipeline_id TEXT,
      created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );
  `);

      // Auto-seed in-memory databases so all module instances have data.
      // Turbopack dev mode uses separate module instances for API routes vs pages,
      // so seeding only via the reset API wouldn't reach page-renderer module instances.
      const { seedFixturesIfEmpty } = require("./seed-fixtures");
      seedFixturesIfEmpty(_rawDb);
    }
  }
  return _rawDb;
}

function initDb(): Kysely<ThingfactoryDB> {
  if (!_db) {
    _db = new Kysely<ThingfactoryDB>({
      dialect: new SqliteDialect({ database: initRawDb() }),
    });
  }
  return _db;
}

// Proxy exports so that db and rawDb are lazily initialized on first property access.
// This prevents the native better-sqlite3 module from loading at import time.
// Wrap a value from the target so that:
// - Functions are called with target as `this` (needed for Kysely private fields).
// - Function own-properties (e.g. db.fn.count) are still accessible.
function wrapValue(target: any, value: any): any {
  if (typeof value !== "function") return value;
  return new Proxy(value, {
    apply(_fn, _thisArg, args) {
      return value.apply(target, args);
    },
    get(_fn, innerProp) {
      return value[innerProp as string];
    },
  });
}

export const rawDb: DatabaseConstructor.Database = new Proxy(
  {} as DatabaseConstructor.Database,
  {
    get(_, prop) {
      const target = initRawDb() as any;
      return wrapValue(target, target[prop as string]);
    },
  },
);

export const db: Kysely<ThingfactoryDB> = new Proxy(
  {} as Kysely<ThingfactoryDB>,
  {
    get(_, prop) {
      const target = initDb() as any;
      return wrapValue(target, target[prop as string]);
    },
  },
);
