/**
 * Admin: resume blocked runs.
 *
 * POST /api/admin/resume-blocked — replay all runs with status="blocked",
 * transitioning them to "running" and executing their steps.  This mirrors
 * what the server startup hook does automatically on every boot, but is
 * also exposed as an API endpoint for testing and operator convenience.
 */
import { NextResponse } from "next/server";
import { resumeBlockedRuns } from "@/lib/startup";

export const dynamic = "force-dynamic";

export async function POST() {
  await resumeBlockedRuns();
  return NextResponse.json({ ok: true });
}
