import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { RunDetailClient } from "@/components/run/RunDetailClient";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ runId: string }> };

async function getRunDetail(runId: string) {
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
      "p.name as pipeline_name",
      "p.version as pipeline_version",
      "p.steps as pipeline_steps",
    ])
    .where("r.id", "=", runId)
    .executeTakeFirst();

  if (!run) return null;

  const stepTraces = await db
    .selectFrom("step_traces")
    .selectAll()
    .where("run_id", "=", runId)
    .orderBy("sequence", "asc")
    .execute();

  return { run, stepTraces };
}

export default async function RunDetailPage({ params }: Props) {
  const { runId } = await params;
  const data = await getRunDetail(runId);

  if (!data) notFound();

  return (
    <RunDetailClient
      run={data.run as any}
      initialTraces={data.stepTraces as any}
    />
  );
}
