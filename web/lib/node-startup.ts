/**
 * Node.js-only startup/shutdown logic.
 * This module is only loaded via dynamic import inside instrumentation.ts
 * when NEXT_RUNTIME === "nodejs", so Next.js does not flag Node.js APIs here
 * during its edge-runtime static analysis pass.
 */
import { initiateGracefulShutdown } from "./shutdown";
import { resumeBlockedRuns } from "./startup";

const handleShutdown = (): Promise<never> =>
  initiateGracefulShutdown().then(() => process.exit(0));

export async function nodeStartup(): Promise<void> {
  process.once("SIGTERM", () => void handleShutdown());
  process.once("SIGINT", () => void handleShutdown());
  await resumeBlockedRuns().catch(() => {});
}
