import { spawn } from "child_process";
import { db } from "./db";
import { config } from "./config";
import { v4 as uuidv4 } from "uuid";
import { type RunEvent, runEvents } from "./run-events";
import type {
  StepDefinition,
  ExecutorConfig,
  DockerExecutorConfig,
} from "./types";

// ---------------------------------------------------------------------------
// Simulated step log (backwards-compat for steps without a command)
// ---------------------------------------------------------------------------

function generateStepLog({
  stepName,
  status,
  durationMs,
}: {
  stepName: string;
  status: string;
  durationMs: number;
}): string {
  const ts = () => new Date().toISOString().replace("T", " ").substring(0, 19);
  const lines = [
    `[${ts()}] Starting step: ${stepName}`,
    `[${ts()}] Working directory: /workspace/pipeline`,
    `$ executing ${stepName}...`,
    `Processing...`,
    ...(durationMs > 1500 ? [`Intermediate progress: 50% complete`] : []),
    status === "failed"
      ? `[ERROR] Step failed with exit code 1`
      : `[${ts()}] Step ${stepName} completed successfully (${durationMs}ms)`,
  ];
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Command execution result
// ---------------------------------------------------------------------------

interface CommandResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
}

// ---------------------------------------------------------------------------
// Shared spawn-and-collect helper
// ---------------------------------------------------------------------------

interface SpawnInput {
  bin: string;
  args: string[];
  cwd?: string;
  timeoutMs: number;
}

