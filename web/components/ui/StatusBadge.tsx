import { statusColor } from "@/lib/format";

type Props = { status: string };

const statusLabel: Record<string, string> = {
  ok: "OK",
  success: "Success",
  failed: "Failed",
  running: "Running",
  skipped: "Skipped",
  pending: "Pending",
};

export function StatusBadge({ status }: Props) {
  const color = statusColor(status);
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--spacing-xs)",
        padding: "var(--spacing-xs) var(--spacing-md)",
        borderRadius: 12,
        fontSize: "var(--font-size-sm)",
        fontWeight: 600,
        background: `${color}18`,
        color: color,
        border: `1px solid ${color}44`,
        whiteSpace: "nowrap",
      }}
    >
      <span
        style={{
          width: 6,
          height: 6,
          borderRadius: "50%",
          background: color,
          display: "inline-block",
        }}
      />
      {statusLabel[status] ?? status}
    </span>
  );
}
