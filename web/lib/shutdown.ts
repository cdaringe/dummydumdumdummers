/**
 * Graceful shutdown / drain-mode manager.
 *
 * When the server receives SIGTERM/SIGINT, or when an operator calls the
 * drain admin API, this module:
 *   1. Sets the "draining" flag so new pipeline trigger requests are blocked
 *      (recorded as status="blocked" in the DB rather than executed).
 *   2. Waits asynchronously until all in-flight executeStepsInBackground calls
 *      have finished.
 *
 * State is kept in globalThis so it survives Next.js hot-reload module
 * replacement in development (same pattern as run-events.ts).
 */

declare global {
  // eslint-disable-next-line no-var
  var __thingfactory_shutdown__: ShutdownState | undefined;
}

interface ShutdownState {
  draining: boolean;
  activeRunCount: number;
  drainResolvers: Array<() => void>;
}

function getState(): ShutdownState {
  if (!globalThis.__thingfactory_shutdown__) {
    globalThis.__thingfactory_shutdown__ = {
      draining: false,
      activeRunCount: 0,
      drainResolvers: [],
    };
  }
  return globalThis.__thingfactory_shutdown__;
}

/** Returns true when the server is in drain/shutdown mode. */
export function isShuttingDown(): boolean {
  return getState().draining;
}

/** Increments active run counter when a background execution starts. */
export function registerActiveRun(): void {
  getState().activeRunCount++;
}

/**
 * Decrements the active run counter when a background execution finishes.
 * Resolves any pending drain waiters if the counter reaches zero.
 */
export function unregisterActiveRun(): void {
  const state = getState();
  state.activeRunCount = Math.max(0, state.activeRunCount - 1);
  if (state.draining && state.activeRunCount === 0) {
    for (const resolve of state.drainResolvers) resolve();
    state.drainResolvers = [];
  }
}

/** Returns the number of currently executing runs. */
export function getActiveRunCount(): number {
  return getState().activeRunCount;
}

/**
 * Enters drain mode: blocks new triggers and returns a Promise that resolves
 * once all currently in-flight runs complete.
 */
export function initiateGracefulShutdown(): Promise<void> {
  const state = getState();
  state.draining = true;
  console.log(
    `[shutdown] Drain mode activated. ${state.activeRunCount} active run(s) in flight.`,
  );
  if (state.activeRunCount === 0) return Promise.resolve();
  return new Promise<void>((resolve) => {
    state.drainResolvers.push(resolve);
  });
}

/**
 * Resets all shutdown state back to initial (used by test reset endpoint and
 * admin drain toggle).
 */
export function resetShutdownState(): void {
  globalThis.__thingfactory_shutdown__ = {
    draining: false,
    activeRunCount: 0,
    drainResolvers: [],
  };
}
