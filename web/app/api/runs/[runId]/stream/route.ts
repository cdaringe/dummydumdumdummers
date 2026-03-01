import { db } from "@/lib/db";
import { type RunEvent, runEvents } from "@/lib/run-events";

export const dynamic = "force-dynamic";

type Params = { params: Promise<{ runId: string }> };

export async function GET(req: Request, { params }: Params) {
  const { runId } = await params;

  // Verify run exists
  const run = await db
    .selectFrom("pipeline_runs")
    .select(["id", "status"])
    .where("id", "=", runId)
    .executeTakeFirst();

  if (!run) {
    return new Response("Run not found", { status: 404 });
  }

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      const send = (event: string, data: unknown) => {
        controller.enqueue(
          encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`),
        );
      };

      // Send initial state
      send("connected", { runId, status: run.status });

      // If already completed, close immediately
      if (run.status !== "running") {
        send("run_completed", { status: run.status });
        controller.close();
        return;
      }

      // Listen for run events
      const handler = (evt: RunEvent) => {
        try {
          send(evt.type, evt);
          if (evt.type === "run_completed") {
            controller.close();
          }
        } catch {
          // Client disconnected
          runEvents.off(`run:${runId}`, handler);
        }
      };

      runEvents.on(`run:${runId}`, handler);

      // Cleanup on client disconnect
      req.signal.addEventListener("abort", () => {
        runEvents.off(`run:${runId}`, handler);
        try {
          controller.close();
        } catch {
          // Already closed
        }
      });
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}
