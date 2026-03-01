import Link from "next/link";
import { db } from "@/lib/db";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { DurationBadge } from "@/components/ui/DurationBadge";
import { EmptyState } from "@/components/ui/EmptyState";
import { formatDate } from "@/lib/format";

export const dynamic = "force-dynamic";

type SearchParams = {
  status?: string;
  pipeline_id?: string;
  page?: string;
};

type Props = { searchParams: Promise<SearchParams> };

async function getRuns(
  status: string | undefined,
  pipelineId: string | undefined,
  page: number,
) {
  const limit = 25;
  const offset = (page - 1) * limit;

  let query = db
    .selectFrom("pipeline_runs as r")
    .innerJoin("pipeline_definitions as p", "p.id", "r.pipeline_id")
    .select([
      "r.id",
      "r.pipeline_id",
      "r.status",
      "r.trigger_type",
      "r.started_at",
      "r.finished_at",
      "r.duration_ms",
      "p.name as pipeline_name",
      "p.version as pipeline_version",
    ])
    .orderBy("r.started_at", "desc");

  if (pipelineId) query = query.where("r.pipeline_id", "=", pipelineId);
  if (status && ["running", "success", "failed"].includes(status)) {
    query = query.where("r.status", "=", status);
  }

  const [runs, countRow, pipelines] = await Promise.all([
    query.limit(limit).offset(offset).execute(),
    db
      .selectFrom("pipeline_runs")
      .$if(!!pipelineId, (q) => q.where("pipeline_id", "=", pipelineId!))
      .$if(
        !!(status && ["running", "success", "failed"].includes(status)),
        (q) => q.where("status", "=", status!),
      )
      .select(db.fn.count("id").as("count"))
      .executeTakeFirst(),
    db
      .selectFrom("pipeline_definitions")
      .select(["id", "name", "version"])
      .orderBy("name")
      .execute(),
  ]);

  return {
    runs,
    total: Number(countRow?.count ?? 0),
    pipelines,
    page,
    limit,
  };
}

export default async function RunsPage({ searchParams }: Props) {
  const sp = await searchParams;
  const status = sp.status;
  const pipelineId = sp.pipeline_id;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10));

  const { runs, total, pipelines, limit } = await getRuns(
    status,
    pipelineId,
    page,
  );
  const totalPages = Math.ceil(total / limit);

  return (
    <div>
      <div className="page-header">
        <h1>Runs</h1>
        <p>{total} total runs</p>
      </div>

      {/* Filters */}
      <form
        method="GET"
        style={{
          display: "flex",
          gap: "var(--spacing-md)",
          marginBottom: "var(--spacing-xl)",
          alignItems: "center",
        }}
      >
        <select
          name="status"
          defaultValue={status ?? ""}
          style={{
            padding: "var(--spacing-sm) var(--spacing-md)",
            borderRadius: "var(--border-radius-md)",
            border: "1px solid var(--color-gray-400)",
            fontSize: "var(--font-size-base)",
          }}
        >
          <option value="">All statuses</option>
          <option value="success">Success</option>
          <option value="failed">Failed</option>
          <option value="running">Running</option>
        </select>
        <select
          name="pipeline_id"
          defaultValue={pipelineId ?? ""}
          style={{
            padding: "var(--spacing-sm) var(--spacing-md)",
            borderRadius: "var(--border-radius-md)",
            border: "1px solid var(--color-gray-400)",
            fontSize: "var(--font-size-base)",
          }}
        >
          <option value="">All pipelines</option>
          {pipelines.map((p) => (
            <option key={p.id} value={p.id ?? ""}>
              {p.name} v{p.version}
            </option>
          ))}
        </select>
        <button
          type="submit"
          className="btn"
          style={{
            background: "var(--color-gray-200)",
            color: "var(--color-gray-800)",
          }}
        >
          Filter
        </button>
        {(status || pipelineId) && (
          <Link
            href="/runs"
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
            }}
          >
            Clear filters
          </Link>
        )}
      </form>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Run ID</th>
              <th>Pipeline</th>
              <th>Status</th>
              <th>Duration</th>
              <th>Triggered By</th>
              <th>Started</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {runs.length === 0
              ? (
                <tr>
                  <td colSpan={7}>
                    <EmptyState message="No runs found" />
                  </td>
                </tr>
              )
              : (
                runs.map((run) => (
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
                      <Link
                        href={`/pipelines/${run.pipeline_name}/${run.pipeline_version}`}
                        style={{ fontWeight: 500 }}
                      >
                        {run.pipeline_name}
                      </Link>
                      <span
                        style={{
                          marginLeft: "var(--spacing-sm)",
                          fontSize: "var(--font-size-xs)",
                          color: "var(--color-gray-500)",
                          fontFamily: "monospace",
                        }}
                      >
                        v{run.pipeline_version}
                      </span>
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

      {/* Pagination */}
      {totalPages > 1 && (
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            gap: "var(--spacing-sm)",
            marginTop: "var(--spacing-xl)",
          }}
        >
          {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
            <Link
              key={p}
              href={`/runs?page=${p}${status ? `&status=${status}` : ""}${
                pipelineId ? `&pipeline_id=${pipelineId}` : ""
              }`}
              className="btn btn-sm"
              style={{
                background: p === page
                  ? "var(--color-primary)"
                  : "var(--color-gray-200)",
                color: p === page
                  ? "var(--color-gray-100)"
                  : "var(--color-gray-800)",
              }}
            >
              {p}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
