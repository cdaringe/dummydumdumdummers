import type Database from "better-sqlite3";

export function clearAllData(db: Database.Database) {
  db.exec("DELETE FROM gitea_connections");
  db.exec("DELETE FROM github_connections");
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
  durationMs: number,
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
      `[${ts}] Step ${stepName} completed successfully (${durationMs}ms)`,
    );
  }
  return lines.join("\n");
}

interface StepFixture {
  name: string;
  timeout_ms: number;
  depends_on: string[];
  loop?: unknown;
  command?: string;
  working_dir?: string;
  wait_for_idle?: boolean;
  only_if_env?: string;
}

interface PipelineFixture {
  name: string;
  version: string;
  description: string;
  steps: StepFixture[];
  schedule?: unknown;
  trigger?: unknown;
  executor?: unknown;
  runs: Array<{
    status: string;
    trigger_type: string;
    duration_ms: number;
    daysAgo: number;
  }>;
  artifacts?: Array<{ name: string; content: string }>;
}

// ---------------------------------------------------------------------------
// Helper: create sequential step chain (each step depends on the previous)
// ---------------------------------------------------------------------------
function seqSteps(
  names: string[],
  timeout_ms: number,
): StepFixture[] {
  return names.map((name, i) => ({
    name,
    timeout_ms,
    depends_on: i === 0 ? [] : [names[i - 1]!],
  }));
}

// ---------------------------------------------------------------------------
// Pipeline definitions — derived from src/thingfactory/examples.gleam
//
// Every pipeline here corresponds 1:1 to a pub fn *_pipeline() in examples.gleam.
// Step names, dependency edges, timeouts, schedules, and loop configs all match
// the Gleam source exactly.
// ---------------------------------------------------------------------------

