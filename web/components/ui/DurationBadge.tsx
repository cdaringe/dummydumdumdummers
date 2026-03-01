import { formatDuration } from "@/lib/format";

type Props = { ms: number | null | undefined };

export function DurationBadge({ ms }: Props) {
  return (
    <span
      style={{
        fontFamily: "monospace",
        fontSize: "var(--font-size-base)",
        color: "var(--color-gray-600)",
      }}
    >
      {formatDuration(ms)}
    </span>
  );
}
