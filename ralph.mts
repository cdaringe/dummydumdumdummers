#!/usr/bin/env -S deno run --allow-run --allow-read --allow-write --allow-env

import { parse } from "https://deno.land/std@0.208.0/flags/mod.ts";

const args = parse(Deno.args, {
  positional: ["iterations"],
});

const iterations = parseInt(args.iterations?.[0] || args._?.[0] || "10", 10);

if (!iterations || isNaN(iterations) || iterations < 1) {
  console.error("Usage: deno run ralph.mts <iterations>");
  Deno.exit(1);
}

console.log(`Starting ralph loop for ${iterations} iterations...`);

let shouldStop = false;

// Handle Ctrl+C gracefully
Deno.addSignalListener("SIGINT", () => {
  console.error("\n[$(date)] Interrupted");
  shouldStop = true;
});

const prompt = `@specification.md @progress.md
ONLY DO ONE TASK AT A TIME.

1. Read the specification.md and progress file.
2. Find the next highest leverage uninmplemented scenario and implement it.
3. Document your scenario implementation in docs/scenarios/:name.md. Write maximally concise detail, justifying how the scenario is fully completed. Reference key details & files as evidence for a reviewer.
4. Commit your changes.
5. Update progress.md scenario table with status and add a pointer to your docs/scenario/* summary.
6. If all scenarios are completed, revisit each claim ONE BY ONE in the progress
file CRITIQUE if the INTENT of the work is done.
  6.1 Review if the user's desires are met--not if the tasks are completed.
  6.2 Every referenced document or module should be verified, and not trusted to exist.
  6.3 Update status to VERIFIED or NEEDS_REWORK with rework notes.

Once all claims are VERIFIED, output <promise>COMPLETE</promise>."`;

const TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes

async function runIteration(iterationNum: number): Promise<boolean> {
  console.log(`[${new Date().toISOString()}] Starting iteration ${iterationNum}...`);

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    let output = "";
    let isComplete = false;

    const process = new Deno.Command("claude", {
      args: ["--dangerously-skip-permissions", "-p", prompt],
      stdout: "piped",
      stderr: "piped",
      signal: controller.signal,
    });

    const child = process.spawn();

    // Stream stdout and stderr concurrently
    const [status] = await Promise.all([
      child.status,
      (async () => {
        try {
          for await (const chunk of child.stdout) {
            const text = new TextDecoder().decode(chunk);
            Deno.stdout.writeSync(new TextEncoder().encode(text));
            output += text;
            if (text.includes("<promise>COMPLETE</promise>")) {
              isComplete = true;
            }
          }
        } catch {
          // Stream closed or cancelled
        }
      })(),
      (async () => {
        try {
          for await (const chunk of child.stderr) {
            const text = new TextDecoder().decode(chunk);
            Deno.stderr.writeSync(new TextEncoder().encode(text));
            output += text;
          }
        } catch {
          // Stream closed or cancelled
        }
      })(),
    ]);

    clearTimeout(timeoutId);

    if (status.code !== 0) {
      console.log(`[${new Date().toISOString()}] ERROR: iteration ${iterationNum} failed with exit code ${status.code}`);
      return false;
    }

    if (isComplete || output.includes("<promise>COMPLETE</promise>")) {
      console.log(`[${new Date().toISOString()}] specification complete after ${iterationNum} iterations.`);
      return true;
    }

    console.log(`[${new Date().toISOString()}] Iteration ${iterationNum} complete.`);
    return null; // Continue to next iteration
  } catch (error) {
    clearTimeout(timeoutId);

    if (error instanceof DOMException && error.name === "AbortError") {
      console.error(`[${new Date().toISOString()}] TIMEOUT: iteration ${iterationNum} exceeded 15 minutes`);
      console.error("specification did not complete - timeout after " + iterationNum + " iterations.");
      return false;
    }

    if (shouldStop) {
      throw error;
    }

    throw error;
  }
}

async function main() {
  for (let i = 1; i <= iterations; i++) {
    if (shouldStop) {
      console.error("Exiting due to signal");
      Deno.exit(130);
    }

    const result = await runIteration(i);

    if (result === true) {
      Deno.exit(0);
    }
  }

  console.log(`[${new Date().toISOString()}] All ${iterations} iterations completed without completion marker.`);
  Deno.exit(1);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  Deno.exit(1);
});
