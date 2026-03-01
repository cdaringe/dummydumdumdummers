#!/usr/bin/env -S deno run --allow-run --allow-read --allow-write --allow-env

/**
 * Sample usage:
 * deno run -A ralph.mts --iterations 10 --agent codex
 * deno run -A ralph.mts --iterations 10 --agent claude
 */

import { parse } from "https://deno.land/std@0.208.0/flags/mod.ts";

const args = parse(Deno.args, {
  string: ["agent", "iterations"],
  alias: {
    a: "agent",
    i: "iterations",
  },
  default: {
    agent: "claude",
  },
});

const iterationsRaw = args.iterations;
const iterations = parseInt(String(iterationsRaw ?? ""), 10);
const agent = String(args.agent).toLowerCase();

if (agent !== "claude" && agent !== "codex") {
  console.error("Usage: deno run ralph.mts --iterations <n> [--agent claude|codex]");
  Deno.exit(1);
}

if (!iterationsRaw || !iterations || isNaN(iterations) || iterations < 1) {
  console.error("Usage: deno run ralph.mts --iterations <n> [--agent claude|codex]");
  Deno.exit(1);
}

console.log(`Starting ralph loop for ${iterations} iterations with ${agent}...`);

let shouldStop = false;

// Handle Ctrl+C gracefully
Deno.addSignalListener("SIGINT", () => {
  console.error("\n[$(date)] Interrupted");
  shouldStop = true;
});

const BASE_PROMPT = `@specification.md @progress.md
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

const TIMEOUT_MS = 60 * 60 * 1000; // 60 minutes
const REWORK_THRESHOLD = 1;

function detectScenarioFromProgress(content: string): number | null {
  const lines = content.split("\n");
  let endDemoSigilSeen = false;
  let count = 0;
  for (const line of lines) {
    if (line.includes("END_DEMO")) {
      endDemoSigilSeen = true;
      continue;
    }
    const match = line.match(/^\|\s*(\d+)\s*\|\s*NEEDS_REWORK\s*\|/);
    if (match && endDemoSigilSeen) {
      const scenario = parseInt(match[1], 10);
      if (isNaN(scenario)) {
        throw new Error(`Failed to parse scenario number from progress.md line: ${line}`);
      }
      return scenario;
    }
    ++count;
  }
  if (!endDemoSigilSeen) throw new Error("END_DEMO sigil not found in progress.md");
  return null;
}

function buildPrompt(targetScenario: number | null, useStrongModel: boolean): string {
  if (!useStrongModel || targetScenario === null) {
    return BASE_PROMPT;
  }

  return `${BASE_PROMPT}

ACTUALLY:
- You must work ONLY on scenario ${targetScenario}.
- Do not work on any other scenario in this iteration.`;
}

async function pickModel(): Promise<{ model: string; useStrongModel: boolean; targetScenario: number | null }> {
  const fastModel = agent === "claude"
    ? Deno.env.get("CLAUDE_FAST_MODEL") ?? "sonnet"
    : Deno.env.get("CODEX_FAST_MODEL") ?? "gpt-5.1-codex-max";
  const strongModel = agent === "claude"
    ? Deno.env.get("CLAUDE_STRONG_MODEL") ?? "opus"
    : Deno.env.get("CODEX_STRONG_MODEL") ?? "gpt-5.3-codex";

  let reworkCount = 0;
  let targetScenario: number | null = null;

  try {
    const content = await Deno.readTextFile("progress.md");
    reworkCount = (content.match(/NEEDS_REWORK/g) || []).length;
    targetScenario = detectScenarioFromProgress(content);
  } catch {
    // Fall through to model defaults when progress.md can't be read.
  }

  const useStrongModel = reworkCount > REWORK_THRESHOLD;
  const model = useStrongModel ? strongModel : fastModel;
  console.log(`[model] ${reworkCount} NEEDS_REWORK entries → using ${model}`);
  if (useStrongModel && targetScenario !== null) {
    console.log(`[scenario] strong-model pass scoped to scenario ${targetScenario}`);
  }

  return { model, useStrongModel, targetScenario };
}

async function runIteration(iterationNum: number): Promise<boolean> {
  const { model, useStrongModel, targetScenario } = await pickModel();
  const prompt = buildPrompt(targetScenario, useStrongModel);
  console.log(`[${new Date().toISOString()}] Starting iteration ${iterationNum}${model ? ` (${model})` : ""}...`);

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    let isComplete = false;

    const command = agent === "claude" ? "claude" : "codex";
    const commandArgs = agent === "claude"
      ? [
        "--dangerously-skip-permissions",
        ...(model ? ["--model", model] : []),
        "-p",
        prompt,
      ]
      : [
        "exec",
        "--dangerously-bypass-approvals-and-sandbox",
        ...(model ? ["--model", model] : []),
        prompt,
      ];

    const process = new Deno.Command(command, {
      args: commandArgs,
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
            await Deno.stdout.write(new TextEncoder().encode(text));
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
            await Deno.stderr.write(new TextEncoder().encode(text));
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

    if (isComplete) {
      console.log(`[${new Date().toISOString()}] specification complete after ${iterationNum} iterations.`);
      return true;
    }

    console.log(`[${new Date().toISOString()}] Iteration ${iterationNum} complete.`);
    return false;
  } catch (error) {
    clearTimeout(timeoutId);

    if (error instanceof DOMException && error.name === "AbortError") {
      console.error(`[${new Date().toISOString()}] TIMEOUT: iteration ${iterationNum} exceeded 60 minutes`);
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
      return
    }
  }

  console.log(`[${new Date().toISOString()}] All ${iterations} iterations completed without completion marker.`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  Deno.exit(1);
});
