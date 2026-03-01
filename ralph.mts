#!/usr/bin/env -S deno run --allow-run --allow-read --allow-write --allow-env

/**
 * Sample usage:
 * deno run -A ralph.mts --iterations 10 --agent codex
 * deno run -A ralph.mts --iterations 10 --agent claude
 */

import { parseArgs } from "jsr:@std/cli@1/parse-args";

type Agent = (typeof VALID_AGENTS)[number];
type LogLevel = "info" | "error" | "debug";
type Logger = (opts: { tags: [LogLevel, ...string[]]; message: string }) => void;
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

const ok = <T,>(value: T): Result<T, never> => ({ ok: true, value });
const err = <E,>(error: E): Result<never, E> => ({ ok: false, error });

type ValidationResult =
  | { status: "passed" }
  | { status: "failed"; outputPath: string };

type ModelSelection = {
  readonly model: string;
  readonly useStrongModel: boolean;
  readonly targetScenario: number | undefined;
};

type IterationResult =
  | { status: "complete" }
  | { status: "continue" }
  | { status: "failed"; code: number }
  | { status: "timeout" };

type CommandSpec = {
  readonly command: string;
  readonly args: string[];
};

// --- Constants ---

const VALID_AGENTS = ["claude", "codex"] as const;
const TIMEOUT_MS = 60 * 60 * 1000;
const REWORK_THRESHOLD = 1;
const USAGE = "Usage: deno run ralph.mts --iterations <n> [--agent claude|codex]";
const COMPLETION_MARKER = "<promise>COMPLETE</promise>";
const VALIDATE_SCRIPT = "specification.validate.sh";
const VALIDATE_OUTPUT_DIR = ".ralph/validation";
const VALIDATE_TEMPLATE = `#!/usr/bin/env bash
set -euo pipefail

# specification.validate.sh
# Validates that specification requirements are met.
# Fill in your validation logic below.
# Exit 0 on success, non-zero on failure.
# stdout/stderr will be captured and provided to the agent on failure.

echo "TODO: implement validation checks"
exit 1
`;

const BASE_PROMPT = `@specification.md @progress.md
ONLY DO ONE TASK AT A TIME.

1. Read specification.md and progress.md files.
2. Find the next highest leverage uninmplemented scenario and implement it.
3. Document your scenario implementation in docs/scenarios/:name.md. Write maximally concise detail, justifying how the scenario is fully completed. Reference key details & files as evidence for a reviewer.
4. Commit your changes.
5. Update progress.md scenario table with status and add a filename pointing to docs/scenario/* summary. Do NOT fill in rework notes column--leave that for the reviewer.
6. If all scenarios are completed, revisit each claim ONE BY ONE in the progress
file CRITIQUE if the INTENT of the scenario is ACTUALLY COMPLETED. Run code, use browsers, and verify documentation to validate the scearnio.
  6.1 Review if the user's desires are met--not if the claimed tasks are completed.
  6.2 Every referenced document or module should be verified existing and up-to-date.
  6.3 Update status to VERIFIED or NEEDS_REWORK with rework notes as needed.

Once all claims are VERIFIED, output <promise>COMPLETE</promise>.`;

// --- Logger ---

const createLogger = (): Logger => {
  const encoder = new TextEncoder();
  return ({ tags, message }) => {
    const encoded = encoder.encode(`[${tags.join(":")}] ${message}\n`);
    tags[0] === "error"
      ? Deno.stderr.writeSync(encoded)
      : Deno.stdout.writeSync(encoded);
  };
};

// --- Pure Functions ---

const parseCliArgs = (rawArgs: string[]): Result<{ agent: Agent; iterations: number }, string> => {
  const args = parseArgs(rawArgs, {
    string: ["agent", "iterations"],
    alias: { a: "agent", i: "iterations" },
    default: { agent: "claude" },
  });

  const agent = String(args.agent).toLowerCase();
  const iterations = parseInt(String(args.iterations ?? ""), 10);

  return !VALID_AGENTS.includes(agent as Agent) || !iterations || isNaN(iterations) || iterations < 1
    ? err(USAGE)
    : ok({ agent: agent as Agent, iterations });
};

const detectScenarioFromProgress = (content: string): Result<number | undefined, string> => {
  const lines = content.split("\n");
  const endDemoIndex = lines.findIndex((line) => line.includes("END_DEMO"));

  if (endDemoIndex === -1) {
    return err("END_DEMO sigil not found in progress.md");
  }

  const reworkLine = lines
    .slice(endDemoIndex + 1)
    .find((line) => /^\|\s*\d+\s*\|\s*NEEDS_REWORK\s*\|/.test(line));

  if (!reworkLine) return ok(undefined);

  const scenario = parseInt(reworkLine.match(/^\|\s*(\d+)/)?.[1] ?? "", 10);

  return isNaN(scenario)
    ? err(`Failed to parse scenario number from line: ${reworkLine}`)
    : ok(scenario);
};