const pipelines: PipelineFixture[] = [
  // Example 1: Basic Sequential Pipeline
  {
    name: "basic_example",
    version: "1.0.0",
    description: "Simple 3-step pipeline demonstrating basic sequential flow",
    steps: seqSteps(["fetch", "transform", "output"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 1200,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 1100,
        daysAgo: 2,
      },
    ],
  },

  // Example 2: Error Handling
  {
    name: "error_example",
    version: "1.0.0",
    description: "Pipeline demonstrating error handling and step skipping",
    steps: seqSteps(["step1", "step2_fails", "step3_skipped"], 1_800_000),
    runs: [
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 800,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 750,
        daysAgo: 3,
      },
    ],
  },

  // Example 3: Testing with Mocks
  {
    name: "mockable_example",
    version: "1.0.0",
    description: "Pipeline demonstrating testability with mocked steps",
    steps: seqSteps(["fetch_from_db", "process"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 900,
        daysAgo: 0,
      },
    ],
  },

  // Example 4: Using Dependencies (injected config)
  {
    name: "dependency_example",
    version: "1.0.0",
    description: "Pipeline using injected dependencies for configuration",
    steps: seqSteps(["use_config", "use_credentials"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 600,
        daysAgo: 1,
      },
    ],
  },

  // Example 5: TypeScript Build Pipeline (REAL commands)
  {
    name: "typescript_build",
    version: "1.0.0",
    description: "Build and test a TypeScript library with npm",
    steps: seqSteps(["install_deps", "lint", "build", "test"], 120_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 12500,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 13200,
        daysAgo: 1,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 8400,
        daysAgo: 2,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 11800,
        daysAgo: 3,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 12100,
        daysAgo: 5,
      },
    ],
    artifacts: [
      { name: "dist.tar.gz", content: "typescript build output" },
      { name: "coverage.json", content: '{"lines": 94.2, "branches": 87.1}' },
    ],
  },

  // Example 6: Rust Library Build Pipeline
  {
    name: "rust_build",
    version: "1.0.0",
    description: "Build and test a Rust library with cargo",
    steps: seqSteps(
      [
        "validate_source",
        "run_tests",
        "build_release",
        "generate_docs",
        "publish_artifacts",
      ],
      180_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 45000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 47500,
        daysAgo: 1,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 43200,
        daysAgo: 4,
      },
    ],
    artifacts: [
      { name: "librust.so", content: "rust binary output" },
    ],
  },

  // Example 7: Full Application Stack
  {
    name: "full_stack_deployment",
    version: "1.0.0",
    description:
      "Complete application deployment with API, frontend, and E2E tests",
    steps: seqSteps(
      [
        "build_api",
        "build_frontend",
        "integration_tests",
        "e2e_tests",
        "deploy_staging",
      ],
      300_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 220000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 215000,
        daysAgo: 1,
      },
    ],
  },

  // Example 8: Gleam Project Build Pipeline (REAL commands)
  {
    name: "gleam_build",
    version: "1.0.0",
    description:
      "Build and test a Gleam project for both JS and Erlang targets",
    steps: seqSteps(
      [
        "validate",
        "unit_tests",
        "format_check",
        "build_javascript",
        "build_erlang",
        "publish_docs",
      ],
      150_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 35000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 38000,
        daysAgo: 1,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 18000,
        daysAgo: 3,
      },
    ],
  },

  // Example 9: Artifact Sharing Pattern
  {
    name: "artifact_sharing",
    version: "1.0.0",
    description: "Pipeline demonstrating artifact sharing across steps",
    steps: seqSteps(
      [
        "generate_config",
        "generate_secrets",
        "build_with_artifacts",
        "verify_artifacts",
      ],
      1_800_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 5000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 4800,
        daysAgo: 2,
      },
    ],
  },

  // Example 10: Go Library Build Pipeline (REAL commands)
  {
    name: "go_build",
    version: "1.0.0",
    description: "Build and test a Go library with go toolchain",
    steps: seqSteps(
      ["download_dependencies", "run_tests", "build", "lint_and_vet"],
      120_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 8200,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 5100,
        daysAgo: 1,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 7800,
        daysAgo: 2,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 8500,
        daysAgo: 3,
      },
    ],
    artifacts: [
      { name: "go-binary", content: "go build output" },
    ],
  },

  // Example 11: Custom Runner Factory
  {
    name: "custom_runner_demo",
    version: "1.0.0",
    description: "Pipeline using custom command runner step factories",
    steps: seqSteps(
      ["lint_code", "run_tests", "build_artifacts", "publish_package"],
      180_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 15000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 14500,
        daysAgo: 1,
      },
    ],
  },

  // Example 13: Parallel Execution with Dependencies (DAG)
  {
    name: "parallel_build",
    version: "1.0.0",
    description: "Parallel build with fan-out/fan-in DAG dependencies",
    steps: [
      { name: "clone", timeout_ms: 600_000, depends_on: [] },
      { name: "lint", timeout_ms: 600_000, depends_on: ["clone"] },
      { name: "test", timeout_ms: 600_000, depends_on: ["clone"] },
      { name: "build", timeout_ms: 600_000, depends_on: ["lint", "test"] },
      { name: "package", timeout_ms: 600_000, depends_on: ["build"] },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 220000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 215000,
        daysAgo: 1,
      },
    ],
  },

  // Example 13b: Diamond Dependency Pattern
  {
    name: "parallel_multi_target",
    version: "1.0.0",
    description: "Diamond dependency pattern with multi-target compilation",
    steps: [
      { name: "setup", timeout_ms: 900_000, depends_on: [] },
      { name: "compile_a", timeout_ms: 900_000, depends_on: ["setup"] },
      { name: "compile_b", timeout_ms: 900_000, depends_on: ["setup"] },
      { name: "test_a", timeout_ms: 900_000, depends_on: ["compile_a"] },
      { name: "test_b", timeout_ms: 900_000, depends_on: ["compile_b"] },
      {
        name: "integration",
        timeout_ms: 900_000,
        depends_on: ["test_a", "test_b"],
      },
      { name: "deploy", timeout_ms: 900_000, depends_on: ["integration"] },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 340000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 360000,
        daysAgo: 2,
      },
    ],
  },

  // Distributed Parallel Pipeline (Kubernetes)
  {
    name: "distributed_parallel",
    version: "1.0.0",
    description: "Distributed parallel pipeline with Kubernetes Jobs",
    steps: [
      { name: "seed", timeout_ms: 600_000, depends_on: [] },
      { name: "async_left", timeout_ms: 600_000, depends_on: ["seed"] },
      { name: "async_right", timeout_ms: 600_000, depends_on: ["seed"] },
      {
        name: "merge",
        timeout_ms: 600_000,
        depends_on: ["async_left", "async_right"],
      },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 95000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 88000,
        daysAgo: 3,
      },
    ],
  },

  // Distributed Accumulation Pipeline (Kubernetes)
  {
    name: "distributed_accumulation",
    version: "1.0.0",
    description: "Distributed accumulation pipeline with Kubernetes Jobs",
    steps: seqSteps(
      ["node_a_base", "node_b_append", "node_c_append", "node_d_publish"],
      600_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 120000,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 65000,
        daysAgo: 2,
      },
    ],
  },

  // Example 14: Retry Pattern
  {
    name: "retry_example",
    version: "1.0.0",
    description: "Pipeline demonstrating retry-on-failure loop pattern",
    steps: [
      { name: "setup", timeout_ms: 1_800_000, depends_on: [] },
      {
        name: "unreliable_operation",
        timeout_ms: 1_800_000,
        depends_on: ["setup"],
        loop: { type: "RetryOnFailure", max_attempts: 3 },
      },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 3500,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 4200,
        daysAgo: 1,
      },
    ],
  },

  // Example 15: Fixed Repeat Pattern
  {
    name: "repeat_example",
    version: "1.0.0",
    description: "Pipeline demonstrating fixed-count repetition pattern",
    steps: [
      { name: "initialize", timeout_ms: 1_800_000, depends_on: [] },
      {
        name: "gather_data",
        timeout_ms: 1_800_000,
        depends_on: ["initialize"],
        loop: { type: "FixedCount", count: 3 },
      },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 2800,
        daysAgo: 0,
      },
    ],
  },

  // Example 16: Until Success Pattern
  {
    name: "until_success_example",
    version: "1.0.0",
    description: "Pipeline demonstrating keep-trying-until-success pattern",
    steps: [
      { name: "start", timeout_ms: 1_800_000, depends_on: [] },
      {
        name: "validate_connection",
        timeout_ms: 1_800_000,
        depends_on: ["start"],
        loop: { type: "UntilSuccess", max_attempts: 5 },
      },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 5200,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 12000,
        daysAgo: 1,
      },
    ],
  },

  // Example 17: Simple Pub-Sub Messaging
  {
    name: "simple_messaging_example",
    version: "1.0.0",
    description: "Simple pub-sub messaging between pipeline steps",
    steps: seqSteps(["publisher", "subscriber"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 1500,
        daysAgo: 0,
      },
    ],
  },

  // Example 18: Multi-Topic Messaging
  {
    name: "multi_topic_messaging_example",
    version: "1.0.0",
    description: "Multi-topic message coordination between steps",
    steps: seqSteps(["task_a", "task_b", "coordinator"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 2200,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 2100,
        daysAgo: 2,
      },
    ],
  },

  // Example 19: Event-Driven Workflow
  {
    name: "event_driven_example",
    version: "1.0.0",
    description: "Event-driven workflow with conditional step execution",
    steps: seqSteps(
      ["event_producer", "event_handler_1", "event_handler_2"],
      1_800_000,
    ),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 3000,
        daysAgo: 0,
      },
    ],
  },

  // Example 20: Dogfood Pipeline (builds thingfactory itself)
  {
    name: "dogfood",
    version: "1.0.0",
    description: "Self-building pipeline for thingfactory (dogfooding)",
    steps: [
      { name: "gleam_check", timeout_ms: 300_000, depends_on: [] },
      { name: "gleam_format", timeout_ms: 300_000, depends_on: [] },
      {
        name: "gleam_build_js",
        timeout_ms: 300_000,
        depends_on: ["gleam_check", "gleam_format"],
      },
      {
        name: "gleam_build_erl",
        timeout_ms: 300_000,
        depends_on: ["gleam_check", "gleam_format"],
      },
      { name: "web_install", timeout_ms: 300_000, depends_on: [] },
      { name: "web_build", timeout_ms: 300_000, depends_on: ["web_install"] },
      {
        name: "verify",
        timeout_ms: 300_000,
        depends_on: ["gleam_build_js", "gleam_build_erl", "web_build"],
      },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 185000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 190000,
        daysAgo: 1,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 78000,
        daysAgo: 3,
      },
    ],
  },

  // Example 21: Kubernetes Build Pipeline
  {
    name: "kubernetes_build",
    version: "1.0.0",
    description: "Kubernetes-backed build pipeline with K8s Jobs",
    steps: [
      { name: "install", timeout_ms: 600_000, depends_on: [] },
      { name: "lint", timeout_ms: 600_000, depends_on: ["install"] },
      { name: "test", timeout_ms: 600_000, depends_on: ["install"] },
      { name: "build", timeout_ms: 600_000, depends_on: ["lint", "test"] },
    ],
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 320000,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "manual",
        duration_ms: 180000,
        daysAgo: 2,
      },
    ],
  },

  // Scheduling: Daily Health Check (9:00 AM UTC)
  {
    name: "daily_health_check",
    version: "1.0.0",
    description: "Daily infrastructure health checks at 9:00 AM UTC",
    steps: seqSteps(
      ["check_api", "check_database", "check_cache"],
      1_800_000,
    ),
    schedule: { Daily: { hour: 9, minute: 0 } },
    runs: [
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 4500,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 4200,
        daysAgo: 1,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 4800,
        daysAgo: 2,
      },
    ],
  },

  // Scheduling: Weekly Backup (Friday 2:00 AM UTC)
  {
    name: "weekly_backup",
    version: "1.0.0",
    description: "Weekly database backup every Friday at 2:00 AM UTC",
    steps: seqSteps(
      ["prepare_snapshot", "upload_to_storage", "verify_backup"],
      1_800_000,
    ),
    schedule: { Weekly: { day: 4, hour: 2, minute: 0 } },
    runs: [
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 95000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 88000,
        daysAgo: 7,
      },
    ],
  },

  // Scheduling: Monthly Reporting (1st and 15th, 8:00 AM UTC)
  {
    name: "monthly_reporting",
    version: "1.0.0",
    description: "Monthly reporting on the 1st and 15th at 8:00 AM UTC",
    steps: seqSteps(
      ["collect_metrics", "generate_report", "send_to_stakeholders"],
      1_800_000,
    ),
    schedule: { Monthly: { days: [1, 15], hour: 8, minute: 0 } },
    runs: [
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 245000,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 232000,
        daysAgo: 15,
      },
    ],
  },

  // Scheduling: Frequent Health Check (every 5 minutes)
  {
    name: "frequent_health_check",
    version: "1.0.0",
    description: "Frequent service health check every 5 minutes",
    steps: seqSteps(["ping_service", "record_metrics"], 1_800_000),
    schedule: { Interval: { interval_ms: 300_000 } },
    runs: [
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 1200,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 1100,
        daysAgo: 0,
      },
    ],
  },

  // Scheduling: Cron Cleanup (weekdays at 11:00 PM UTC)
  {
    name: "cron_cleanup",
    version: "1.0.0",
    description: "Cron-based cleanup running weekdays at 11:00 PM UTC",
    steps: seqSteps(
      ["cleanup_temp_files", "vacuum_database", "archive_logs"],
      1_800_000,
    ),
    schedule: { Cron: { expression: "0 23 * * 1-5" } },
    runs: [
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 520000,
        daysAgo: 0,
      },
      {
        status: "failed",
        trigger_type: "schedule",
        duration_ms: 410000,
        daysAgo: 1,
      },
      {
        status: "success",
        trigger_type: "schedule",
        duration_ms: 510000,
        daysAgo: 2,
      },
    ],
  },

  // Example 22: Queue-Based Worker Pipeline (PULL Model)
  {
    name: "queue_worker",
    version: "1.0.0",
    description: "Queue-based PULL model worker pipeline",
    steps: seqSteps(["produce_work", "worker", "summarize"], 1_800_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 3800,
        daysAgo: 0,
      },
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 3500,
        daysAgo: 1,
      },
    ],
  },

  // Scenario 67: Label-based executor selection — matching labels (standard)
  {
    name: "labeled_executor_standard",
    version: "1.0.0",
    description:
      'Pipeline using label-based executor selection (requires "standard" label)',
    executor: { kind: "labeled", requiredLabels: ["standard"] },
    steps: seqSteps(["prepare", "run"], 60_000),
    runs: [
      {
        status: "success",
        trigger_type: "manual",
        duration_ms: 800,
        daysAgo: 0,
      },
    ],
  },

  // Scenario 67: Label-based executor selection — unmatched labels (gpu)
  {
    name: "labeled_executor_gpu",
    version: "1.0.0",
    description:
      'Pipeline requiring GPU-capable executor (requires "gpu" label, no match in default pool)',
    executor: { kind: "labeled", requiredLabels: ["gpu"] },
    steps: seqSteps(["train_model"], 300_000),
    runs: [],
  },

  // Self-deploy pipeline — triggered by Gitea webhook on push
  {
    name: "thingfactory_deploy",
    version: "1.0.0",
    description: "Self-update pipeline: pull, build, wait for idle, restart",
    steps: [
      {
        name: "git_pull",
        timeout_ms: 120_000,
        depends_on: [],
        command: "git fetch origin main && git reset --hard origin/main",
      },
      {
        name: "docker_build",
        timeout_ms: 600_000,
        depends_on: ["git_pull"],
        command: "docker compose build web",
      },
      {
        name: "wait_for_idle",
        timeout_ms: 300_000,
        depends_on: ["docker_build"],
        command: "echo 'Proceeding to restart...'",
        wait_for_idle: true,
        only_if_env: "THINGFACTORY_IS_DEPLOY_SERVER",
      },
      {
        name: "restart",
        timeout_ms: 60_000,
        depends_on: ["wait_for_idle"],
        command:
          "docker run --rm -d -v /var/run/docker.sock:/var/run/docker.sock -v $THINGFACTORY_HOST_SOURCE_DIR:/workspace -w /workspace docker:cli sh -c 'sleep 5 && docker compose up -d --build web'",
        only_if_env: "THINGFACTORY_IS_DEPLOY_SERVER",
      },
    ],
    executor: { kind: "local" },
    trigger: { Gitea: { repo: "cdaringe/thingfactory", events: ["push"] } },
    runs: [],
  },
];

