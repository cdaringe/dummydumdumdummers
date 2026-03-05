/**
 * Service configuration, driven by THINGFACTORY_* environment variables.
 *
 * All service-specific configuration uses the THINGFACTORY_ prefix.
 * Standard platform variables (NODE_ENV, PORT) are read directly.
 */

import { join } from "path";
import { mkdirSync } from "fs";
import type { ExecutorInstance, ExecutorKind } from "./types";

export interface ServiceConfig {
  /** Root data directory. Set via THINGFACTORY_DATA_DIRNAME. */
  dataDirname: string;
  /** SQLite database file path. Derived from dataDirname or overridden via THINGFACTORY_DATABASE_PATH. */
  databasePath: string;
  /** Web server port. Set via THINGFACTORY_PORT or PORT. Defaults to 3000. */
  port: number;
  /** Node environment. Set via NODE_ENV. */
  nodeEnv: "development" | "production" | "test";
  /** Allowed executor kinds. Set via THINGFACTORY_ALLOWED_EXECUTORS (comma-separated). Defaults to ["local"]. */
  allowedExecutors: ExecutorKind[];
  /**
   * Pool of named executor instances the system can schedule pipelines on.
   * Set via THINGFACTORY_EXECUTOR_POOL as a JSON array of ExecutorInstance objects.
   * Pipelines with `kind: "labeled"` executor requirements are matched against this pool.
   * Defaults to a single local executor with labels ["local", "standard"].
   */
  executorPool: ExecutorInstance[];
}

function defaultExecutorPool(): ExecutorInstance[] {
  return [
    {
      id: "default",
      labels: ["local", "standard"],
      config: { kind: "local" },
    },
  ];
}

function parseExecutorPool(raw: string | undefined): ExecutorInstance[] {
  if (!raw) return defaultExecutorPool();
  try {
    return JSON.parse(raw) as ExecutorInstance[];
  } catch {
    return defaultExecutorPool();
  }
}

export function getConfig(): ServiceConfig {
  const dataDirname = process.env.THINGFACTORY_DATA_DIRNAME ?? "./data";
  const databasePath = process.env.THINGFACTORY_DATABASE_PATH ??
    join(dataDirname, "db", "thingfactory.db");
  const nodeEnv =
    (process.env.NODE_ENV ?? "development") as ServiceConfig["nodeEnv"];

  // ensure data subdirectories exist (skip for in-memory test dbs)
  if (databasePath !== ":memory:") {
    for (const sub of ["db", "logs", "backups"]) {
      mkdirSync(join(dataDirname, sub), { recursive: true });
    }
  }

  const allowedExecutorsRaw = process.env.THINGFACTORY_ALLOWED_EXECUTORS ??
    "local";
  const parsedExecutors = allowedExecutorsRaw
    .split(",")
    .map((s) => s.trim())
    .filter((s): s is ExecutorKind => s === "local" || s === "docker");
  const allowedExecutors: ExecutorKind[] = parsedExecutors.length === 0
    ? ["local"]
    : parsedExecutors;

  const executorPool = parseExecutorPool(
    process.env.THINGFACTORY_EXECUTOR_POOL,
  );

  return {
    dataDirname,
    databasePath,
    port: parseInt(
      process.env.THINGFACTORY_PORT ?? process.env.PORT ?? "3000",
      10,
    ),
    nodeEnv,
    allowedExecutors,
    executorPool,
  };
}

export const config = getConfig();