const getModelDefaults = (agent: Agent): { fast: string; strong: string } =>
  agent === "claude"
    ? {
        fast: Deno.env.get("CLAUDE_FAST_MODEL") ?? "sonnet",
        strong: Deno.env.get("CLAUDE_STRONG_MODEL") ?? "opus",
      }
    : {
        fast: Deno.env.get("CODEX_FAST_MODEL") ?? "gpt-5.1-codex-max",
        strong: Deno.env.get("CODEX_STRONG_MODEL") ?? "gpt-5.3-codex",
      };

const computeModelSelection = (content: string, agent: Agent): Result<ModelSelection, string> => {
  const reworkCount = (content.match(/NEEDS_REWORK/g) ?? []).length;
  const scenarioResult = detectScenarioFromProgress(content);

  if (!scenarioResult.ok) return scenarioResult;

  const useStrongModel = reworkCount > REWORK_THRESHOLD;
  const models = getModelDefaults(agent);

  return ok({
    model: useStrongModel ? models.strong : models.fast,
    useStrongModel,
    targetScenario: scenarioResult.value,
  });
};

const buildPrompt = ({ targetScenario, useStrongModel, validationFailurePath }: {
  targetScenario: number | undefined;
  useStrongModel: boolean;
  validationFailurePath: string | undefined;
}): string => {
  const base = !useStrongModel || targetScenario === undefined
    ? BASE_PROMPT
    : `${BASE_PROMPT}

ACTUALLY:
- You must work ONLY on scenario ${targetScenario}.
- Do not work on any other scenario in this iteration.`;

  return validationFailurePath === undefined
    ? base
    : `${base}

VALIDATION FAILED on previous iteration. Review the failure output at: ${validationFailurePath}
Fix the issues identified in the validation output before proceeding with other work.`;
};

const buildCommandSpec = ({ agent, model, prompt }: {
  agent: Agent;
  model: string;
  prompt: string;
}): CommandSpec =>
  agent === "claude"
    ? {
        command: "claude",
        args: ["--dangerously-skip-permissions", "--model", model,
          //  "-p",
           prompt],
      }
    : {
        command: "codex",
        args: ["exec", "--dangerously-bypass-approvals-and-sandbox", "--model", model, prompt],
      };

// --- IO Functions ---

const pipeStream = async ({ stream, output, marker }: {
  stream: ReadableStream<Uint8Array>;
  output: { write: (data: Uint8Array) => Promise<number> };
  marker?: string;
}): Promise<boolean> => {
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();
  let found = false;
  try {
    for await (const chunk of stream) {
      const text = decoder.decode(chunk);
      await output.write(encoder.encode(text));
      if (marker && text.includes(marker)) found = true;
    }
  } catch {
    // Stream closed or aborted
  }
  return found;
};

const resolveModelSelection = async (agent: Agent, log: Logger): Promise<ModelSelection> => {
  const defaults: ModelSelection = {
    model: getModelDefaults(agent).fast,
    useStrongModel: false,
    targetScenario: undefined,
  };

  const content = await Deno.readTextFile("progress.md").catch(() => undefined);
  if (!content) return defaults;

  const result = computeModelSelection(content, agent);
  if (!result.ok) {
    log({ tags: ["error", "model"], message: result.error });
    return defaults;
  }

  const { model, useStrongModel, targetScenario } = result.value;
  const reworkCount = (content.match(/NEEDS_REWORK/g) ?? []).length;
  log({ tags: ["info", "model"], message: `${reworkCount} NEEDS_REWORK entries → using ${model}` });

  if (useStrongModel && targetScenario !== undefined) {
    log({ tags: ["info", "scenario"], message: `strong-model pass scoped to scenario ${targetScenario}` });
  }

  return result.value;
};

const ensureValidationHook = async (log: Logger): Promise<Result<void, string>> => {
  const exists = await Deno.stat(VALIDATE_SCRIPT).then(() => true, () => false);
  if (exists) return ok(undefined);

  await Deno.writeTextFile(VALIDATE_SCRIPT, VALIDATE_TEMPLATE);
  await Deno.chmod(VALIDATE_SCRIPT, 0o755);
  log({ tags: ["info", "hook"], message: `Created ${VALIDATE_SCRIPT}. Fill in your validation logic and re-run.` });
  return err(`${VALIDATE_SCRIPT} created — fill in validation logic before re-running.`);
};

