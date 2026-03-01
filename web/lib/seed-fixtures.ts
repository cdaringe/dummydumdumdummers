import type Database from "better-sqlite3";
import { v4 as uuidv4 } from "uuid";

export function clearAllData(db: Database.Database) {
  db.exec("DELETE FROM artifacts");
  db.exec("DELETE FROM step_traces");
  db.exec("DELETE FROM pipeline_runs");
  db.exec("DELETE FROM pipeline_definitions");
}

function generateStepLog(
  stepName: string,
  status: string,
  durationMs: number
): string {
  const ts = new Date().toISOString().replace("T", " ").substring(0, 19);
  const lines: string[] = [];
  lines.push(`[${ts}] Starting step: ${stepName}`);
  lines.push(`[${ts}] Working directory: /workspace/pipeline`);
  lines.push(`$ executing ${stepName}...`);
  lines.push("Processing...");
  if (durationMs > 1500) {
    lines.push("Intermediate progress: 50% complete");
  }
  if (status === "failed") {
    lines.push("[ERROR] Step failed with exit code 1");
  } else {
    lines.push(
      `[${ts}] Step ${stepName} completed successfully (${durationMs}ms)`
    );
  }
  return lines.join("\n");
}

interface PipelineFixture {
  name: string;
  version: string;
  description: string;
  steps: Array<{
    name: string;
    timeout_ms: number;
    depends_on: string[];
    loop?: unknown;
  }>;
  schedule?: unknown;
  trigger?: unknown;
  runs: Array<{
    status: string;
    trigger_type: string;
    duration_ms: number;
    daysAgo: number;
  }>;
  artifacts?: Array<{ name: string; content: string }>;
}

const pipelines: PipelineFixture[] = [
  {
    name: "typescript-build",
    version: "1.0.0",
    description: "Build and test a TypeScript library",
    steps: [
      { name: "install-deps", timeout_ms: 60000, depends_on: [] },
      { name: "lint", timeout_ms: 30000, depends_on: ["install-deps"] },
      { name: "compile", timeout_ms: 60000, depends_on: ["install-deps"] },
      { name: "test", timeout_ms: 120000, depends_on: ["compile"] },
      { name: "package", timeout_ms: 30000, depends_on: ["lint", "test"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 12500, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 13200, daysAgo: 1 },
      { status: "failed", trigger_type: "manual", duration_ms: 8400, daysAgo: 2 },
      { status: "success", trigger_type: "schedule", duration_ms: 11800, daysAgo: 3 },
      { status: "success", trigger_type: "manual", duration_ms: 12100, daysAgo: 5 },
    ],
    artifacts: [
      { name: "dist.tar.gz", content: "typescript build output" },
      { name: "coverage.json", content: '{"lines": 94.2, "branches": 87.1}' },
    ],
  },
  {
    name: "rust-build",
    version: "1.0.0",
    description: "Build and test a Rust library",
    steps: [
      { name: "cargo-check", timeout_ms: 120000, depends_on: [] },
      { name: "cargo-test", timeout_ms: 180000, depends_on: ["cargo-check"] },
      { name: "cargo-build", timeout_ms: 180000, depends_on: ["cargo-check"] },
      { name: "cargo-clippy", timeout_ms: 60000, depends_on: ["cargo-check"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 45000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 47500, daysAgo: 1 },
      { status: "success", trigger_type: "manual", duration_ms: 43200, daysAgo: 4 },
    ],
    artifacts: [
      { name: "librust.so", content: "rust binary output" },
    ],
  },
  {
    name: "go-build",
    version: "1.0.0",
    description: "Build and test a Go library",
    steps: [
      { name: "go-vet", timeout_ms: 30000, depends_on: [] },
      { name: "go-test", timeout_ms: 120000, depends_on: ["go-vet"] },
      { name: "go-build", timeout_ms: 60000, depends_on: ["go-vet"] },
    ],
    schedule: { Daily: { hour: 3, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 8200, daysAgo: 0 },
      { status: "failed", trigger_type: "schedule", duration_ms: 5100, daysAgo: 1 },
      { status: "success", trigger_type: "manual", duration_ms: 7800, daysAgo: 2 },
      { status: "success", trigger_type: "schedule", duration_ms: 8500, daysAgo: 3 },
    ],
    artifacts: [
      { name: "go-binary", content: "go build output" },
    ],
  },
  {
    name: "deploy-staging",
    version: "2.0.0",
    description: "Deploy application to staging environment",
    steps: [
      { name: "build", timeout_ms: 120000, depends_on: [] },
      { name: "push-image", timeout_ms: 60000, depends_on: ["build"] },
      { name: "deploy", timeout_ms: 120000, depends_on: ["push-image"] },
      { name: "health-check", timeout_ms: 30000, depends_on: ["deploy"] },
    ],
    trigger: { Webhook: { url: "/hooks/deploy" } },
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 95000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 88000, daysAgo: 2 },
      { status: "failed", trigger_type: "manual", duration_ms: 42000, daysAgo: 5 },
    ],
  },
];

