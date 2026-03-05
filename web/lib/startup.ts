/**
 * Startup recovery: on every server boot this module finds any pipeline runs
 * that were left in status="blocked" (queued while the previous session was in
 * drain/shutdown mode) or status="running" (orphaned by a crash) and handles
 * them appropriately:
 *
 *  - "blocked" runs → re-executed from the beginning (status transitions to
 *    "running" immediately, then completes normally).
 *  - "running" runs  → marked "failed" since the executor process that was
 *    running them is gone; they cannot be safely resumed mid-step.
 */

import { db } from "./db";
import { resumeBlockedRun, markOrphanedRunFailed } from "./trigger-pipeline";

export async function resumeBlockedRuns(): Promise<void> {
  const blocked = await db
    .selectFrom("pipeline_runs")
    .select("id")
    .where("status", "=", "blocked")
    .execute();

  for (const run of blocked) {
    console.log(`[startup] Resuming blocked run: ${run.id}`);
    await resumeBlockedRun(run.id);
  }

  const orphaned = await db
    .selectFrom("pipeline_runs")
    .select("id")
    .where("status", "=", "running")
    .execute();

  for (const run of orphaned) {
    console.log(`[startup] Marking orphaned run as failed: ${run.id}`);
    await markOrphanedRunFailed(run.id);
  }

  if (blocked.length > 0 || orphaned.length > 0) {
    console.log(
      `[startup] Recovery complete: resumed ${blocked.length} blocked run(s), failed ${orphaned.length} orphaned run(s).`,
    );
  }
}
