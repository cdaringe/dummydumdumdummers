"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { GanttTimeline } from "@/components/run/GanttTimeline";
import { ArtifactsList } from "@/components/run/ArtifactsList";
import { StepLogViewer } from "@/components/run/StepLogViewer";
import { formatDate, formatDuration } from "@/lib/format";

type StepDef = {
  name: string;
  timeout_ms: number;
  depends_on: string[];
};

type StepTrace = {
  id: string;
  step_name: string;
  status: string;
  duration_ms: number;
  error_msg: string | null;
  log_output: string | null;
  sequence: number;
};

type RunData = {
  id: string;
  pipeline_name: string;
  pipeline_version: string;
  pipeline_steps: string; // JSON
  status: string;
  trigger_type: string;
  started_at: string;
  finished_at: string | null;
  duration_ms: number | null;
};

type Props = {
  run: RunData;
  initialTraces: StepTrace[];
};

export function RunDetailClient({ run: initialRun, initialTraces }: Props) {
  const [status, setStatus] = useState(initialRun.status);
  const [finishedAt, setFinishedAt] = useState(initialRun.finished_at);
  const [durationMs, setDurationMs] = useState(initialRun.duration_ms);
  const [traces, setTraces] = useState<StepTrace[]>(initialTraces);
  const [elapsedMs, setElapsedMs] = useState<number | null>(null);
  const startTimeRef = useRef(new Date(initialRun.started_at).getTime());

  const steps: StepDef[] = JSON.parse(initialRun.pipeline_steps);

  // SSE connection for live updates
  useEffect(() => {
    if (status !== "running") return;

    const es = new EventSource(`/api/runs/${initialRun.id}/stream`);

    es.addEventListener("step_started", (e) => {
      const data = JSON.parse(e.data);
      setTraces((prev) => {
        // Remove any existing trace for this step, add running one
        const filtered = prev.filter(
          (t) => t.step_name !== data.step_name,
        );
        return [
          ...filtered,
          {
            id: `running-${data.sequence}`,
            step_name: data.step_name,
            status: "running",
            duration_ms: 0,
            error_msg: null,
            log_output: null,
            sequence: data.sequence,
          },
        ].sort((a, b) => a.sequence - b.sequence);
      });
    });

    es.addEventListener("step_completed", (e) => {
      const data = JSON.parse(e.data);
      setTraces((prev) => {
        const filtered = prev.filter(
          (t) => t.step_name !== data.step_name,
        );
        return [
          ...filtered,
          {
            id: `done-${data.sequence}`,
            step_name: data.step_name,
            status: data.status,
            duration_ms: data.duration_ms,
            error_msg: null,
            log_output: data.log_output,
            sequence: data.sequence,
          },
        ].sort((a, b) => a.sequence - b.sequence);
      });
    });

    es.addEventListener("run_completed", (e) => {
      const data = JSON.parse(e.data);
      setStatus(data.status);
      setDurationMs(data.duration_ms);
      setFinishedAt(data.finished_at);
      es.close();
    });

    es.onerror = () => {
      es.close();
    };

    return () => es.close();
  }, [initialRun.id, status]);

  // Elapsed time counter while running
  useEffect(() => {
    if (status !== "running") {
      setElapsedMs(null);
      return;
    }

    const tick = () => setElapsedMs(Date.now() - startTimeRef.current);
    tick();
    const interval = setInterval(tick, 100);
    return () => clearInterval(interval);
  }, [status]);

  // Build the full step list: traces + pending steps
  const allSteps: StepTrace[] = steps.map((step, i) => {
    const trace = traces.find((t) => t.step_name === step.name);
    if (trace) return trace;
    return {
      id: `pending-${i}`,
      step_name: step.name,
      status: "pending",
      duration_ms: 0,
      error_msg: null,
      log_output: null,
      sequence: i,
    };
  });

  const completedTraces = allSteps.filter(
    (t) => t.status === "ok" || t.status === "failed",
  );
  const displayDuration = durationMs ?? elapsedMs ??
    completedTraces.reduce((s, t) => s + t.duration_ms, 0);
  const timelineDuration = durationMs ??
    completedTraces.reduce((s, t) => s + t.duration_ms, 0);

  return (
    <div>
      <div style={{ marginBottom: "var(--spacing-sm)" }}>
        <Link
          href={`/pipelines/${initialRun.pipeline_name}/${initialRun.pipeline_version}`}
          style={{
            fontSize: "var(--font-size-base)",
            color: "var(--color-gray-600)",
          }}
        >
          &larr; {initialRun.pipeline_name} v{initialRun.pipeline_version}
        </Link>
      </div>

      <div className="page-header">
        <h1>
          Run{" "}
          <span
            style={{
              fontFamily: "monospace",
              fontSize: "var(--font-size-lg)",
              color: "var(--color-gray-600)",
            }}
          >
            {initialRun.id?.substring(0, 8)}...
          </span>
        </h1>
        <p>
          {initialRun.pipeline_name} v{initialRun.pipeline_version}{" "}
          &nbsp;&middot;&nbsp; Triggered by {initialRun.trigger_type}
        </p>
      </div>

      {/* Run Summary Card */}
      <div
        className="card"
        style={{
          padding: "var(--spacing-xl)",
          marginBottom: "var(--spacing-xl)",
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: "var(--spacing-lg)",
        }}
      >
        <div>
          <div
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-xs)",
            }}
          >
            Status
          </div>
          <StatusBadge status={status} />
        </div>
        <div>
          <div
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-xs)",
            }}
          >
            {status === "running" ? "Elapsed" : "Total Duration"}
          </div>
          <div
            style={{
              fontWeight: 600,
              fontFamily: "monospace",
              color: status === "running"
                ? "var(--color-primary-light)"
                : undefined,
            }}
          >
            {formatDuration(displayDuration)}
          </div>
        </div>
        <div>
          <div
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-xs)",
            }}
          >
            Started
          </div>
          <div style={{ fontSize: "var(--font-size-base)" }}>
            {formatDate(initialRun.started_at)}
          </div>
        </div>
        <div>
          <div
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-xs)",
            }}
          >
            Finished
          </div>
          <div style={{ fontSize: "var(--font-size-base)" }}>
            {formatDate(finishedAt)}
          </div>
        </div>
      </div>

      {/* Gantt Timeline - only show when we have completed steps */}
      {completedTraces.length > 0 && timelineDuration > 0 && (
        <div className="card" style={{ marginBottom: "var(--spacing-xl)" }}>
          <div
            style={{
              padding: "var(--spacing-lg)",
              borderBottom: "1px solid var(--color-gray-300)",
              fontWeight: 600,
              fontSize: "var(--font-size-base)",
            }}
          >
            Timeline View
          </div>
          <div style={{ padding: "var(--spacing-lg)" }}>
            <GanttTimeline
              stepTraces={completedTraces as any}
              totalDuration={timelineDuration}
            />
          </div>
        </div>
      )}

      {/* Artifacts - only show when run is complete */}
      {status !== "running" && (
        <div className="card" style={{ marginBottom: "var(--spacing-xl)" }}>
          <div
            style={{
              padding: "var(--spacing-lg)",
              borderBottom: "1px solid var(--color-gray-300)",
              fontWeight: 600,
              fontSize: "var(--font-size-base)",
            }}
          >
            Artifacts
          </div>
          <div style={{ padding: "var(--spacing-lg)" }}>
            <ArtifactsList runId={initialRun.id!} />
          </div>
        </div>
      )}

      {/* Step Traces with Log Viewer */}
      <div className="card">
        <div
          style={{
            padding: "var(--spacing-lg)",
            borderBottom: "1px solid var(--color-gray-300)",
            fontWeight: 600,
            fontSize: "var(--font-size-base)",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <span>
            Step Traces ({allSteps.filter((t) => t.status !== "pending")
              .length})
          </span>
          {status === "running"
            ? (
              <span
                style={{
                  fontSize: "var(--font-size-xs)",
                  color: "var(--color-primary-light)",
                  fontWeight: 400,
                  animation: "pulse 2s infinite",
                }}
              >
                executing...
              </span>
            )
            : (
              allSteps.some((t) => t.log_output) && (
                <span
                  style={{
                    fontSize: "var(--font-size-xs)",
                    color: "var(--color-gray-500)",
                    fontWeight: 400,
                  }}
                >
                  click a step to view logs
                </span>
              )
            )}
        </div>
        <div style={{ padding: "var(--spacing-lg)" }}>
          {allSteps.length === 0
            ? (
              <div
                style={{
                  color: "var(--color-gray-500)",
                  textAlign: "center",
                  padding: "var(--spacing-2xl)",
                }}
              >
                No steps defined
              </div>
            )
            : <StepLogViewer stepTraces={allSteps as any} />}
        </div>
      </div>

      <style
        dangerouslySetInnerHTML={{
          __html: `@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}`,
        }}
      />
    </div>
  );
}
