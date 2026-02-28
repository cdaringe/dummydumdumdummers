import Database from "better-sqlite3";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { seedFixtures } from "../lib/seed-fixtures";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dbPath = process.env.DATABASE_PATH ?? join(__dirname, "thingfactory.db");
const db = new Database(dbPath);
db.pragma("foreign_keys = ON");

seedFixtures(db);

console.log("Seeded pipelines with synthetic run history.");
db.close();