export function seedFixtures(db: Database.Database) {
  const insertPipeline = db.prepare(
    `INSERT INTO pipeline_definitions (id, name, version, description, schedule, trigger, steps) VALUES (?, ?, ?, ?, ?, ?, ?)`
  );

  const insertRun = db.prepare(
    `INSERT INTO pipeline_runs (id, pipeline_id, status, trigger_type, started_at, finished_at, duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?)`
  );

  const insertTrace = db.prepare(
    `INSERT INTO step_traces (id, run_id, step_name, status, duration_ms, error_msg, log_output, sequence) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  );

  const insertArtifact = db.prepare(
    `INSERT INTO artifacts (id, run_id, name, content) VALUES (?, ?, ?, ?)`
  );

  for (const p of pipelines) {
    const pipelineId = `${p.name}@${p.version}`;

    insertPipeline.run(
      pipelineId,
      p.name,
      p.version,
      p.description,
      JSON.stringify(p.schedule ?? "NoSchedule"),
      JSON.stringify(p.trigger ?? "NoTrigger"),
      JSON.stringify(p.steps)
    );

    for (const run of p.runs) {
      const runId = uuidv4();
      const startedAt = new Date(
        Date.now() - run.daysAgo * 86_400_000
      ).toISOString();
      const finishedAt = new Date(
        Date.now() - run.daysAgo * 86_400_000 + run.duration_ms
      ).toISOString();

      insertRun.run(
        runId,
        pipelineId,
        run.status,
        run.trigger_type,
        startedAt,
        finishedAt,
        run.duration_ms
      );

      // Create step traces for each run
      let remaining = run.duration_ms;
      for (let i = 0; i < p.steps.length; i++) {
        const step = p.steps[i]!;
        const isFailed = run.status === "failed" && i === p.steps.length - 1;
        const isSkipped = run.status === "failed" && i > p.steps.length - 1;
        const stepDuration =
          i < p.steps.length - 1
            ? Math.round(remaining / (p.steps.length - i))
            : remaining;
        remaining -= stepDuration;

        const stepStatus = isSkipped ? "skipped" : isFailed ? "failed" : "ok";
        const logOutput = generateStepLog(step.name, stepStatus, stepDuration);

        insertTrace.run(
          uuidv4(),
          runId,
          step.name,
          stepStatus,
          stepDuration,
          isFailed ? "Step failed with exit code 1" : null,
          logOutput,
          i
        );
      }

      // Add artifacts to the first successful run
      if (run === p.runs[0] && run.status === "success" && p.artifacts) {
        for (const artifact of p.artifacts) {
          insertArtifact.run(uuidv4(), runId, artifact.name, artifact.content);
        }
      }
    }
  }
}
