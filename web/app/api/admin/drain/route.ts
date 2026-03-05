/**
 * Admin: drain mode toggle.
 *
 * POST   /api/admin/drain  — enter drain mode (block new triggers)
 * DELETE /api/admin/drain  — exit drain mode (allow new triggers again)
 *
 * In production this would be gated behind authentication; for this project
 * it is intentionally open to allow E2E testing and operator convenience.
 */
import { NextResponse } from "next/server";
import {
  getActiveRunCount,
  initiateGracefulShutdown,
  isShuttingDown,
  resetShutdownState,
} from "@/lib/shutdown";

export const dynamic = "force-dynamic";

export async function POST() {
  if (isShuttingDown()) {
    return NextResponse.json(
      { draining: true, activeRuns: getActiveRunCount() },
      { status: 200 },
    );
  }
  // Fire-and-forget: drain resolves when all active runs finish, but we
  // return immediately so the caller is not blocked.
  void initiateGracefulShutdown();
  return NextResponse.json(
    { draining: true, activeRuns: getActiveRunCount() },
    { status: 200 },
  );
}

export async function DELETE() {
  resetShutdownState();
  return NextResponse.json({ draining: false }, { status: 200 });
}
