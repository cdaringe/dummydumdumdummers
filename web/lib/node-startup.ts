/**
 * Node.js-only startup/shutdown logic.
 * This module is only loaded via dynamic import inside instrumentation.ts
 * when NEXT_RUNTIME === "nodejs", so Next.js does not flag Node.js APIs here
 * during its edge-runtime static analysis pass.
 */
import { initiateGracefulShutdown } from "./shutdown";
import { resumeBlockedRuns } from "./startup";

export async function nodeStartup(): Promise<void> {
  const handleShutdown = async () => {
    console.log(
      "[process] Shutdown signal received — initiating graceful drain...",
    );
    await initiateGracefulShutdown();
    console.log("[process] All in-flight runs finished. Exiting cleanly.");
    process.exit(0);
  };

  process.once("SIGTERM", () => void handleShutdown());
  process.once("SIGINT", () => void handleShutdown());

  try {
    await resumeBlockedRuns();
  } catch (err) {
    console.error("[startup] Failed to resume blocked/orphaned runs:", err);
  }
}
