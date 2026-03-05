import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { triggerPipeline } from "@/lib/trigger-pipeline";

export const dynamic = "force-dynamic";

/**
 * POST /api/webhooks/gitea
 *
 * Receives Gitea push webhook events. Parses the repo/branch from the
 * payload, looks up matching gitea_connections, and triggers linked pipelines.
 *
 * Gitea push event payload:
 *   { ref: "refs/heads/main", repository: { full_name: "owner/repo" } }
 */
export async function POST(req: Request) {
  const payload = await req.json();

  const ref: string = payload.ref ?? "";
  const branch = ref.replace("refs/heads/", "");
  const fullName: string = payload.repository?.full_name ?? "";

  if (!branch || !fullName) {
    return NextResponse.json(
      { error: "Missing ref or repository.full_name" },
      { status: 400 },
    );
  }

  const connections = await db
    .selectFrom("gitea_connections")
    .select(["id", "pipeline_id"])
    .where("repo", "=", fullName)
    .where("branch", "=", branch)
    .where("pipeline_id", "is not", null)
    .execute();

  const runIds: string[] = [];
  const errors: string[] = [];
  for (const conn of connections) {
    if (conn.pipeline_id) {
      try {
        const runId = await triggerPipeline(conn.pipeline_id, "webhook");
        if (runId) runIds.push(runId);
      } catch (err) {
        errors.push(err instanceof Error ? err.message : String(err));
      }
    }
  }

  return NextResponse.json({
    ok: errors.length === 0,
    triggered: runIds.length,
    run_ids: runIds,
    ...(errors.length > 0 ? { errors } : {}),
  });
}
