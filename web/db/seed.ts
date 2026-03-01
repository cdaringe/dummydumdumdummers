import Database from "better-sqlite3";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { seedFixtures } from "../lib/seed-fixtures";
import { getConfig } from "../lib/config";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cfg = getConfig();
const dbPath = cfg.databasePath === "./db/thingfactory.db"
  ? join(__dirname, "thingfactory.db")
  : cfg.databasePath;
const db = new Database(dbPath);
db.pragma("foreign_keys = ON");

seedFixtures(db);

console.log("Seeded pipelines with synthetic run history.");
db.close();