/**
 * Generate a deterministic UUID-format ID from a counter.
 * All module instances (Next.js/Turbopack creates separate ones for pages vs API routes)
 * will produce the same IDs because the fixture data and insertion order are identical,
 * preventing cross-module UUID mismatches that cause 404s in E2E tests.
 */
function makeId(prefix: string, counter: number): string {
  const p = prefix.padStart(8, "0").slice(-8);
  const c = counter.toString(16).padStart(12, "0");
  return `${p}-0000-4000-a000-${c}`;
}

export function seedFixtures(db: Database.Database) {
  // Counters reset per call so IDs are deterministic across module instances
  let runCounter = 0;
  let traceCounter = 0;
  let artifactCounter = 0;

  const insertPipeline = db.prepare(
    `INSERT INTO pipeline_definitions (id, name, version, description, schedule, trigger, steps, executor) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );

  const insertRun = db.prepare(
    `INSERT INTO pipeline_runs (id, pipeline_id, status, trigger_type, started_at, finished_at, duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?)`,
  );

  const insertTrace = db.prepare(
    `INSERT INTO step_traces (id, run_id, step_name, status, duration_ms, error_msg, log_output, sequence) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );

  const insertArtifact = db.prepare(
    `INSERT INTO artifacts (id, run_id, name, content) VALUES (?, ?, ?, ?)`,
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
      JSON.stringify(p.steps),
      JSON.stringify(p.executor ?? { kind: "local" }),
    );

    for (const run of p.runs) {
      const runId = makeId("0000aa00", ++runCounter);
      const startedAt = new Date(
        Date.now() - run.daysAgo * 86_400_000,
      ).toISOString();
      const finishedAt = new Date(
        Date.now() - run.daysAgo * 86_400_000 + run.duration_ms,
      ).toISOString();

      insertRun.run(
        runId,
        pipelineId,
        run.status,
        run.trigger_type,
        startedAt,
        finishedAt,
        run.duration_ms,
      );

      // Create step traces for each run
      let remaining = run.duration_ms;
      for (let i = 0; i < p.steps.length; i++) {
        const step = p.steps[i]!;
        const isFailed = run.status === "failed" && i === p.steps.length - 1;
        const isSkipped = run.status === "failed" && i > p.steps.length - 1;
        const stepDuration = i < p.steps.length - 1
          ? Math.round(remaining / (p.steps.length - i))
          : remaining;
        remaining -= stepDuration;

        const stepStatus = isSkipped ? "skipped" : isFailed ? "failed" : "ok";
        const logOutput = generateStepLog(step.name, stepStatus, stepDuration);

        insertTrace.run(
          makeId("0000bb00", ++traceCounter),
          runId,
          step.name,
          stepStatus,
          stepDuration,
          isFailed ? "Step failed with exit code 1" : null,
          logOutput,
          i,
        );
      }

      // Add artifacts to the first successful run
      if (run === p.runs[0] && run.status === "success" && p.artifacts) {
        for (const artifact of p.artifacts) {
          insertArtifact.run(
            makeId("0000cc00", ++artifactCounter),
            runId,
            artifact.name,
            artifact.content,
          );
        }
      }
    }
  }
}
