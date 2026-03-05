import { NextResponse } from "next/server";
import { rawDb } from "@/lib/db";
import { clearAllData, seedFixtures } from "@/lib/seed-fixtures";
import { config } from "@/lib/config";
import { resetShutdownState } from "@/lib/shutdown";

export const dynamic = "force-dynamic";

export async function POST() {
  if (config.databasePath !== ":memory:") {
    return NextResponse.json(
      { error: "Test reset only available with in-memory database" },
      { status: 403 },
    );
  }

  clearAllData(rawDb);
  seedFixtures(rawDb);
  // Also reset drain state so tests start with a clean server state.
  resetShutdownState();

  return NextResponse.json({ ok: true });
}
