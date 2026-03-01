"use client";

import { useState } from "react";

type StepTrace = {
  id: string;
  step_name: string;
  status: string;
  duration_ms: number;
  error_msg: string | null;
  log_output: string | null;
  sequence: number;
};

type Props = {
  stepTraces: StepTrace[];
};

function StatusIndicator({ status }: { status: string }) {
  if (status === "running") {
    return (
      <span
        style={{
          display: "inline-block",
          width: 8,
          height: 8,
          borderRadius: "50%",
          backgroundColor: "var(--color-primary-light)",
          animation: "pulse 1.5s ease-in-out infinite",
        }}
      />
    );
  }
  if (status === "pending") {
    return (
      <span
        style={{
          display: "inline-block",
          width: 8,
          height: 8,
          borderRadius: 2,
          backgroundColor: "var(--color-gray-300, #d1d5db)",
          opacity: 0.5,
        }}
      />
    );
  }
  const color =
    status === "ok"
      ? "var(--color-status-ok)"
      : status === "failed"
        ? "var(--color-status-failed)"
        : "var(--color-status-skipped)";
  return (
    <span
      style={{
        display: "inline-block",
        width: 8,
        height: 8,
        borderRadius: 2,
        backgroundColor: color,
      }}
    />
  );
}

function formatDuration(ms: number): string {
  if (ms === 0) return "0ms";
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

export function StepLogViewer({ stepTraces }: Props) {
  const [expandedSteps, setExpandedSteps] = useState<Set<string>>(new Set());

  const toggleStep = (id: string) => {
    setExpandedSteps((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const maxDuration = Math.max(...stepTraces.map((t) => t.duration_ms), 1);

  return (
    <div>
      {stepTraces.map((trace, i) => {
        const isExpanded = expandedSteps.has(trace.id);
        const hasLogs = !!trace.log_output;
        const isRunning = trace.status === "running";
        const isPending = trace.status === "pending";

        return (
          <div
            key={trace.id}
            style={{
              borderBottom:
                i < stepTraces.length - 1
                  ? "1px solid var(--color-gray-200)"
                  : "none",
              opacity: isPending ? 0.45 : 1,
            }}
          >
            {/* Step header row */}
            <div
              onClick={() => hasLogs && toggleStep(trace.id)}
              style={{
                display: "grid",
                gridTemplateColumns: "var(--step-number-width) var(--step-name-width) var(--step-status-width) var(--step-duration-width) 1fr 24px",
                alignItems: "center",
                gap: "var(--spacing-md)",
                padding: "var(--step-row-padding) 0",
                cursor: hasLogs ? "pointer" : "default",
                userSelect: "none",
              }}
              data-testid={`step-row-${trace.step_name}`}
            >
              <span
                style={{
                  fontSize: "var(--font-size-xs)",
                  color: "var(--color-gray-500)",
                  textAlign: "right",
                  fontFamily: "monospace",
                }}
              >
                {trace.sequence + 1}
              </span>
              <span
                style={{
                  fontFamily: "monospace",
                  fontSize: "var(--font-size-sm)",
                  fontWeight: 500,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {trace.step_name}
              </span>
              <span>
                <StatusIndicator status={trace.status} />
                <span
                  style={{
                    marginLeft: "var(--spacing-sm)",
                    fontSize: "var(--font-size-xs)",
                    color: isRunning
                      ? "var(--color-primary-light)"
                      : isPending
                        ? "var(--color-gray-400)"
                        : "var(--color-gray-600)",
                    textTransform: "uppercase",
                    letterSpacing: "0.05em",
                    fontWeight: isRunning ? 600 : undefined,
                  }}
                >
                  {trace.status}
                </span>
              </span>
              <span
                style={{
                  fontFamily: "monospace",
                  fontSize: "var(--font-size-sm)",
                  color: "var(--color-gray-600)",
                }}
              >
                {isRunning
                  ? "..."
                  : isPending
                    ? "-"
                    : formatDuration(trace.duration_ms)}
              </span>
              <div>
                {!isPending &&
                  !isRunning &&
                  trace.status !== "skipped" &&
                  trace.duration_ms > 0 && (
                    <div
                      style={{
                        height: 6,
                        borderRadius: 3,
                        background:
                          trace.status === "ok"
                            ? "var(--color-status-ok)"
                            : trace.status === "failed"
                              ? "var(--color-status-failed)"
                              : "var(--color-status-skipped)",
                        width: `${Math.max(2, (trace.duration_ms / maxDuration) * 100)}%`,
                        opacity: 0.7,
                      }}
                    />
                  )}
                {isRunning && (
                  <div
                    style={{
                      height: 6,
                      borderRadius: 3,
                      background: "var(--color-primary-light)",
                      width: "60%",
                      animation: "pulse 1.5s ease-in-out infinite",
                    }}
                  />
                )}
                {trace.error_msg && (
                  <div
                    style={{
                      marginTop: "var(--spacing-xs)",
                      fontSize: "var(--font-size-sm)",
                      color: "var(--color-status-failed)",
                      fontFamily: "monospace",
                    }}
                  >
                    {trace.error_msg}
                  </div>
                )}
              </div>
              <span
                style={{
                  fontSize: "var(--font-size-sm)",
                  color: hasLogs ? "var(--color-gray-500)" : "transparent",
                  textAlign: "center",
                  fontFamily: "monospace",
                }}
              >
                {isExpanded ? "[-]" : "[+]"}
              </span>
            </div>

            {/* Expanded log output */}
            {isExpanded && trace.log_output && (
              <div
                data-testid={`step-log-${trace.step_name}`}
                style={{
                  margin: "0 0 var(--spacing-md) var(--step-row-indent)",
                  padding: "var(--spacing-md) var(--spacing-lg)",
                  backgroundColor: "var(--color-gray-950)",
                  color: "var(--color-gray-400)",
                  fontFamily: "monospace",
                  fontSize: "var(--font-size-xs)",
                  lineHeight: 1.7,
                  borderRadius: "var(--border-radius-sm)",
                  whiteSpace: "pre-wrap",
                  wordBreak: "break-word",
                  overflowX: "auto",
                  maxHeight: 400,
                  overflowY: "auto",
                }}
              >
                {trace.log_output.split("\n").map((line, li) => {
                  let lineColor = "var(--color-gray-400)";
                  if (line.startsWith("[ERROR]")) {
                    lineColor = "var(--color-status-failed)";
                  } else if (line.startsWith("[SKIP]")) {
                    lineColor = "var(--color-status-skipped)";
                  } else if (line.startsWith("$")) {
                    lineColor = "var(--color-primary-light)";
                  } else if (
                    line.includes("passed") ||
                    line.includes("successfully") ||
                    line.includes("Finished")
                  ) {
                    lineColor = "var(--color-primary)";
                  }
                  return (
                    <div key={li} style={{ color: lineColor }}>
                      {line}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}

      <style
        dangerouslySetInnerHTML={{
          __html: `@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}`,
        }}
      />
    </div>
  );
}
