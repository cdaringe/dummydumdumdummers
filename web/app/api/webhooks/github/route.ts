import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { triggerPipeline } from "@/lib/trigger-pipeline";

export const dynamic = "force-dynamic";

/**
 * POST /api/webhooks/github
 *
 * Receives GitHub push webhook events. Parses the repo/branch from the
 * payload, looks up matching github_connections, and triggers linked pipelines.
 *
 * GitHub push event payload:
 *   { ref: "refs/heads/main", repository: { name: "repo", owner: { login: "org" } } }
 */
export async function POST(req: Request) {
  const payload = await req.json();

  const ref: string = payload.ref ?? "";
  const branch = ref.replace("refs/heads/", "");
  const repo: string = payload.repository?.name ?? "";
  const org: string = payload.repository?.owner?.login ?? "";

  if (!branch || !repo || !org) {
    return NextResponse.json(
      { error: "Missing ref, repository.name, or repository.owner.login" },
      { status: 400 },
    );
  }

  const connections = await db
    .selectFrom("github_connections")
    .select(["id", "pipeline_id"])
    .where("org", "=", org)
    .where("repo", "=", repo)
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
