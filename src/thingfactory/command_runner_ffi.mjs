// JavaScript FFI for command runner
// Uses Node.js child_process.spawnSync for synchronous command execution

import { Ok, Error } from "../gleam.mjs";
import { spawnSync } from "child_process";

export function run_command(program, args) {
  try {
    const argsArray = args.toArray();
    const result = spawnSync(program, argsArray, {
      encoding: "utf-8",
      timeout: 300000, // 5 minutes
    });

    if (result.error) {
      return new Error(result.error.message);
    }

    return new Ok([
      result.status ?? 0,
      result.stdout ?? "",
      result.stderr ?? "",
    ]);
  } catch (e) {
    return new Error(e.message);
  }
}
