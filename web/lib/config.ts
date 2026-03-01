/**
 * Service configuration, driven by THINGFACTORY_* environment variables.
 *
 * All service-specific configuration uses the THINGFACTORY_ prefix.
 * Standard platform variables (NODE_ENV, PORT) are read directly.
 */

export interface ServiceConfig {
  /** SQLite database file path. Set via THINGFACTORY_DATABASE_PATH. */
  databasePath: string;
  /** Web server port. Set via THINGFACTORY_PORT or PORT. Defaults to 3000. */
  port: number;
  /** Node environment. Set via NODE_ENV. */
  nodeEnv: "development" | "production" | "test";
}

export function getConfig(): ServiceConfig {
  return {
    databasePath: process.env.THINGFACTORY_DATABASE_PATH ??
      process.env.DATABASE_PATH ??
      "./db/thingfactory.db",
    port: parseInt(
      process.env.THINGFACTORY_PORT ?? process.env.PORT ?? "3000",
      10,
    ),
    nodeEnv:
      (process.env.NODE_ENV ?? "development") as ServiceConfig["nodeEnv"],
  };
}

export const config = getConfig();
