import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import type { StepDefinition, ScheduleConfig, TriggerConfig } from "@/lib/types";

type Params = { params: Promise<{ name: string; version: string }> };

export async function GET(_req: Request, { params }: Params) {
  const { name, version } = await params;
  const pipelineId = `${name}@${version}`;

  const pipeline = await db
    .selectFrom("pipeline_definitions")
    .selectAll()
    .where("id", "=", pipelineId)
    .executeTakeFirst();

  if (!pipeline) {
    return NextResponse.json({ error: "Pipeline not found" }, { status: 404 });
  }

  const recentRuns = await db
    .selectFrom("pipeline_runs")
    .selectAll()
    .where("pipeline_id", "=", pipelineId)
    .orderBy("started_at", "desc")
    .limit(20)
    .execute();

  return NextResponse.json({
    id: pipeline.id,
    name: pipeline.name,
    version: pipeline.version,
    description: pipeline.description,
    schedule: JSON.parse(pipeline.schedule) as ScheduleConfig,
    trigger: JSON.parse(pipeline.trigger) as TriggerConfig,
    steps: JSON.parse(pipeline.steps) as StepDefinition[],
    timeout_ms: pipeline.timeout_ms,
    created_at: pipeline.created_at,
    recent_runs: recentRuns,
  });
}
