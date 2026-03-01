import type Database from "better-sqlite3";
import { v4 as uuidv4 } from "uuid";

export function clearAllData(db: Database.Database) {
  db.exec("DELETE FROM artifacts");
  db.exec("DELETE FROM step_traces");
  db.exec("DELETE FROM pipeline_runs");
  db.exec("DELETE FROM pipeline_definitions");
}

export function seedFixturesIfEmpty(db: Database.Database) {
  const row = db
    .prepare("SELECT COUNT(*) as count FROM pipeline_definitions")
    .get() as { count: number } | undefined;
  if ((row?.count ?? 0) === 0) {
    seedFixtures(db);
  }
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
    name: "typescript_build",
    version: "1.0.0",
    description: "Build and test a TypeScript library",
    steps: [
      { name: "checkout", timeout_ms: 15000, depends_on: [] },
      { name: "install-deps", timeout_ms: 60000, depends_on: ["checkout"] },
      { name: "lint", timeout_ms: 30000, depends_on: ["install-deps"] },
      { name: "compile", timeout_ms: 60000, depends_on: ["install-deps"] },
      { name: "unit_tests", timeout_ms: 120000, depends_on: ["compile"] },
      { name: "package", timeout_ms: 30000, depends_on: ["lint", "unit_tests"] },
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
    name: "rust_build",
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
    name: "go_build",
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
    name: "deploy_staging",
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
  {
    name: "parallel_build",
    version: "1.0.0",
    description: "Parallel multi-platform build demonstrating DAG fan-out/fan-in",
    steps: [
      { name: "setup", timeout_ms: 20000, depends_on: [] },
      { name: "build-frontend", timeout_ms: 90000, depends_on: ["setup"] },
      { name: "build-backend", timeout_ms: 120000, depends_on: ["setup"] },
      { name: "run-tests", timeout_ms: 180000, depends_on: ["build-frontend", "build-backend"] },
      { name: "deploy", timeout_ms: 60000, depends_on: ["run-tests"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 220000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 215000, daysAgo: 1 },
    ],
  },
  {
    name: "python_build",
    version: "1.0.0",
    description: "Build and test a Python package",
    steps: [
      { name: "lint", timeout_ms: 30000, depends_on: [] },
      { name: "test", timeout_ms: 120000, depends_on: ["lint"] },
      { name: "package", timeout_ms: 45000, depends_on: ["test"] },
    ],
    schedule: { Daily: { hour: 6, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 9800, daysAgo: 0 },
      { status: "success", trigger_type: "manual", duration_ms: 10200, daysAgo: 1 },
    ],
  },
  {
    name: "java_build",
    version: "3.1.0",
    description: "Maven build and test for Java service",
    steps: [
      { name: "compile", timeout_ms: 120000, depends_on: [] },
      { name: "test", timeout_ms: 180000, depends_on: ["compile"] },
      { name: "package", timeout_ms: 60000, depends_on: ["test"] },
      { name: "publish", timeout_ms: 45000, depends_on: ["package"] },
    ],
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 320000, daysAgo: 0 },
      { status: "failed", trigger_type: "webhook", duration_ms: 180000, daysAgo: 2 },
    ],
  },
  {
    name: "node_ci",
    version: "1.0.0",
    description: "Node.js CI pipeline",
    steps: [
      { name: "install", timeout_ms: 60000, depends_on: [] },
      { name: "test", timeout_ms: 120000, depends_on: ["install"] },
      { name: "lint", timeout_ms: 30000, depends_on: ["install"] },
    ],
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 15000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 14500, daysAgo: 1 },
      { status: "success", trigger_type: "webhook", duration_ms: 16200, daysAgo: 2 },
    ],
  },
  {
    name: "docker_build",
    version: "1.2.0",
    description: "Build and publish Docker image",
    steps: [
      { name: "build", timeout_ms: 180000, depends_on: [] },
      { name: "tag", timeout_ms: 10000, depends_on: ["build"] },
      { name: "push", timeout_ms: 60000, depends_on: ["tag"] },
    ],
    trigger: { Webhook: { url: "/hooks/docker" } },
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 48000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 52000, daysAgo: 3 },
    ],
  },
  {
    name: "integration_tests",
    version: "1.0.0",
    description: "Full integration test suite",
    steps: [
      { name: "setup", timeout_ms: 60000, depends_on: [] },
      { name: "run", timeout_ms: 600000, depends_on: ["setup"] },
      { name: "cleanup", timeout_ms: 30000, depends_on: ["run"] },
    ],
    schedule: { Daily: { hour: 2, minute: 30 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 520000, daysAgo: 0 },
      { status: "failed", trigger_type: "schedule", duration_ms: 310000, daysAgo: 1 },
    ],
  },
  {
    name: "deploy_production",
    version: "2.0.0",
    description: "Production deployment pipeline with approval gates",
    steps: [
      { name: "validate", timeout_ms: 60000, depends_on: [] },
      { name: "backup", timeout_ms: 120000, depends_on: ["validate"] },
      { name: "deploy", timeout_ms: 180000, depends_on: ["backup"] },
      { name: "smoke-test", timeout_ms: 60000, depends_on: ["deploy"] },
      { name: "notify", timeout_ms: 10000, depends_on: ["smoke-test"] },
    ],
    trigger: { Webhook: { url: "/hooks/production" } },
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 340000, daysAgo: 0 },
      { status: "success", trigger_type: "manual", duration_ms: 360000, daysAgo: 7 },
    ],
  },
  {
    name: "data_pipeline",
    version: "1.0.0",
    description: "ETL data processing pipeline",
    steps: [
      { name: "extract", timeout_ms: 300000, depends_on: [] },
      { name: "transform", timeout_ms: 600000, depends_on: ["extract"] },
      { name: "validate", timeout_ms: 120000, depends_on: ["transform"] },
      { name: "load", timeout_ms: 300000, depends_on: ["validate"] },
    ],
    schedule: { Daily: { hour: 1, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 1100000, daysAgo: 0 },
      { status: "success", trigger_type: "schedule", duration_ms: 980000, daysAgo: 1 },
    ],
  },
  {
    name: "security_scan",
    version: "1.0.0",
    description: "Security vulnerability scanning",
    steps: [
      { name: "sast", timeout_ms: 300000, depends_on: [] },
      { name: "dast", timeout_ms: 600000, depends_on: ["sast"] },
      { name: "report", timeout_ms: 30000, depends_on: ["dast"] },
    ],
    schedule: { Daily: { hour: 4, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 720000, daysAgo: 0 },
      { status: "success", trigger_type: "schedule", duration_ms: 680000, daysAgo: 1 },
    ],
  },
  {
    name: "performance_tests",
    version: "1.0.0",
    description: "Load and performance testing suite",
    steps: [
      { name: "load-test", timeout_ms: 600000, depends_on: [] },
      { name: "stress-test", timeout_ms: 600000, depends_on: ["load-test"] },
      { name: "report", timeout_ms: 30000, depends_on: ["stress-test"] },
    ],
    schedule: { Daily: { hour: 3, minute: 30 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 980000, daysAgo: 0 },
    ],
  },
  {
    name: "e2e_tests",
    version: "1.0.0",
    description: "End-to-end browser test suite",
    steps: [
      { name: "setup", timeout_ms: 60000, depends_on: [] },
      { name: "run", timeout_ms: 300000, depends_on: ["setup"] },
      { name: "teardown", timeout_ms: 30000, depends_on: ["run"] },
    ],
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 280000, daysAgo: 0 },
      { status: "failed", trigger_type: "webhook", duration_ms: 145000, daysAgo: 1 },
    ],
  },
  {
    name: "release",
    version: "1.0.0",
    description: "Release pipeline for versioned artifacts",
    steps: [
      { name: "tag", timeout_ms: 10000, depends_on: [] },
      { name: "build", timeout_ms: 120000, depends_on: ["tag"] },
      { name: "sign", timeout_ms: 30000, depends_on: ["build"] },
      { name: "publish", timeout_ms: 60000, depends_on: ["sign"] },
    ],
    trigger: { Webhook: { url: "/hooks/release" } },
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 185000, daysAgo: 0 },
      { status: "success", trigger_type: "manual", duration_ms: 190000, daysAgo: 14 },
    ],
  },
  {
    name: "database_migration",
    version: "1.0.0",
    description: "Database schema migration pipeline",
    steps: [
      { name: "validate", timeout_ms: 30000, depends_on: [] },
      { name: "run", timeout_ms: 120000, depends_on: ["validate"] },
      { name: "verify", timeout_ms: 60000, depends_on: ["run"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 95000, daysAgo: 0 },
      { status: "success", trigger_type: "manual", duration_ms: 88000, daysAgo: 7 },
    ],
  },
  {
    name: "frontend_build",
    version: "1.0.0",
    description: "Frontend build and asset deployment",
    steps: [
      { name: "install", timeout_ms: 60000, depends_on: [] },
      { name: "lint", timeout_ms: 30000, depends_on: ["install"] },
      { name: "build", timeout_ms: 120000, depends_on: ["install"] },
      { name: "deploy", timeout_ms: 45000, depends_on: ["build", "lint"] },
    ],
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 145000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 138000, daysAgo: 1 },
      { status: "failed", trigger_type: "webhook", duration_ms: 78000, daysAgo: 3 },
    ],
  },
  {
    name: "infrastructure",
    version: "1.0.0",
    description: "Terraform infrastructure provisioning",
    steps: [
      { name: "plan", timeout_ms: 120000, depends_on: [] },
      { name: "apply", timeout_ms: 300000, depends_on: ["plan"] },
      { name: "verify", timeout_ms: 60000, depends_on: ["apply"] },
      { name: "notify", timeout_ms: 10000, depends_on: ["verify"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 385000, daysAgo: 0 },
    ],
  },
  {
    name: "ml_train",
    version: "1.0.0",
    description: "Machine learning model training pipeline",
    steps: [
      { name: "prepare", timeout_ms: 600000, depends_on: [] },
      { name: "train", timeout_ms: 3600000, depends_on: ["prepare"] },
      { name: "evaluate", timeout_ms: 300000, depends_on: ["train"] },
      { name: "deploy", timeout_ms: 120000, depends_on: ["evaluate"] },
    ],
    schedule: { Daily: { hour: 0, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 4200000, daysAgo: 0 },
      { status: "success", trigger_type: "schedule", duration_ms: 4350000, daysAgo: 1 },
    ],
    artifacts: [
      { name: "model.pkl", content: "trained model weights" },
      { name: "metrics.json", content: '{"accuracy": 0.94, "f1": 0.91}' },
    ],
  },
  {
    name: "report_gen",
    version: "1.0.0",
    description: "Automated report generation and distribution",
    steps: [
      { name: "collect", timeout_ms: 120000, depends_on: [] },
      { name: "generate", timeout_ms: 180000, depends_on: ["collect"] },
      { name: "send", timeout_ms: 30000, depends_on: ["generate"] },
    ],
    schedule: { Daily: { hour: 8, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 245000, daysAgo: 0 },
      { status: "success", trigger_type: "schedule", duration_ms: 232000, daysAgo: 1 },
    ],
  },
  {
    name: "nightly_ci",
    version: "1.0.0",
    description: "Comprehensive nightly CI run",
    steps: [
      { name: "checkout", timeout_ms: 15000, depends_on: [] },
      { name: "build", timeout_ms: 180000, depends_on: ["checkout"] },
      { name: "unit-test", timeout_ms: 120000, depends_on: ["build"] },
      { name: "integration-test", timeout_ms: 300000, depends_on: ["unit-test"] },
      { name: "report", timeout_ms: 30000, depends_on: ["integration-test"] },
    ],
    schedule: { Daily: { hour: 23, minute: 0 } },
    runs: [
      { status: "success", trigger_type: "schedule", duration_ms: 520000, daysAgo: 0 },
      { status: "failed", trigger_type: "schedule", duration_ms: 410000, daysAgo: 1 },
      { status: "success", trigger_type: "schedule", duration_ms: 510000, daysAgo: 2 },
    ],
  },
  {
    name: "api_tests",
    version: "1.0.0",
    description: "REST API contract and integration tests",
    steps: [
      { name: "mock-server", timeout_ms: 30000, depends_on: [] },
      { name: "test", timeout_ms: 180000, depends_on: ["mock-server"] },
      { name: "cleanup", timeout_ms: 15000, depends_on: ["test"] },
    ],
    runs: [
      { status: "success", trigger_type: "webhook", duration_ms: 185000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 192000, daysAgo: 1 },
    ],
  },
  {
    name: "mobile_build",
    version: "1.0.0",
    description: "iOS and Android mobile app build pipeline",
    steps: [
      { name: "ios", timeout_ms: 600000, depends_on: [] },
      { name: "android", timeout_ms: 480000, depends_on: [] },
      { name: "sign", timeout_ms: 60000, depends_on: ["ios", "android"] },
      { name: "distribute", timeout_ms: 120000, depends_on: ["sign"] },
    ],
    runs: [
      { status: "success", trigger_type: "manual", duration_ms: 720000, daysAgo: 0 },
      { status: "success", trigger_type: "webhook", duration_ms: 680000, daysAgo: 3 },
    ],
    artifacts: [
      { name: "app.ipa", content: "iOS app bundle" },
      { name: "app.apk", content: "Android app bundle" },
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