const runValidation = async ({ iterationNum, log }: {
  iterationNum: number;
  log: Logger;
}): Promise<ValidationResult> => {
  await Deno.mkdir(VALIDATE_OUTPUT_DIR, { recursive: true });
  const outputPath = `${VALIDATE_OUTPUT_DIR}/iteration-${iterationNum}.log`;
  const decoder = new TextDecoder();

  const output = await new Deno.Command("bash", {
    args: [VALIDATE_SCRIPT],
    stdout: "piped",
    stderr: "piped",
  }).output();

  const content = [
    "--- stdout ---",
    decoder.decode(output.stdout),
    "--- stderr ---",
    decoder.decode(output.stderr),
    `--- exit code: ${output.code} ---`,
  ].join("\n");
  await Deno.writeTextFile(outputPath, content);

  return output.code === 0
    ? (log({ tags: ["info", "validate"], message: `Validation passed (iteration ${iterationNum})` }),
       { status: "passed" })
    : (log({ tags: ["error", "validate"], message: `Validation failed (iteration ${iterationNum}), see ${outputPath}` }),
       { status: "failed", outputPath });
};

const runIteration = async ({ iterationNum, agent, signal, log, validationFailurePath }: {
  iterationNum: number;
  agent: Agent;
  signal: AbortSignal;
  log: Logger;
  validationFailurePath: string | undefined;
}): Promise<IterationResult> => {
  const { model, useStrongModel, targetScenario } = await resolveModelSelection(agent, log);
  const prompt = buildPrompt({ targetScenario, useStrongModel, validationFailurePath });
  const spec = buildCommandSpec({ agent, model, prompt });

  log({ tags: ["info"], message: `Starting iteration ${iterationNum} (${model})...` });

  const combinedSignal = AbortSignal.any([signal, AbortSignal.timeout(TIMEOUT_MS)]);

  try {
    const child = new Deno.Command(spec.command, {
      args: spec.args,
      stdin: "null",
      stdout: "piped",
      stderr: "piped",
      signal: combinedSignal,
    }).spawn();

    const [status, foundComplete] = await Promise.all([
      child.status,
      pipeStream({ stream: child.stdout, output: Deno.stdout, marker: COMPLETION_MARKER }),
      pipeStream({ stream: child.stderr, output: Deno.stderr }),
    ]);

    return status.code !== 0
      ? (log({ tags: ["error"], message: `iteration ${iterationNum} failed with exit code ${status.code}` }),
         { status: "failed", code: status.code })
      : foundComplete
        ? (log({ tags: ["info"], message: `specification complete after ${iterationNum} iterations.` }),
           { status: "complete" })
        : (log({ tags: ["info"], message: `Iteration ${iterationNum} complete.` }),
           { status: "continue" });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      log({ tags: ["error"], message: `TIMEOUT: iteration ${iterationNum} exceeded 60 minutes` });
      return { status: "timeout" };
    }

    throw error;
  }
};

// --- Main ---

const main = async (): Promise<void> => {
  const log = createLogger();
  const parsed = parseCliArgs(Deno.args);

  if (!parsed.ok) {
    log({ tags: ["error"], message: parsed.error });
    Deno.exit(1);
  }

  const { agent, iterations } = parsed.value;
  log({ tags: ["info"], message: `Starting ralph loop for ${iterations} iterations with ${agent}...` });

  const shutdownController = new AbortController();
  let interrupted = false;
  Deno.addSignalListener("SIGINT", () => {
    if (interrupted) Deno.exit(130);
    interrupted = true;
    log({ tags: ["error"], message: "Interrupted (ctrl+c again to force exit)" });
    shutdownController.abort();
    setTimeout(() => Deno.exit(130), 3_000);
  });

  const hookResult = await ensureValidationHook(log);
  if (!hookResult.ok) {
    log({ tags: ["error"], message: hookResult.error });
    Deno.exit(1);
  }

  let validationFailurePath: string | undefined;

  for (let i = 1; i <= iterations; i++) {
    if (shutdownController.signal.aborted) {
      log({ tags: ["error"], message: "Exiting due to signal" });
      Deno.exit(130);
    }

    const result = await runIteration({
      iterationNum: i,
      agent,
      signal: shutdownController.signal,
      log,
      validationFailurePath,
    });

    // On error/timeout, clear validation state and continue
    if (result.status === "failed" || result.status === "timeout") {
      validationFailurePath = undefined;
      continue;
    }

    // Run validation after successful agent iteration
    const validation = await runValidation({ iterationNum: i, log });
    validationFailurePath = validation.status === "failed"
      ? validation.outputPath
      : undefined;

    // Only accept completion if validation also passes
    if (result.status === "complete" && validation.status === "passed") return;
  }

  log({ tags: ["info"], message: `All ${iterations} iterations completed without completion marker.` });
};

main().catch((error) => {
  const log = createLogger();
  log({ tags: ["error"], message: `Fatal error: ${error}` });
  Deno.exit(1);
});
