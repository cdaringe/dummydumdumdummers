import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { randomUUID } from "crypto";

export const dynamic = "force-dynamic";

export async function GET() {
  const connections = await db
    .selectFrom("github_connections")
    .select(["id", "org", "repo", "branch", "pipeline_id", "created_at"])
    .orderBy("created_at", "desc")
    .execute();

  return NextResponse.json(connections);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { token, org, repo, branch, pipeline_id } = body;

  if (!token || !org || !repo || !branch) {
    return NextResponse.json(
      { error: "token, org, repo, and branch are required" },
      { status: 400 },
    );
  }

  const id = randomUUID();

  await db
    .insertInto("github_connections")
    .values({
      id,
      token,
      org,
      repo,
      branch,
      pipeline_id: pipeline_id ?? null,
    })
    .execute();

  // Update the linked pipeline's trigger to GitHub if pipeline_id is provided
  if (pipeline_id) {
    const trigger = JSON.stringify({
      GitHub: { repo: `${org}/${repo}`, events: ["push"] },
    });
    await db
      .updateTable("pipeline_definitions")
      .set({ trigger })
      .where("id", "=", pipeline_id)
      .execute();
  }

  return NextResponse.json({ id }, { status: 201 });
}
