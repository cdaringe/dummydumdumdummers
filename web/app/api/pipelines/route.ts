import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import type {
  ScheduleConfig,
  StepDefinition,
  TriggerConfig,
} from "@/lib/types";

export const dynamic = "force-dynamic";

export async function GET() {
  const pipelines = await db
    .selectFrom("pipeline_definitions")
    .selectAll()
    .orderBy("name")
    .execute() as any[];

  // Get the latest run for each pipeline
  const runs = await db
    .selectFrom("pipeline_runs")
    .selectAll()
    .orderBy("started_at", "desc")
    .execute() as any[];

  const latestRunsByPipeline = new Map<string, any>();
  for (const run of runs) {
    if (!latestRunsByPipeline.has(run.pipeline_id)) {
      latestRunsByPipeline.set(run.pipeline_id, run);
    }
  }

  const result = pipelines.map((p: any) => {
    const lastRun = latestRunsByPipeline.get(p.id);
    return {
      id: p.id,
      name: p.name,
      version: p.version,
      description: p.description,
      schedule: JSON.parse(p.schedule) as ScheduleConfig,
      trigger: JSON.parse(p.trigger) as TriggerConfig,
      steps: JSON.parse(p.steps) as StepDefinition[],
      timeout_ms: p.timeout_ms,
      created_at: p.created_at,
      last_run: lastRun
        ? {
          id: lastRun.id,
          status: lastRun.status,
          started_at: lastRun.started_at,
          duration_ms: lastRun.duration_ms,
        }
        : null,
    };
  });

  return NextResponse.json(result);
}
