import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const { searchParams } = req.nextUrl;
  const pipelineId = searchParams.get("pipeline_id");
  const status = searchParams.get("status");
  const page = Math.max(1, parseInt(searchParams.get("page") ?? "1", 10));
  const limit = Math.min(
    100,
    Math.max(1, parseInt(searchParams.get("limit") ?? "25", 10)),
  );
  const offset = (page - 1) * limit;

  let query = db
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
    ])
    .orderBy("r.started_at", "desc");

  if (pipelineId) {
    query = query.where("r.pipeline_id", "=", pipelineId);
  }
  if (status && ["running", "success", "failed"].includes(status)) {
    query = query.where("r.status", "=", status);
  }

  const [runs, countResult] = await Promise.all([
    query.limit(limit).offset(offset).execute(),
    db
      .selectFrom("pipeline_runs")
      .$if(!!pipelineId, (q) => q.where("pipeline_id", "=", pipelineId!))
      .$if(!!status, (q) => q.where("status", "=", status!))
      .select(db.fn.count("id").as("total"))
      .executeTakeFirst(),
  ]);

  return NextResponse.json({
    runs,
    total: Number(countResult?.total ?? 0),
    page,
    limit,
  });
}
