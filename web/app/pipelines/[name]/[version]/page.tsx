import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { DurationBadge } from "@/components/ui/DurationBadge";
import { PipelineDag } from "@/components/pipeline/PipelineDag";
import { buildDagGraph } from "@/lib/dag";
import { formatDate, formatSchedule, formatTrigger } from "@/lib/format";
import type {
  ScheduleConfig,
  StepDefinition,
  TriggerConfig,
} from "@/lib/types";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ name: string; version: string }> };

async function getPageData(name: string, version: string) {
  const pipelineId = `${name}@${version}`;

  const [pipeline, recentRuns] = await Promise.all([
    db
      .selectFrom("pipeline_definitions")
      .selectAll()
      .where("id", "=", pipelineId)
      .executeTakeFirst(),
    db
      .selectFrom("pipeline_runs")
      .selectAll()
      .where("pipeline_id", "=", pipelineId)
      .orderBy("started_at", "desc")
      .limit(20)
      .execute(),
  ]);

  return { pipeline, recentRuns };
}

export default async function PipelineDetailPage({ params }: Props) {
  const { name, version } = await params;
  const { pipeline, recentRuns } = await getPageData(name, version);

  if (!pipeline) notFound();

  const steps = JSON.parse(pipeline.steps) as StepDefinition[];
  const schedule = JSON.parse(pipeline.schedule) as ScheduleConfig;
  const trigger = JSON.parse(pipeline.trigger) as TriggerConfig;

  // Build last run trace data for node coloring and duration
  const lastRun = recentRuns[0];
  const traceData: Record<string, { status: string; duration_ms?: number }> =
    {};
  if (lastRun) {
    const traces = await db
      .selectFrom("step_traces")
      .select(["step_name", "status", "duration_ms"])
      .where("run_id", "=", lastRun.id ?? "")
      .execute();
    for (const t of traces) {
      traceData[t.step_name] = {
        status: t.status,
        duration_ms: t.duration_ms ?? undefined,
      };
    }
  }

  const graph = buildDagGraph(steps, traceData);

  return (
    <div>
      <div style={{ marginBottom: "var(--spacing-sm)" }}>
        <Link
          href="/pipelines"
          style={{
            fontSize: "var(--font-size-base)",
            color: "var(--color-gray-600)",
          }}
        >
          ← Pipelines
        </Link>
      </div>

      <div
        className="page-header"
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
        }}
      >
        <div>
          <h1>{name}</h1>
          <p>
            v{version} &nbsp;·&nbsp; {steps.length} steps &nbsp;·&nbsp;{" "}
            {formatSchedule(JSON.stringify(schedule))} &nbsp;·&nbsp; Trigger:
            {" "}
            {formatTrigger(JSON.stringify(trigger))}
          </p>
          {pipeline.description && (
            <p
              style={{
                marginTop: "var(--spacing-xs)",
                color: "var(--color-gray-800)",
              }}
            >
              {pipeline.description}
            </p>
          )}
        </div>
        <form
          action={`/api/pipelines/${name}/${version}/trigger`}
          method="POST"
        >
          <button type="submit" className="btn btn-primary">
            ▶ Trigger Run
          </button>
        </form>
      </div>

      {/* DAG Visualization */}
      <div
        className="card"
        style={{
          marginBottom: "var(--spacing-xl)",
          padding: "var(--spacing-lg)",
        }}
      >
        <div
          style={{
            fontWeight: 600,
            fontSize: "var(--font-size-base)",
            marginBottom: "var(--spacing-md)",
            color: "var(--color-gray-800)",
          }}
        >
          Pipeline DAG
        </div>
        <PipelineDag graph={graph} />
        <div
          style={{
            marginTop: "var(--spacing-sm)",
            fontSize: "var(--font-size-sm)",
            color: "var(--color-gray-500)",
            display: "flex",
            gap: "var(--spacing-lg)",
          }}
        >
          {(["ok", "failed", "skipped", "pending"] as const).map((s) => (
            <span
              key={s}
              style={{
                display: "flex",
                alignItems: "center",
                gap: "var(--spacing-xs)",
              }}
            >
              <span
                style={{
                  display: "inline-block",
                  width: 8,
                  height: 8,
                  borderRadius: "50%",
                  background: s === "ok"
                    ? "var(--color-primary)"
                    : s === "failed"
                    ? "var(--color-gray-800)"
                    : s === "skipped"
                    ? "var(--color-gray-500)"
                    : "var(--color-gray-400)",
                }}
              />
              {s}
            </span>
          ))}
        </div>
      </div>

      {/* Steps List */}
      <div className="card" style={{ marginBottom: "var(--spacing-xl)" }}>
        <div
          style={{
            padding: "var(--spacing-lg)",
            borderBottom: "1px solid var(--color-gray-300)",
            fontWeight: 600,
            fontSize: "var(--font-size-base)",
          }}
        >
          Steps ({steps.length})
        </div>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Step Name</th>
              <th>Timeout</th>
              <th>Dependencies</th>
              <th>Loop</th>
            </tr>
          </thead>
          <tbody>
            {steps.map((step, i) => (
              <tr key={step.name}>
                <td style={{ color: "var(--color-gray-500)", width: 40 }}>
                  {i + 1}
                </td>
                <td style={{ fontWeight: 500, fontFamily: "monospace" }}>
                  {step.name}
                </td>
                <td>
                  <DurationBadge ms={step.timeout_ms} />
                </td>
                <td
                  style={{
                    fontSize: "var(--font-size-sm)",
                    color: "var(--color-gray-600)",
                  }}
                >
                  {step.depends_on.length > 0
                    ? step.depends_on.join(", ")
                    : "—"}
                </td>
                <td
                  style={{
                    fontSize: "var(--font-size-sm)",
                    color: "var(--color-gray-600)",
                  }}
                >
                  {step.loop
                    ? `${step.loop.type}(${
                      "count" in step.loop
                        ? step.loop.count
                        : step.loop.max_attempts
                    })`
                    : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Run History */}
      <div className="card">
        <div
          style={{
            padding: "var(--spacing-lg)",
            borderBottom: "1px solid var(--color-gray-300)",
            fontWeight: 600,
            fontSize: "var(--font-size-base)",
          }}
        >
          Run History
        </div>
        <table>
          <thead>
            <tr>
              <th>Run ID</th>
              <th>Status</th>
              <th>Duration</th>
              <th>Triggered By</th>
              <th>Started</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {recentRuns.length === 0
              ? (
                <tr>
                  <td
                    colSpan={6}
                    style={{
                      textAlign: "center",
                      color: "var(--color-gray-500)",
                      padding: "var(--spacing-2xl)",
                    }}
                  >
                    No runs yet
                  </td>
                </tr>
              )
              : (
                recentRuns.map((run) => (
                  <tr key={run.id}>
                    <td
                      style={{
                        fontFamily: "monospace",
                        fontSize: "var(--font-size-sm)",
                        color: "var(--color-gray-600)",
                      }}
                    >
                      {run.id?.substring(0, 8)}...
                    </td>
                    <td>
                      <StatusBadge status={run.status} />
                    </td>
                    <td>
                      <DurationBadge ms={run.duration_ms} />
                    </td>
                    <td
                      style={{
                        fontSize: "var(--font-size-sm)",
                        color: "var(--color-gray-600)",
                      }}
                    >
                      {run.trigger_type}
                    </td>
                    <td
                      style={{
                        fontSize: "var(--font-size-sm)",
                        color: "var(--color-gray-600)",
                      }}
                    >
                      {formatDate(run.started_at)}
                    </td>
                    <td>
                      <Link
                        href={`/runs/${run.id}`}
                        style={{
                          fontSize: "var(--font-size-sm)",
                          color: "var(--color-primary)",
                        }}
                      >
                        Details →
                      </Link>
                    </td>
                  </tr>
                ))
              )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
