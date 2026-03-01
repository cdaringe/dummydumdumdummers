"use client";
import { Handle, Position } from "@xyflow/react";
import { statusColor } from "@/lib/format";
import type { StepNodeData } from "@/lib/dag";

type Props = { data: StepNodeData };

const loopLabel = (loop: StepNodeData["loop"]): string | null => {
  if (!loop) return null;
  switch (loop.type) {
    case "FixedCount":
      return `×${loop.count}`;
    case "RetryOnFailure":
      return `retry ×${loop.max_attempts}`;
    case "UntilSuccess":
      return `until ✓ (max ${loop.max_attempts})`;
  }
};

export function PipelineDagNode({ data }: Props) {
  const color = statusColor(data.status);
  const loop = loopLabel(data.loop);

  return (
    <div
      style={{
        background: "var(--color-gray-100)",
        border: `2px solid ${color}`,
        borderRadius: "var(--border-radius-sm)",
        padding: "var(--spacing-sm) var(--spacing-md)",
        minWidth: 160,
      }}
    >
      <Handle type="target" position={Position.Left} />
      <div
        style={{
          fontWeight: 600,
          fontSize: "var(--font-size-base)",
          color: "var(--color-gray-950)",
          wordBreak: "break-word",
        }}
      >
        {data.label}
      </div>
      {loop && (
        <div style={{ fontSize: "var(--font-size-xs)", color: "var(--color-gray-600)", marginTop: "var(--spacing-xs)" }}>
          {loop}
        </div>
      )}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "var(--spacing-sm)",
          marginTop: "var(--spacing-xs)",
        }}
      >
        <span
          style={{
            display: "inline-block",
            width: 8,
            height: 8,
            borderRadius: "50%",
            background: color,
          }}
        />
        <span style={{ fontSize: "var(--font-size-xs)", color: "var(--color-gray-600)" }}>{data.status}</span>
      </div>
      <Handle type="source" position={Position.Right} />
    </div>
  );
}
