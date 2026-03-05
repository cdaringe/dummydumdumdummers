/**
 * Next.js server instrumentation — runs once per server process on startup.
 * https://nextjs.org/docs/app/building-your-application/optimizing/instrumentation
 *
 * All Node.js-specific code (process.once, SIGTERM/SIGINT handlers, etc.) is
 * isolated in lib/node-startup.ts and only loaded via dynamic import when the
 * runtime is confirmed to be Node.js. This prevents Next.js's edge-runtime
 * static analysis from flagging Node.js APIs.
 */
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { nodeStartup } = await import("./lib/node-startup");
    await nodeStartup();
  }
}
