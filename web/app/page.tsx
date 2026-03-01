import Link from "next/link";
import { db } from "@/lib/db";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { DurationBadge } from "@/components/ui/DurationBadge";
import { formatDate } from "@/lib/format";

export const dynamic = "force-dynamic";

async function getStats() {
  const [totalPipelines, totalRuns, recentRuns, statusCounts] = await Promise
    .all([
      db
        .selectFrom("pipeline_definitions")
        .select(db.fn.count("id").as("count"))
        .executeTakeFirst(),
      db
        .selectFrom("pipeline_runs")
        .select(db.fn.count("id").as("count"))
        .executeTakeFirst(),
      db
        .selectFrom("pipeline_runs as r")
        .innerJoin("pipeline_definitions as p", "p.id", "r.pipeline_id")
        .select([
          "r.id",
          "r.status",
          "r.started_at",
          "r.duration_ms",
          "p.name as pipeline_name",
          "p.version as pipeline_version",
        ])
        .orderBy("r.started_at", "desc")
        .limit(10)
        .execute(),
      db
        .selectFrom("pipeline_runs")
        .select(["status", db.fn.count("id").as("count")])
        .groupBy("status")
        .execute(),
    ]);

  return { totalPipelines, totalRuns, recentRuns, statusCounts };
}

export default async function DashboardPage() {
  const { totalPipelines, totalRuns, recentRuns, statusCounts } =
    await getStats();

  const statusMap = Object.fromEntries(
    statusCounts.map((s) => [s.status, Number(s.count)]),
  );

  return (
    <div>
      <div className="page-header">
        <h1>Dashboard</h1>
        <p>Overview of your CI/CD pipelines and recent runs</p>
      </div>

      {/* Stats Row */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: "var(--spacing-lg)",
          marginBottom: "var(--spacing-2xl)",
        }}
      >
        {[
          {
            label: "Total Pipelines",
            value: Number(totalPipelines?.count ?? 0),
          },
          { label: "Total Runs", value: Number(totalRuns?.count ?? 0) },
          { label: "Successful Runs", value: statusMap["success"] ?? 0 },
          { label: "Failed Runs", value: statusMap["failed"] ?? 0 },
        ].map((stat) => (
          <div
            key={stat.label}
            className="card"
            style={{ padding: "var(--spacing-xl)" }}
          >
            <div
              style={{
                fontSize: "var(--font-size-2xl)",
                fontWeight: 700,
                color: "var(--color-gray-950)",
              }}
            >
              {stat.value}
            </div>
            <div
              style={{
                fontSize: "var(--font-size-sm)",
                color: "var(--color-gray-600)",
                marginTop: "var(--spacing-xs)",
              }}
            >
              {stat.label}
            </div>
          </div>
        ))}
      </div>

      {/* Quick Links */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(2, 1fr)",
          gap: "var(--spacing-lg)",
          marginBottom: "var(--spacing-2xl)",
        }}
      >
        <div
          className="card"
          style={{ padding: "var(--spacing-xl)", textAlign: "center" }}
        >
          <div
            style={{
              fontSize: "var(--font-size-md)",
              marginBottom: "var(--spacing-sm)",
              fontFamily: "monospace",
              color: "var(--color-primary)",
            }}
          >
            [#=]
          </div>
          <h3
            style={{
              fontSize: "var(--font-size-base)",
              fontWeight: 600,
              marginBottom: "var(--spacing-sm)",
            }}
          >
            Performance Metrics
          </h3>
          <p
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-lg)",
            }}
          >
            View detailed statistics and performance trends
          </p>
          <Link href="/stats" className="btn btn-sm btn-primary">
            View Statistics
          </Link>
        </div>
        <div
          className="card"
          style={{ padding: "var(--spacing-xl)", textAlign: "center" }}
        >
          <div
            style={{
              fontSize: "var(--font-size-md)",
              marginBottom: "var(--spacing-sm)",
              fontFamily: "monospace",
              color: "var(--color-primary)",
            }}
          >
            {"[|>]"}
          </div>
          <h3
            style={{
              fontSize: "var(--font-size-base)",
              fontWeight: 600,
              marginBottom: "var(--spacing-sm)",
            }}
          >
            All Pipelines
          </h3>
          <p
            style={{
              fontSize: "var(--font-size-sm)",
              color: "var(--color-gray-600)",
              marginBottom: "var(--spacing-lg)",
            }}
          >
            Browse and manage all registered pipelines
          </p>
          <Link href="/pipelines" className="btn btn-sm btn-primary">
            Go to Pipelines
          </Link>
        </div>
      </div>

      {/* Recent Runs */}
      <div className="card">
        <div
          style={{
            padding: "var(--spacing-lg) var(--spacing-xl)",
            borderBottom: "1px solid var(--color-gray-300)",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <h2 style={{ fontSize: "var(--font-size-md)", fontWeight: 600 }}>
            Recent Runs
          </h2>
          <Link
            href="/runs"
            className="btn btn-sm"
            style={{ color: "var(--color-primary)" }}
          >
            View all →
          </Link>
        </div>
        <table>
          <thead>
            <tr>
              <th>Pipeline</th>
              <th>Status</th>
              <th>Duration</th>
              <th>Started</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {recentRuns.length === 0
              ? (
                <tr>
                  <td
                    colSpan={5}
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
                    <td>
                      <Link
                        href={`/pipelines/${run.pipeline_name}/${run.pipeline_version}`}
                        style={{ fontWeight: 500 }}
                      >
                        {run.pipeline_name}
                      </Link>
                      <span
                        style={{
                          color: "var(--color-gray-500)",
                          marginLeft: "var(--spacing-sm)",
                          fontSize: "var(--font-size-sm)",
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
                        color: "var(--color-gray-600)",
                        fontSize: "var(--font-size-sm)",
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
