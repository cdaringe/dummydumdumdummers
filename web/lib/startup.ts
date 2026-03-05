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
import { markOrphanedRunFailed, resumeBlockedRun } from "./trigger-pipeline";

export async function resumeBlockedRuns(): Promise<void> {
  const [blocked, orphaned] = await Promise.all([
    db
      .selectFrom("pipeline_runs")
      .select("id")
      .where("status", "=", "blocked")
      .execute(),
    db
      .selectFrom("pipeline_runs")
      .select("id")
      .where("status", "=", "running")
      .execute(),
  ]);

  await Promise.all([
    ...blocked.map(({ id }) => resumeBlockedRun(id)),
    ...orphaned.map(({ id }) => markOrphanedRunFailed(id)),
  ]);
}
