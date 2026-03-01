import { NextResponse } from "next/server";
import { db } from "@/lib/db";

export async function GET() {
  try {
    await db.selectFrom("pipeline_definitions").select("id").limit(1).execute();
    return NextResponse.json({ status: "ok", db: "connected" });
  } catch {
    return NextResponse.json(
      { status: "error", db: "disconnected" },
      { status: 500 },
    );
  }
}
