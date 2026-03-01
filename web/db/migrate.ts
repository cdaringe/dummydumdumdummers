import Database from "better-sqlite3";
import { readFileSync, readdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { getConfig } from "../lib/config";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dbPath = getConfig().databasePath;
const db = new Database(dbPath);

// Enable WAL mode for better performance
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

// Create migrations tracking table
db.exec(`
  CREATE TABLE IF NOT EXISTS _migrations (
    filename TEXT PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  )
`);

const migrationsDir = join(__dirname, "migrations");
const files = readdirSync(migrationsDir)
  .filter((f) => f.endsWith(".sql"))
  .sort();

const applied = new Set(
  db
    .prepare("SELECT filename FROM _migrations")
    .all()
    .map((r) => (r as { filename: string }).filename)
);

let count = 0;
for (const file of files) {
  if (applied.has(file)) continue;
  const sql = readFileSync(join(migrationsDir, file), "utf8");
  db.exec(sql);
  db.prepare("INSERT INTO _migrations (filename) VALUES (?)").run(file);
  console.log(`Applied migration: ${file}`);
  count++;
}

if (count === 0) {
  console.log("No new migrations to apply.");
} else {
  console.log(`Applied ${count} migration(s).`);
}

db.close();
