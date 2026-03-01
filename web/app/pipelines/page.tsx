import Link from "next/link";
import { db } from "@/lib/db";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { DurationBadge } from "@/components/ui/DurationBadge";
import { formatDate, formatSchedule, formatTrigger } from "@/lib/format";
import type { StepDefinition } from "@/lib/types";

export const dynamic = "force-dynamic";

async function getPipelines() {
  const pipelines = await db
    .selectFrom("pipeline_definitions")
    .selectAll()
    .orderBy("name")
    .execute() as any[];

  const allRuns = await db
    .selectFrom("pipeline_runs")
    .selectAll()
    .orderBy("started_at", "desc")
    .execute() as any[];

  const lastRunMap = new Map<string, any>();
  for (const run of allRuns) {
    if (!lastRunMap.has(run.pipeline_id)) {
      lastRunMap.set(run.pipeline_id, run);
    }
  }

  return pipelines.map((p: any) => ({
    ...p,
    steps: JSON.parse(p.steps) as StepDefinition[],
    last_run: lastRunMap.get(p.id) ?? null,
  }));
}

export default async function PipelinesPage() {
  const pipelines = await getPipelines();

  return (
    <div>
      <div className="page-header">
        <h1>Pipelines</h1>
        <p>{pipelines.length} pipeline definitions registered</p>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Steps</th>
              <th>Schedule</th>
              <th>Trigger</th>
              <th>Last Run</th>
              <th>Duration</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {pipelines.map((p) => (
              <tr key={p.id}>
                <td>
                  <Link
                    href={`/pipelines/${p.name}/${p.version}`}
                    style={{ fontWeight: 600 }}
                  >
                    {p.name}
                  </Link>
                  <span
                    style={{
                      marginLeft: "var(--spacing-sm)",
                      fontSize: "var(--font-size-xs)",
                      color: "var(--color-gray-500)",
                      fontFamily: "monospace",
                    }}
                  >
                    v{p.version}
                  </span>
                  {p.description && (
                    <div
                      style={{
                        fontSize: "var(--font-size-sm)",
                        color: "var(--color-gray-600)",
                        marginTop: "var(--spacing-xs)",
                        maxWidth: 280,
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {p.description}
                    </div>
                  )}
                </td>
                <td style={{ color: "var(--color-gray-600)" }}>
                  {p.steps.length}
                </td>
                <td
                  style={{
                    fontSize: "var(--font-size-sm)",
                    color: "var(--color-gray-600)",
                  }}
                >
                  {formatSchedule(p.schedule)}
                </td>
                <td
                  style={{
                    fontSize: "var(--font-size-sm)",
                    color: "var(--color-gray-600)",
                  }}
                >
                  {formatTrigger(p.trigger)}
                </td>
                <td>
                  {p.last_run
                    ? <StatusBadge status={p.last_run.status} />
                    : (
                      <span
                        style={{
                          color: "var(--color-gray-500)",
                          fontSize: "var(--font-size-sm)",
                        }}
                      >
                        Never
                      </span>
                    )}
                </td>
                <td>
                  <DurationBadge ms={p.last_run?.duration_ms} />
                </td>
                <td>
                  <div
                    style={{
                      display: "flex",
                      gap: "var(--spacing-sm)",
                      alignItems: "center",
                    }}
                  >
                    <Link
                      href={`/pipelines/${p.name}/${p.version}`}
                      className="btn btn-sm"
                      style={{
                        background: "var(--color-gray-200)",
                        color: "var(--color-gray-800)",
                      }}
                    >
                      View
                    </Link>
                    <TriggerButton name={p.name} version={p.version} />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function TriggerButton({
  name,
  version,
}: {
  name: string;
  version: string;
}) {
  return (
    <form
      action={`/api/pipelines/${name}/${version}/trigger`}
      method="POST"
      style={{ display: "inline" }}
    >
      <button
        type="submit"
        className="btn btn-sm btn-primary"
        data-testid={`trigger-${name}`}
      >
        ▶ Run
      </button>
    </form>
  );
}
