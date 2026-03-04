import Database from "better-sqlite3";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { seedFixturesIfEmpty } from "../lib/seed-fixtures";
import { getConfig } from "../lib/config";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cfg = getConfig();
const dbPath = cfg.databasePath === "./db/thingfactory.db"
  ? join(__dirname, "thingfactory.db")
  : cfg.databasePath;
const db = new Database(dbPath);
db.pragma("foreign_keys = ON");

seedFixturesIfEmpty(db);

console.log("Seeded pipelines with synthetic run history.");
db.close();
