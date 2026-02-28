import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import type { StepDefinition, ScheduleConfig, TriggerConfig } from "@/lib/types";

type Params = { params: Promise<{ runId: string }> };

export async function GET(_req: Request, { params }: Params) {
  const { runId } = await params;

  const run = await db
    .selectFrom("pipeline_runs as r")
    .innerJoin("pipeline_definitions as p", "p.id", "r.pipeline_id")
    .select([
      "r.id",
      "r.pipeline_id",
      "r.status",
      "r.trigger_type",
      "r.started_at",
      "r.finished_at",
      "r.duration_ms",
      "r.created_at",
      "p.id as p_id",
      "p.name as p_name",
      "p.version as p_version",
      "p.description as p_description",
      "p.schedule as p_schedule",
      "p.trigger as p_trigger",
      "p.steps as p_steps",
      "p.timeout_ms as p_timeout_ms",
      "p.created_at as p_created_at",
    ])
    .where("r.id", "=", runId)
    .executeTakeFirst();

  if (!run) {
    return NextResponse.json({ error: "Run not found" }, { status: 404 });
  }

  const stepTraces = await db
    .selectFrom("step_traces")
    .selectAll()
    .where("run_id", "=", runId)
    .orderBy("sequence", "asc")
    .execute();

  return NextResponse.json({
    id: run.id,
    pipeline_id: run.pipeline_id,
    status: run.status,
    trigger_type: run.trigger_type,
    started_at: run.started_at,
    finished_at: run.finished_at,
    duration_ms: run.duration_ms,
    created_at: run.created_at,
    pipeline: {
      id: run.p_id,
      name: run.p_name,
      version: run.p_version,
      description: run.p_description,
      schedule: JSON.parse(run.p_schedule) as ScheduleConfig,
      trigger: JSON.parse(run.p_trigger) as TriggerConfig,
      steps: JSON.parse(run.p_steps) as StepDefinition[],
      timeout_ms: run.p_timeout_ms,
      created_at: run.p_created_at,
    },
    step_traces: stepTraces,
  });
}
