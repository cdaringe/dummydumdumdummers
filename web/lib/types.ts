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
  /** Capability labels this executor instance advertises (e.g. ["linux", "standard"]). */
  labels?: string[];
}

export interface DockerExecutorConfig {
  kind: "docker";
  /** Docker image to run commands in. */
  image: string;
  /** Extra volume mounts (host:container format). */
  volumes?: string[];
  /** Capability labels this executor instance advertises. */
  labels?: string[];
}

export type ExecutorConfig = LocalExecutorConfig | DockerExecutorConfig;

/**
 * Label-based executor requirement — stored in pipeline.executor when the
 * pipeline author wants the system to select any executor that satisfies all
 * required labels rather than pinning to a specific executor kind.
 */
export interface LabeledExecutorRequirement {
  kind: "labeled";
  /** All of these labels must be present on the chosen executor instance. */
  requiredLabels: string[];
}

/** What can be stored in the pipeline_definitions.executor column. */
export type PipelineExecutor = ExecutorConfig | LabeledExecutorRequirement;

/** A named executor instance registered in the service executor pool. */
export interface ExecutorInstance {
  id: string;
  /** Labels advertising this instance's capabilities (e.g. ["docker", "gpu", "linux"]). */
  labels: string[];
  /** The concrete executor configuration used when this instance is selected. */
  config: ExecutorConfig;
}
