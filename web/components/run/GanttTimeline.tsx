"use client";

import { StepTrace } from "@/lib/types";
import { formatDuration } from "@/lib/format";

type Props = {
  stepTraces: StepTrace[];
  totalDuration: number;
};

export function GanttTimeline({ stepTraces, totalDuration }: Props) {
  // Calculate cumulative time for each step (assuming sequential execution)
  const stepsWithTiming = stepTraces.map((trace, idx) => {
    const startTime = stepTraces
      .slice(0, idx)
      .reduce((sum, t) => sum + t.duration_ms, 0);
    return {
      ...trace,
      startTime,
      endTime: startTime + trace.duration_ms,
    };
  });

  const pixelsPerMs = totalDuration > 0 ? 600 / totalDuration : 1;

  return (
    <div style={{ marginTop: "var(--spacing-lg)" }}>
      <div
        style={{
          fontSize: "var(--font-size-sm)",
          color: "var(--color-gray-600)",
          marginBottom: "var(--spacing-md)",
          fontWeight: 600,
        }}
      >
        Execution Timeline
      </div>

      <div style={{ overflowX: "auto", paddingBottom: "var(--spacing-lg)" }}>
        <div style={{ minWidth: 800 }}>
          {/* Timeline header with time markers */}
          <div style={{ marginBottom: "var(--spacing-xl)" }}>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                fontSize: "var(--font-size-xs)",
                color: "var(--color-gray-500)",
                fontFamily: "monospace",
                paddingRight: "var(--spacing-lg)",
                marginLeft: "var(--gantt-label-width)",
              }}
            >
              <span>0ms</span>
              <span>{formatDuration(totalDuration / 4)}</span>
              <span>{formatDuration(totalDuration / 2)}</span>
              <span>{formatDuration((totalDuration * 3) / 4)}</span>
              <span>{formatDuration(totalDuration)}</span>
            </div>
            <div
              style={{
                height: 1,
                background: "var(--color-gray-300)",
                marginLeft: "var(--gantt-label-width)",
                marginRight: "var(--spacing-lg)",
              }}
            />
          </div>

          {/* Step bars */}
          {stepsWithTiming.map((trace) => {
            const barWidth = Math.max(
              4,
              trace.duration_ms * pixelsPerMs
            );
            const offsetLeft = trace.startTime * pixelsPerMs;

            const statusColor = {
              ok: "var(--color-primary)",
              failed: "var(--color-gray-800)",
              skipped: "var(--color-gray-400)",
            }[trace.status] || "var(--color-gray-500)";

            return (
              <div
                key={trace.id}
                style={{
                  display: "flex",
                  alignItems: "center",
                  marginBottom: "var(--gantt-bar-gap)",
                  minHeight: "var(--gantt-bar-height)",
                }}
              >
                {/* Step name column */}
                <div
                  style={{
                    width: "var(--gantt-label-width)",
                    fontSize: "var(--font-size-base)",
                    fontFamily: "monospace",
                    fontWeight: 500,
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                    whiteSpace: "nowrap",
                    paddingRight: "var(--spacing-sm)",
                    color: trace.status === "skipped" ? "var(--color-gray-500)" : "var(--color-gray-900)",
                    textDecoration:
                      trace.status === "skipped" ? "line-through" : "none",
                  }}
                  title={trace.step_name}
                >
                  {trace.step_name}
                </div>

                {/* Timeline bar container */}
                <div
                  style={{
                    flex: 1,
                    position: "relative",
                    height: "var(--gantt-bar-height)",
                    display: "flex",
                    alignItems: "center",
                    paddingRight: "var(--spacing-lg)",
                  }}
                >
                  {/* Bar with offset */}
                  <div
                    style={{
                      marginLeft: `${offsetLeft}px`,
                      height: "calc(var(--gantt-bar-height) - 8px)",
                      borderRadius: "var(--border-radius-sm)",
                      background: statusColor,
                      opacity: 0.85,
                      minWidth: barWidth,
                      display: "flex",
                      alignItems: "center",
                      paddingLeft: barWidth > 30 ? 6 : 0,
                      cursor: "pointer",
                      transition: "opacity 0.2s",
                      position: "relative",
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.opacity = "1";
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.opacity = "0.85";
                    }}
                    title={`${trace.step_name}: ${formatDuration(trace.duration_ms)}`}
                  >
                    {barWidth > 50 && (
                      <span
                        style={{
                          fontSize: "var(--font-size-xs)",
                          color: "white",
                          fontWeight: 600,
                          fontFamily: "monospace",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {formatDuration(trace.duration_ms)}
                      </span>
                    )}
                  </div>
                </div>

                {/* Duration label */}
                <div
                  style={{
                    fontSize: "var(--font-size-sm)",
                    color: "var(--color-gray-600)",
                    fontFamily: "monospace",
                    minWidth: 60,
                    textAlign: "right",
                  }}
                >
                  {formatDuration(trace.duration_ms)}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Legend */}
      <div
        style={{
          display: "flex",
          gap: "var(--spacing-xl)",
          fontSize: "var(--font-size-sm)",
          color: "var(--color-gray-600)",
          marginTop: "var(--spacing-lg)",
          padding: "var(--spacing-md) 0",
          borderTop: "1px solid var(--color-gray-300)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: "var(--spacing-sm)" }}>
          <div
            style={{
              width: 12,
              height: 12,
              borderRadius: 2,
              background: "var(--color-primary)",
            }}
          />
          <span>Success</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--spacing-sm)" }}>
          <div
            style={{
              width: 12,
              height: 12,
              borderRadius: 2,
              background: "var(--color-gray-800)",
            }}
          />
          <span>Failed</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--spacing-sm)" }}>
          <div
            style={{
              width: 12,
              height: 12,
              borderRadius: 2,
              background: "var(--color-gray-400)",
            }}
          />
          <span>Skipped</span>
        </div>
      </div>
    </div>
  );
}
