// Get command-line arguments (skip first two: node and script path)
// This function returns a proper Gleam list

// Import Gleam's list constructors from prelude
import { Empty as $EmptyClass, toList, Ok, Error } from "../gleam.mjs";
import * as readline from "readline";
import * as fs from "fs";
import * as path from "path";

export function load_pipeline(module_name, function_name) {
  return new Error(
    `Dynamic pipeline loading is only supported on the Erlang target. Received ${module_name}:${function_name}`,
  );
}

export function get_argv() {
  const args = typeof process !== 'undefined' ? process.argv.slice(2) : [];

  // Use Gleam's toList function to create a proper Gleam list from the array
  return toList(args);
}

// Readline interface for interactive mode (kept as singleton)
let rl = null;
let lineQueue = [];
let waitingForLine = false;

function getReadlineInterface() {
  if (!rl) {
    rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true
    });

    // Collect lines as they come in
    rl.on('line', (line) => {
      lineQueue.push(line);
    });
  }
  return rl;
}

// Write a file to disk, creating directories as needed
export function write_file(dir, filename, content) {
  try {
    fs.mkdirSync(dir, { recursive: true });
    const filepath = path.join(dir, filename);
    fs.writeFileSync(filepath, content, "utf-8");
    return new Ok(filepath);
  } catch (e) {
    return new Error(e.message);
  }
}

// Read a single line from stdin (using readline)
// Note: This must be called with proper async handling
export async function read_line_sync() {
  const rl = getReadlineInterface();

  return new Promise((resolve) => {
    if (lineQueue.length > 0) {
      resolve(new Ok(lineQueue.shift()));
    } else {
      // Set up a one-time listener for the next line
      const onLine = (line) => {
        rl.removeListener('line', onLine);
        resolve(new Ok(line));
      };
      rl.on('line', onLine);
    }
  });
}
