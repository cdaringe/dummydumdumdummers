import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { randomUUID } from "crypto";

export const dynamic = "force-dynamic";

export async function GET() {
  const connections = await db
    .selectFrom("gitea_connections")
    .select(["id", "url", "repo", "branch", "pipeline_id", "created_at"])
    .orderBy("created_at", "desc")
    .execute();

  return NextResponse.json(connections);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { url, token, repo, branch, pipeline_id } = body;

  if (!url || !token || !repo || !branch) {
    return NextResponse.json(
      { error: "url, token, repo, and branch are required" },
      { status: 400 },
    );
  }

  const id = randomUUID();

  await db
    .insertInto("gitea_connections")
    .values({
      id,
      url,
      token,
      repo,
      branch,
      pipeline_id: pipeline_id ?? null,
    })
    .execute();

  if (pipeline_id) {
    const trigger = JSON.stringify({
      Gitea: { repo, events: ["push"] },
    });
    await db
      .updateTable("pipeline_definitions")
      .set({ trigger })
      .where("id", "=", pipeline_id)
      .execute();
  }

  return NextResponse.json({ id }, { status: 201 });
}
