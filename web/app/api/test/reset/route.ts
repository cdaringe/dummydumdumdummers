import { NextResponse } from "next/server";
import { rawDb } from "@/lib/db";
import { clearAllData, seedFixtures } from "@/lib/seed-fixtures";

export async function POST() {
  if (process.env.DATABASE_PATH !== ":memory:") {
    return NextResponse.json(
      { error: "Test reset only available with in-memory database" },
      { status: 403 }
    );
  }

  clearAllData(rawDb);
  seedFixtures(rawDb);

  return NextResponse.json({ ok: true });
}
