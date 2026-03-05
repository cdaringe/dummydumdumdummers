export interface StepDefinition {
  name: string;
  timeout_ms: number;
  depends_on: string[];
  loop?: LoopConfig;
  /** Shell command to execute. When absent, the simulation path is used. */
  command?: string;
  /** Working directory for the command. Defaults to THINGFACTORY_SOURCE_DIR or /app. */
  working_dir?: string;
  /** Poll pipeline_runs until no other runs are "running" before executing. */
  wait_for_idle?: boolean;
  /** Skip this step (status "skipped") if this env var is not truthy. */
  only_if_env?: string;
}

export type LoopConfig =
  | { type: "FixedCount"; count: number }
  | { type: "RetryOnFailure"; max_attempts: number }
  | { type: "UntilSuccess"; max_attempts: number };

export type ScheduleConfig =
  | "NoSchedule"
  | { Daily: { hour: number; minute: number } }
  | { Weekly: { day: number; hour: number; minute: number } }
  | { Monthly: { day: number; hour: number; minute: number } }
  | { Interval: { seconds: number } }
  | { Cron: { expression: string } };

export type TriggerConfig =
  | "NoTrigger"
  | { Webhook: { url: string } }
  | { GitHub: { repo: string; events: string[] } }
  | { Gitea: { repo: string; events: string[] } }
  | { GitLab: { project: string; events: string[] } }
  | { Custom: { name: string } };

export interface StepTrace {
  id: string;
  run_id: string;
  step_name: string;
  status: string;
  duration_ms: number;
  error_msg: string | null;
  log_output: string | null;
  sequence: number;
  created_at: string;
}

export interface Artifact {
  id: string;
  run_id: string;
  name: string;
  content: string;
  created_at: string;
}

// ---------------------------------------------------------------------------
// Executor configuration — determines how step commands are run
// ---------------------------------------------------------------------------

export type ExecutorKind = "local" | "docker";

export interface LocalExecutorConfig {
  kind: "local";
}

export interface DockerExecutorConfig {
  kind: "docker";
  /** Docker image to run commands in. */
  image: string;
  /** Extra volume mounts (host:container format). */
  volumes?: string[];
}

export type ExecutorConfig = LocalExecutorConfig | DockerExecutorConfig;
