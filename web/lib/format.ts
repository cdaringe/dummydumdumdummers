export function formatDate(
  dateStr: string | null | undefined,
): string {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;
  return d.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatDuration(
  ms: number | null | undefined,
): string {
  if (ms == null || ms === 0) return "—";
  if (ms < 1000) return `${Math.round(ms)}ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(1)}s`;
  const mins = Math.floor(ms / 60_000);
  const secs = Math.round((ms % 60_000) / 1000);
  return `${mins}m ${secs}s`;
}

export function formatSchedule(scheduleStr: string): string {
  if (
    !scheduleStr || scheduleStr === "NoSchedule" ||
    scheduleStr === '"NoSchedule"'
  ) {
    return "None";
  }
  try {
    const s = typeof scheduleStr === "string"
      ? JSON.parse(scheduleStr)
      : scheduleStr;
    if (s === "NoSchedule") return "None";
    if (s.Daily) {
      return `Daily ${s.Daily.hour}:${String(s.Daily.minute).padStart(2, "0")}`;
    }
    if (s.Weekly) return `Weekly (day ${s.Weekly.day})`;
    if (s.Monthly) return `Monthly (day ${s.Monthly.day})`;
    if (s.Interval) return `Every ${s.Interval.seconds}s`;
    if (s.Cron) return `Cron: ${s.Cron.expression}`;
    return "None";
  } catch {
    return "None";
  }
}

export function formatTrigger(triggerStr: string): string {
  if (
    !triggerStr || triggerStr === "NoTrigger" || triggerStr === '"NoTrigger"'
  ) {
    return "None";
  }
  try {
    const t = typeof triggerStr === "string"
      ? JSON.parse(triggerStr)
      : triggerStr;
    if (t === "NoTrigger") return "None";
    if (t.Webhook) return "Webhook";
    if (t.GitHub) return `GitHub (${t.GitHub.repo})`;
    if (t.GitLab) return `GitLab (${t.GitLab.project})`;
    if (t.Custom) return `Custom: ${t.Custom.name}`;
    return "None";
  } catch {
    return "None";
  }
}

export function statusColor(status: string): string {
  switch (status) {
    case "ok":
    case "success":
      return "var(--color-status-ok)";
    case "failed":
      return "var(--color-status-failed)";
    case "running":
      return "var(--color-status-running)";
    case "skipped":
      return "var(--color-status-skipped)";
    default:
      return "var(--color-gray-400)";
  }
}
