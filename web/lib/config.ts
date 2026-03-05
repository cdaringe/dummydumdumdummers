/**
 * Service configuration, driven by THINGFACTORY_* environment variables.
 *
 * All service-specific configuration uses the THINGFACTORY_ prefix.
 * Standard platform variables (NODE_ENV, PORT) are read directly.
 */

import { join } from "path";
import { mkdirSync } from "fs";
import type { ExecutorKind } from "./types";

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

  const allowedExecutorsRaw = process.env.THINGFACTORY_ALLOWED_EXECUTORS ?? "local";
  const parsedExecutors = allowedExecutorsRaw
    .split(",")
    .map((s) => s.trim())
    .filter((s): s is ExecutorKind => s === "local" || s === "docker");
  const allowedExecutors: ExecutorKind[] = parsedExecutors.length === 0 ? ["local"] : parsedExecutors;

  return {
    dataDirname,
    databasePath,
    port: parseInt(
      process.env.THINGFACTORY_PORT ?? process.env.PORT ?? "3000",
      10,
    ),
    nodeEnv,
    allowedExecutors,
  };
}

export const config = getConfig();
