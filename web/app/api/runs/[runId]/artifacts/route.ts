import { db } from "@/lib/db";
import { NextRequest, NextResponse } from "next/server";

type Props = { params: Promise<{ runId: string }> };

export async function GET(req: NextRequest, { params }: Props) {
  const { runId } = await params;

  try {
    const artifacts = await db
      .selectFrom("artifacts")
      .selectAll()
      .where("run_id", "=", runId)
      .orderBy("created_at", "asc")
      .execute();

    return NextResponse.json(artifacts);
  } catch (error) {
    return NextResponse.json(
      { error: "Failed to fetch artifacts" },
      { status: 500 }
    );
  }
}
