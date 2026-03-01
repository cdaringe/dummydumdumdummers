"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { DurationBadge } from "@/components/ui/DurationBadge";
import { formatDate } from "@/lib/format";

interface OverallStats {
  totalRuns: number;
  successfulRuns: number;
  failedRuns: number;
  successRate: number;
  avgDuration: number;
  totalDuration: number;
}

interface PipelineStatistic {
  id: string;
  name: string;
  version: string;
  totalRuns: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  avgDuration: number;
  minDuration: number;
  maxDuration: number;
  latestRun: any;
}

interface TrendData {
  date: string;
  totalRuns: number;
  successCount: number;
  avgDuration: number;
}

interface StatsData {
  overall: OverallStats;
  pipelines: PipelineStatistic[];
  trends: TrendData[];
  topPerformers: Array<{
    name: string;
    version: string;
    avgDuration: number;
    successCount: number;
    totalRuns: number;
  }>;
  bottomPerformers: Array<{
    name: string;
    version: string;
    avgDuration: number;
    successCount: number;
    totalRuns: number;
  }>;
}

export default function StatsPage() {
  const [stats, setStats] = useState<StatsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/stats")
      .then((res) => res.json())
      .then((data) => {
        setStats(data);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div
        style={{
          padding: "var(--spacing-2xl)",
          textAlign: "center",
          color: "var(--color-gray-500)",
        }}
      >
        Loading statistics...
      </div>
    );
  }

  if (!stats) {
    return (
      <div
        style={{
          padding: "var(--spacing-2xl)",
          textAlign: "center",
          color: "var(--color-gray-500)",
        }}
      >
        Failed to load statistics
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <h1>Statistics</h1>
        <p>Pipeline performance and execution metrics</p>
      </div>

      {/* Overall Stats */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "var(--spacing-lg)",
          marginBottom: "var(--spacing-2xl)",
        }}
      >
        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-gray-950)",
            }}
          >
            {stats.overall.totalRuns}
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Total Runs
          </div>
        </div>

        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-primary)",
            }}
          >
            {Math.round(stats.overall.successRate)}%
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Success Rate
          </div>
        </div>

        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-gray-950)",
            }}
          >
            {Math.round(stats.overall.avgDuration)}ms
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Avg Duration
          </div>
        </div>

        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-gray-950)",
            }}
          >
            {Math.round(stats.overall.totalDuration / 1000)}s
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Total Duration
          </div>
        </div>
      </div>

      {/* Run Counts Row */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "var(--spacing-lg)",
          marginBottom: "var(--spacing-2xl)",
        }}
      >
        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-primary)",
            }}
          >
            {stats.overall.successfulRuns}
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Successful Runs
          </div>
        </div>

        <div className="card" style={{ padding: "var(--spacing-xl)" }}>
          <div
            style={{
              fontSize: "var(--font-size-2xl)",
              fontWeight: 700,
              color: "var(--color-gray-800)",
            }}
          >
            {stats.overall.failedRuns}
          </div>
          <div
            style={{
              fontSize: "var(--font-size-base)",
              color: "var(--color-gray-600)",
              marginTop: "var(--spacing-xs)",
            }}
          >
            Failed Runs
          </div>
        </div>
      </div>

      {/* Top Performers */}
      {stats.topPerformers.length > 0 && (
        <div className="card" style={{ marginBottom: "var(--spacing-2xl)" }}>
          <div
            style={{
              padding: "var(--spacing-lg) var(--spacing-xl)",
              borderBottom: "1px solid var(--color-gray-300)",
            }}
          >
            <h2 style={{ fontSize: "var(--font-size-md)", fontWeight: 600 }}>
              Fastest Pipelines
            </h2>
          </div>
          <table>
            <thead>
              <tr>
                <th>Pipeline</th>
                <th>Runs</th>
                <th>Success Rate</th>
                <th>Avg Duration</th>
              </tr>
            </thead>
            <tbody>
              {stats.topPerformers.map((p) => (
                <tr key={`${p.name}@${p.version}`}>
                  <td>
                    <Link href={`/pipelines/${p.name}/${p.version}`}>
                      <span style={{ fontWeight: 500 }}>{p.name}</span>
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
                    </Link>
                  </td>
                  <td>{p.totalRuns}</td>
                  <td
                    style={{ color: "var(--color-primary)", fontWeight: 500 }}
                  >
                    {Math.round(
                      (p.successCount / p.totalRuns) * 100,
                    )}%
                  </td>
                  <td>
                    <DurationBadge ms={p.avgDuration} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Bottom Performers */}
      {stats.bottomPerformers.length > 0 && (
        <div className="card" style={{ marginBottom: "var(--spacing-2xl)" }}>
          <div
            style={{
              padding: "var(--spacing-lg) var(--spacing-xl)",
              borderBottom: "1px solid var(--color-gray-300)",
            }}
          >
            <h2 style={{ fontSize: "var(--font-size-md)", fontWeight: 600 }}>
              Slowest Pipelines
            </h2>
          </div>
          <table>
            <thead>
              <tr>
                <th>Pipeline</th>
                <th>Runs</th>
                <th>Success Rate</th>
                <th>Avg Duration</th>
              </tr>
            </thead>
            <tbody>
              {stats.bottomPerformers.map((p) => (
                <tr key={`${p.name}@${p.version}`}>
                  <td>
                    <Link href={`/pipelines/${p.name}/${p.version}`}>
                      <span style={{ fontWeight: 500 }}>{p.name}</span>
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
                    </Link>
                  </td>
                  <td>{p.totalRuns}</td>
                  <td
                    style={{
                      color: Number(p.successCount / p.totalRuns) < 0.5
                        ? "var(--color-gray-800)"
                        : "var(--color-primary)",
                      fontWeight: 500,
                    }}
                  >
                    {Math.round(
                      (p.successCount / p.totalRuns) * 100,
                    )}%
                  </td>
                  <td>
                    <DurationBadge ms={p.avgDuration} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* All Pipeline Statistics */}
      <div className="card" style={{ marginBottom: "var(--spacing-2xl)" }}>
        <div
          style={{
            padding: "var(--spacing-lg) var(--spacing-xl)",
            borderBottom: "1px solid var(--color-gray-300)",
          }}
        >
          <h2 style={{ fontSize: "var(--font-size-md)", fontWeight: 600 }}>
            Pipeline Statistics
          </h2>
        </div>
        <div style={{ overflowX: "auto" }}>
          <table>
            <thead>
              <tr>
                <th>Pipeline</th>
                <th>Total Runs</th>
                <th>Success Rate</th>
                <th>Avg Duration</th>
                <th>Min Duration</th>
                <th>Max Duration</th>
                <th>Latest Run</th>
              </tr>
            </thead>
            <tbody>
              {stats.pipelines.map((p) => (
                <tr key={p.id}>
                  <td>
                    <Link href={`/pipelines/${p.name}/${p.version}`}>
                      <span style={{ fontWeight: 500 }}>{p.name}</span>
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
                    </Link>
                  </td>
                  <td>{p.totalRuns}</td>
                  <td
                    style={{
                      color: p.successRate >= 80
                        ? "var(--color-primary)"
                        : p.successRate >= 50
                        ? "var(--color-gray-600)"
                        : "var(--color-gray-800)",
                      fontWeight: 500,
                    }}
                  >
                    {Math.round(p.successRate)}%
                  </td>
                  <td>
                    <DurationBadge ms={p.avgDuration} />
                  </td>
                  <td
                    style={{
                      fontSize: "var(--font-size-sm)",
                      color: "var(--color-gray-600)",
                    }}
                  >
                    {Math.round(p.minDuration)}ms
                  </td>
                  <td
                    style={{
                      fontSize: "var(--font-size-sm)",
                      color: "var(--color-gray-600)",
                    }}
                  >
                    {Math.round(p.maxDuration)}ms
                  </td>
                  <td
                    style={{
                      fontSize: "var(--font-size-sm)",
                      color: "var(--color-gray-600)",
                    }}
                  >
                    {p.latestRun ? formatDate(p.latestRun.started_at) : "Never"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Trends Chart Info */}
      {stats.trends.length > 0 && (
        <div className="card">
          <div
            style={{
              padding: "var(--spacing-lg) var(--spacing-xl)",
              borderBottom: "1px solid var(--color-gray-300)",
            }}
          >
            <h2 style={{ fontSize: "var(--font-size-md)", fontWeight: 600 }}>
              Last 30 Days Trends
            </h2>
          </div>
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Total Runs</th>
                <th>Successful</th>
                <th>Success Rate</th>
                <th>Avg Duration</th>
              </tr>
            </thead>
            <tbody>
              {stats.trends.map((t) => (
                <tr key={t.date}>
                  <td
                    style={{
                      fontFamily: "monospace",
                      fontSize: "var(--font-size-base)",
                    }}
                  >
                    {t.date}
                  </td>
                  <td>{t.totalRuns}</td>
                  <td
                    style={{ color: "var(--color-primary)", fontWeight: 500 }}
                  >
                    {t.successCount}
                  </td>
                  <td
                    style={{
                      color: (t.successCount / t.totalRuns) * 100 >= 80
                        ? "var(--color-primary)"
                        : "var(--color-gray-800)",
                      fontWeight: 500,
                    }}
                  >
                    {Math.round(
                      (t.successCount / t.totalRuns) * 100,
                    )}%
                  </td>
                  <td>
                    <DurationBadge ms={t.avgDuration} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