function spawnAndCollect({ bin, args, cwd, timeoutMs }: SpawnInput): Promise<CommandResult> {
  return new Promise((resolve) => {
    const start = Date.now();
    let stdout = "";
    let stderr = "";
    let settled = false;

    const child = spawn(bin, args, {
      cwd,
      env: { ...process.env },
      stdio: ["ignore", "pipe", "pipe"],
    });

    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    const settle = (result: CommandResult): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };

    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      settle({
        exitCode: 124,
        stdout,
        stderr: stderr + "\n[TIMEOUT] Step exceeded timeout",
        durationMs: Date.now() - start,
      });
    }, timeoutMs);

    child.on("close", (code) => {
      settle({
        exitCode: code ?? 1,
        stdout,
        stderr,
        durationMs: Date.now() - start,
      });
    });

    child.on("error", (err) => {
      settle({
        exitCode: 127,
        stdout,
        stderr: stderr + "\n" + err.message,
        durationMs: Date.now() - start,
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Local executor — runs command via sh -c
// ---------------------------------------------------------------------------

interface ExecInput {
  command: string;
  workingDir: string;
  timeoutMs: number;
}

function executeLocal({ command, workingDir, timeoutMs }: ExecInput): Promise<CommandResult> {
  return spawnAndCollect({
    bin: "sh",
    args: ["-c", command],
    cwd: workingDir,
    timeoutMs,
  });
}

// ---------------------------------------------------------------------------
// Docker executor — runs command inside a docker container
// ---------------------------------------------------------------------------

function buildDockerArgs({
  command,
  workingDir,
  dockerCfg,
}: {
  command: string;
  workingDir: string;
  dockerCfg: DockerExecutorConfig;
}): string[] {
  const volumeArgs = (dockerCfg.volumes ?? []).flatMap((v) => ["-v", v]);
  return [
    "run",
    "--rm",
    "-v",
    `${workingDir}:/workspace`,
    "-w",
    "/workspace",
    ...volumeArgs,
    dockerCfg.image,
    "sh",
    "-c",
    command,
  ];
}

function executeDocker({
  command,
  workingDir,
  timeoutMs,
  dockerCfg,
}: ExecInput & { dockerCfg: DockerExecutorConfig }): Promise<CommandResult> {
  return spawnAndCollect({
    bin: "docker",
    args: buildDockerArgs({ command, workingDir, dockerCfg }),
    timeoutMs,
  });
}

// ---------------------------------------------------------------------------
// Dispatch to the correct executor
// ---------------------------------------------------------------------------

function executeCommand(
  input: ExecInput,
  executor: ExecutorConfig,
): Promise<CommandResult> {
  switch (executor.kind) {
    case "docker":
      return executeDocker({ ...input, dockerCfg: executor });
    case "local":
      return executeLocal(input);
    default: {
      const _exhaustive: never = executor;
      return executeLocal(input);
    }
  }
}

// ---------------------------------------------------------------------------
// Wait for all other runs to finish before proceeding
// ---------------------------------------------------------------------------

async function waitForIdle(currentRunId: string): Promise<void> {
  const pollIntervalMs = 3000;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const row = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.count<number>("id").as("cnt"))
      .where("status", "=", "running")
      .where("id", "!=", currentRunId)
      .executeTakeFirst();
    if ((row?.cnt ?? 0) === 0) return;
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }
}

// ---------------------------------------------------------------------------
// Mark a run as finished (success or failure)
// ---------------------------------------------------------------------------

async function finalizeRun({
  runId,
  status,
  startTime,
}: {
  runId: string;
  status: "success" | "failed";
  startTime: number;
}): Promise<void> {
  const totalDuration = Date.now() - startTime;
  const finishedAt = new Date().toISOString();

  await db
    .updateTable("pipeline_runs")
    .set({ status, finished_at: finishedAt, duration_ms: totalDuration })
    .where("id", "=", runId)
    .execute();

  const runEvt: RunEvent = {
    type: "run_completed",
    status,
    duration_ms: totalDuration,
    finished_at: finishedAt,
  };
  runEvents.emit(`run:${runId}`, runEvt);
}

// ---------------------------------------------------------------------------
// Background step execution
// ---------------------------------------------------------------------------

async function executeStepsInBackground({
  runId,
  steps,
  executor,
}: {
  runId: string;
  steps: StepDefinition[];
  executor: ExecutorConfig;
}): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 500));

  const startTime = Date.now();

  try {
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i]!;
      const traceId = uuidv4();

      // Check only_if_env — skip step if env var is not truthy
      if (step.only_if_env && !process.env[step.only_if_env]) {
        const logOutput = `[SKIPPED] Environment variable ${step.only_if_env} is not set`;
        await db
          .insertInto("step_traces")
          .values({
            id: traceId,
            run_id: runId,
            step_name: step.name,
            status: "skipped",
            duration_ms: 0,
            error_msg: null,
            log_output: logOutput,
            sequence: i,
          })
          .execute();

        const skipEvt: RunEvent = {
          type: "step_completed",
          step_name: step.name,
          sequence: i,
          status: "skipped",
          duration_ms: 0,
          log_output: logOutput,
        };
        runEvents.emit(`run:${runId}`, skipEvt);
        continue;
      }

      // Wait for other runs to finish if requested
      if (step.wait_for_idle) {
        await waitForIdle(runId);
      }

      await db
        .insertInto("step_traces")
        .values({
          id: traceId,
          run_id: runId,
          step_name: step.name,
          status: "running",
          duration_ms: 0,
          error_msg: null,
          log_output: null,
          sequence: i,
        })
        .execute();

      const startEvt: RunEvent = {
        type: "step_started",
        step_name: step.name,
        sequence: i,
      };
      runEvents.emit(`run:${runId}`, startEvt);

      if (step.command) {
        // Real command execution via configured executor
        const workingDir = step.working_dir || process.cwd();

        const result = await executeCommand(
          { command: step.command, workingDir, timeoutMs: step.timeout_ms },
          executor,
        );

        const ts = new Date()
          .toISOString()
          .replace("T", " ")
          .substring(0, 19);
        const logLines = [
          `[${ts}] Starting step: ${step.name}`,
          `[${ts}] Executor: ${executor.kind}`,
          `[${ts}] Working directory: ${workingDir}`,
          `$ ${step.command}`,
          result.stdout,
          ...(result.stderr ? [`[stderr] ${result.stderr}`] : []),
          result.exitCode === 0
            ? `[${ts}] Step ${step.name} completed successfully (${result.durationMs}ms)`
            : `[ERROR] Step failed with exit code ${result.exitCode}`,
        ];
        const logOutput = logLines.join("\n");
        const status = result.exitCode === 0 ? "ok" : "failed";

        await db
          .updateTable("step_traces")
          .set({
            status,
            duration_ms: result.durationMs,
            log_output: logOutput,
            error_msg:
              result.exitCode !== 0
                ? `Exit code ${result.exitCode}`
                : null,
          })
          .where("id", "=", traceId)
          .execute();

        const completeEvt: RunEvent = {
          type: "step_completed",
          step_name: step.name,
          sequence: i,
          status,
          duration_ms: result.durationMs,
          log_output: logOutput,
        };
        runEvents.emit(`run:${runId}`, completeEvt);

        if (result.exitCode !== 0) {
          await finalizeRun({ runId, status: "failed", startTime });
          return;
        }
      } else {
        // Simulation path (backwards compatible)
        const execTime = 1500 + Math.round(Math.random() * 2000);
        await new Promise((resolve) => setTimeout(resolve, execTime));

        const logOutput = generateStepLog({ stepName: step.name, status: "ok", durationMs: execTime });
        await db
          .updateTable("step_traces")
          .set({
            status: "ok",
            duration_ms: execTime,
            log_output: logOutput,
          })
          .where("id", "=", traceId)
          .execute();

        const completeEvt: RunEvent = {
          type: "step_completed",
          step_name: step.name,
          sequence: i,
          status: "ok",
          duration_ms: execTime,
          log_output: logOutput,
        };
        runEvents.emit(`run:${runId}`, completeEvt);
      }
    }

    await finalizeRun({ runId, status: "success", startTime });
  } catch {
    await finalizeRun({ runId, status: "failed", startTime });
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Trigger a pipeline by ID. Creates a new run and starts background execution.
 * Returns the new runId, or null if the pipeline was not found.
 * Rejects if the pipeline's executor kind is not in the allowed list.
 */
export async function triggerPipeline(
  pipelineId: string,
  triggerType: string,
): Promise<string | null> {
  const pipeline = await db
    .selectFrom("pipeline_definitions")
    .select(["id", "steps", "executor"])
    .where("id", "=", pipelineId)
    .executeTakeFirst();

  if (!pipeline) return null;

  const steps = JSON.parse(pipeline.steps) as StepDefinition[];
  const executor: ExecutorConfig = JSON.parse(
    pipeline.executor ?? '{"kind":"local"}',
  );

  // Enforce allowlist
  if (!config.allowedExecutors.includes(executor.kind)) {
    throw new Error(
      `Executor kind "${executor.kind}" is not permitted. Allowed: ${config.allowedExecutors.join(", ")}`,
    );
  }

  const runId = uuidv4();

  await db
    .insertInto("pipeline_runs")
    .values({
      id: runId,
      pipeline_id: pipelineId,
      status: "running",
      trigger_type: triggerType,
      started_at: new Date().toISOString(),
    })
    .execute();

  void executeStepsInBackground({ runId, steps, executor });

  return runId;
}
