import { db } from "@/lib/db";
import { sql } from "kysely";

export async function GET() {
  try {
    // Overall statistics
    const totalRuns = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.count("id").as("count"))
      .executeTakeFirst();

    const successfulRuns = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.count("id").as("count"))
      .where("status", "=", "success")
      .executeTakeFirst();

    const failedRuns = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.count("id").as("count"))
      .where("status", "=", "failed")
      .executeTakeFirst();

    const avgDuration = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.avg("duration_ms").as("avg_duration"))
      .executeTakeFirst();

    const totalDuration = await db
      .selectFrom("pipeline_runs")
      .select(db.fn.sum("duration_ms").as("total_duration"))
      .executeTakeFirst();

    // Per-pipeline statistics
    const pipelineStats = await db
      .selectFrom("pipeline_runs as r")
      .innerJoin("pipeline_definitions as p", "p.id", "r.pipeline_id")
      .select([
        "p.id",
        "p.name",
        "p.version",
        sql<number>`count(r.id)`.as("total_runs"),
        sql<number>`count(CASE WHEN r.status = 'success' THEN 1 END)`.as(
          "success_count",
        ),
        sql<number>`avg(r.duration_ms)`.as("avg_duration"),
        sql<number>`min(r.duration_ms)`.as("min_duration"),
        sql<number>`max(r.duration_ms)`.as("max_duration"),
      ])
      .groupBy(["p.id", "p.name", "p.version"])
      .orderBy("p.name")
      .execute();

    // Latest run per pipeline (using subquery for SQLite compatibility)
    const latestRuns = await db
      .selectFrom("pipeline_runs as r")
      .innerJoin("pipeline_definitions as p", "p.id", "r.pipeline_id")
      .select([
        "p.name",
        "p.version",
        "r.id as run_id",
        "r.status",
        "r.started_at",
        "r.duration_ms",
      ])
      .where(
        "r.id",
        "in",
        db
          .selectFrom("pipeline_runs as r2")
          .select(sql<string>`MAX(r2.id)`.as("id"))
          .groupBy("r2.pipeline_id"),
      )
      .orderBy("p.name")
      .execute();

    const latestRunMap = new Map(
      latestRuns.map((r: any) => [`${r.name}@${r.version}`, r]),
    );

    // Trends: last 30 days of runs grouped by date
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      .toISOString()
      .split("T")[0];

    const trends = await db
      .selectFrom("pipeline_runs")
      .select([
        sql<string>`DATE(started_at)`.as("run_date"),
        db.fn.count("pipeline_runs.id").as("total_runs"),
        db.fn
          .count(sql`CASE WHEN status = 'success' THEN 1 END`)
          .as("success_count"),
        db.fn.avg("pipeline_runs.duration_ms").as("avg_duration"),
      ])
      .where("started_at", ">=", thirtyDaysAgo)
      .groupBy(sql`DATE(started_at)`)
      .orderBy("run_date")
      .execute();

    // Top performers (fastest average duration)
    const topPerformers = pipelineStats
      .map((s: any) => ({
        name: s.name,
        version: s.version,
        avgDuration: Number(s.avg_duration || 0),
        successCount: Number(s.success_count || 0),
        totalRuns: Number(s.total_runs || 0),
      }))
      .sort((a: any, b: any) => a.avgDuration - b.avgDuration)
      .slice(0, 5);

    // Bottom performers (slowest average duration)
    const bottomPerformers = pipelineStats
      .map((s: any) => ({
        name: s.name,
        version: s.version,
        avgDuration: Number(s.avg_duration || 0),
        successCount: Number(s.success_count || 0),
        totalRuns: Number(s.total_runs || 0),
      }))
      .sort((a: any, b: any) => b.avgDuration - a.avgDuration)
      .slice(0, 5);

    const enrichedPipelineStats = pipelineStats.map((s: any) => ({
      id: s.id,
      name: s.name,
      version: s.version,
      totalRuns: Number(s.total_runs || 0),
      successCount: Number(s.success_count || 0),
      failureCount: (Number(s.total_runs || 0) - Number(s.success_count || 0)),
      successRate: Number(s.total_runs || 0) > 0
        ? (Number(s.success_count || 0) / Number(s.total_runs || 0)) * 100
        : 0,
      avgDuration: Number(s.avg_duration || 0),
      minDuration: Number(s.min_duration || 0),
      maxDuration: Number(s.max_duration || 0),
      latestRun: latestRunMap.get(`${s.name}@${s.version}`) || null,
    }));

    return Response.json({
      overall: {
        totalRuns: Number(totalRuns?.count || 0),
        successfulRuns: Number(successfulRuns?.count || 0),
        failedRuns: Number(failedRuns?.count || 0),
        successRate: Number(totalRuns?.count || 0) > 0
          ? (Number(successfulRuns?.count || 0) /
            Number(totalRuns?.count || 0)) * 100
          : 0,
        avgDuration: Number(avgDuration?.avg_duration || 0),
        totalDuration: Number(totalDuration?.total_duration || 0),
      },
      pipelines: enrichedPipelineStats,
      trends: trends.map((t: any) => ({
        date: t.run_date,
        totalRuns: Number(t.total_runs || 0),
        successCount: Number(t.success_count || 0),
        avgDuration: Number(t.avg_duration || 0),
      })),
      topPerformers,
      bottomPerformers,
    });
  } catch (error) {
    console.error("Error fetching statistics:", error);
    return Response.json(
      { error: "Failed to fetch statistics" },
      { status: 500 },
    );
  }
}
