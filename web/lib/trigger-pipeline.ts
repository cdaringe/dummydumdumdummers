import { db } from "./db";
import { v4 as uuidv4 } from "uuid";
import { type RunEvent, runEvents } from "./run-events";
import type { StepDefinition } from "./types";

function generateStepLog(
  stepName: string,
  status: string,
  durationMs: number,
): string {
  const ts = () => new Date().toISOString().replace("T", " ").substring(0, 19);
  const lines: string[] = [];
  lines.push(`[${ts()}] Starting step: ${stepName}`);
  lines.push(`[${ts()}] Working directory: /workspace/pipeline`);
  lines.push(`$ executing ${stepName}...`);
  lines.push(`Processing...`);
  if (durationMs > 1500) {
    lines.push(`Intermediate progress: 50% complete`);
  }
  if (status === "failed") {
    lines.push(`[ERROR] Step failed with exit code 1`);
  } else {
    lines.push(
      `[${ts()}] Step ${stepName} completed successfully (${durationMs}ms)`,
    );
  }
  return lines.join("\n");
}

async function executeStepsInBackground(
  runId: string,
  steps: StepDefinition[],
): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 500));

  const startTime = Date.now();

  for (let i = 0; i < steps.length; i++) {
    const step = steps[i]!;
    const traceId = uuidv4();

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

    const execTime = 1500 + Math.round(Math.random() * 2000);
    await new Promise((resolve) => setTimeout(resolve, execTime));

    const logOutput = generateStepLog(step.name, "ok", execTime);
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

  const totalDuration = Date.now() - startTime;
  const finishedAt = new Date().toISOString();

  await db
    .updateTable("pipeline_runs")
    .set({
      status: "success",
      finished_at: finishedAt,
      duration_ms: totalDuration,
    })
    .where("id", "=", runId)
    .execute();

  const runEvt: RunEvent = {
    type: "run_completed",
    status: "success",
    duration_ms: totalDuration,
    finished_at: finishedAt,
  };
  runEvents.emit(`run:${runId}`, runEvt);
}

/**
 * Trigger a pipeline by ID. Creates a new run and starts background execution.
 * Returns the new runId, or null if the pipeline was not found.
 */
export async function triggerPipeline(
  pipelineId: string,
  triggerType: string,
): Promise<string | null> {
  const pipeline = await db
    .selectFrom("pipeline_definitions")
    .select(["id", "steps"])
    .where("id", "=", pipelineId)
    .executeTakeFirst();

  if (!pipeline) return null;

  const steps = JSON.parse(pipeline.steps) as StepDefinition[];
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

  void executeStepsInBackground(runId, steps);

  return runId;
}
