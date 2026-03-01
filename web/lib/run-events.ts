import { EventEmitter } from "events";

export type RunEvent =
  | {
      type: "step_started";
      step_name: string;
      sequence: number;
    }
  | {
      type: "step_completed";
      step_name: string;
      sequence: number;
      status: string;
      duration_ms: number;
      log_output: string;
    }
  | {
      type: "run_completed";
      status: string;
      duration_ms: number;
      finished_at: string;
    };

// Singleton event bus shared across API routes for SSE streaming.
// Using globalThis to survive hot-module-reload in dev.
const globalKey = "__thingfactory_run_events__";

function getRunEvents(): EventEmitter {
  const g = globalThis as Record<string, unknown>;
  if (!g[globalKey]) {
    const emitter = new EventEmitter();
    emitter.setMaxListeners(100);
    g[globalKey] = emitter;
  }
  return g[globalKey] as EventEmitter;
}

export const runEvents = getRunEvents();
