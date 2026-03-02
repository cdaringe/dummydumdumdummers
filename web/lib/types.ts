export interface StepDefinition {
  name: string;
  timeout_ms: number;
  depends_on: string[];
  loop?: LoopConfig;
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
