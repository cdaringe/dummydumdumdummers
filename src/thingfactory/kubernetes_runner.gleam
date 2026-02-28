/// Kubernetes runner backend for executing pipeline steps as Kubernetes Jobs.
///
/// Provides configuration types, step factories, and job management
/// utilities for running pipelines on a Kubernetes cluster via kubectl.
///
/// Fulfills: "The runner host SHALL allow kubernetes as a runner backend,
/// but SHOULD be able to run on a single machine for ease of use."
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/string
import thingfactory/command_runner
import thingfactory/types

// ---------------------------------------------------------------------------
// Configuration types
// ---------------------------------------------------------------------------

/// Resource limits for a Kubernetes Job pod.
pub type ResourceLimits {
  ResourceLimits(cpu: String, memory: String)
}

/// Configuration for connecting to and running Jobs on a Kubernetes cluster.
pub type KubernetesConfig {
  KubernetesConfig(
    /// Kubernetes namespace for Job execution (default: "default").
    namespace: String,
    /// Container image to use for Job pods.
    image: String,
    /// Optional service account name for pod identity.
    service_account: String,
    /// Optional kubeconfig path (empty string uses default).
    kubeconfig: String,
    /// Resource limits for Job pods.
    limits: ResourceLimits,
    /// Resource requests for Job pods.
    requests: ResourceLimits,
    /// Number of seconds before a Job is cleaned up after completion.
    ttl_seconds: Int,
    /// Restart policy for Job pods ("Never" or "OnFailure").
    restart_policy: String,
  )
}

/// Status of a Kubernetes Job.
pub type JobStatus {
  JobPending
  JobRunning
  JobSucceeded
  JobFailed(reason: String)
  JobUnknown(raw: String)
}

// ---------------------------------------------------------------------------
// Configuration constructors
// ---------------------------------------------------------------------------

/// Create a default Kubernetes configuration.
/// Uses "default" namespace, no service account, and moderate resource limits.
pub fn default_config(image: String) -> KubernetesConfig {
  KubernetesConfig(
    namespace: "default",
    image: image,
    service_account: "",
    kubeconfig: "",
    limits: ResourceLimits(cpu: "500m", memory: "256Mi"),
    requests: ResourceLimits(cpu: "100m", memory: "64Mi"),
    ttl_seconds: 600,
    restart_policy: "Never",
  )
}

/// Set the namespace for Kubernetes Job execution.
pub fn with_namespace(
  config: KubernetesConfig,
  namespace: String,
) -> KubernetesConfig {
  KubernetesConfig(..config, namespace: namespace)
}

/// Set the service account for pod identity.
pub fn with_service_account(
  config: KubernetesConfig,
  service_account: String,
) -> KubernetesConfig {
  KubernetesConfig(..config, service_account: service_account)
}

/// Set custom kubeconfig path.
pub fn with_kubeconfig(
  config: KubernetesConfig,
  kubeconfig: String,
) -> KubernetesConfig {
  KubernetesConfig(..config, kubeconfig: kubeconfig)
}

/// Set resource limits for Job pods.
pub fn with_limits(
  config: KubernetesConfig,
  cpu: String,
  memory: String,
) -> KubernetesConfig {
  KubernetesConfig(..config, limits: ResourceLimits(cpu: cpu, memory: memory))
}

/// Set resource requests for Job pods.
pub fn with_requests(
  config: KubernetesConfig,
  cpu: String,
  memory: String,
) -> KubernetesConfig {
  KubernetesConfig(..config, requests: ResourceLimits(cpu: cpu, memory: memory))
}

/// Set the TTL for completed Job cleanup (in seconds).
pub fn with_ttl(config: KubernetesConfig, ttl_seconds: Int) -> KubernetesConfig {
  KubernetesConfig(..config, ttl_seconds: ttl_seconds)
}

// ---------------------------------------------------------------------------
// Step factory — create pipeline steps that run as Kubernetes Jobs
// ---------------------------------------------------------------------------

/// Create a pipeline step that executes a command inside a Kubernetes Job pod.
///
/// The step creates a K8s Job via kubectl, waits for completion,
/// retrieves logs, and cleans up. This is the Kubernetes equivalent
/// of `command_runner.step()`.
///
/// Example:
///   pipeline.new("k8s_build", "1.0.0")
///   |> pipeline.add_step("test",
///        kubernetes_runner.step(k8s_config, "run-tests", ["npm", "test"]))
pub fn step(
  config: KubernetesConfig,
  job_name: String,
  command: List(String),
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  fn(_ctx: types.Context, _input: Dynamic) {
    let job_spec = build_job_yaml(config, job_name, command)
    // Apply the Job manifest
    case apply_manifest(config, job_spec) {
      Error(msg) ->
        Error(types.StepFailure(
          message: "Failed to create Kubernetes Job " <> job_name <> ": " <> msg,
        ))
      Ok(_) -> {
        // Wait for the Job to complete
        case wait_for_job(config, job_name) {
          Error(msg) ->
            Error(types.StepFailure(
              message: "Kubernetes Job "
              <> job_name
              <> " failed to complete: "
              <> msg,
            ))
          Ok(status) ->
            case status {
              JobSucceeded -> {
                // Retrieve logs from the completed pod
                case get_logs(config, job_name) {
                  Ok(logs) -> Ok(dynamic.string(logs))
                  Error(_) ->
                    Ok(dynamic.string("Job " <> job_name <> " succeeded"))
                }
              }
              JobFailed(reason) ->
                Error(types.StepFailure(
                  message: "Kubernetes Job "
                  <> job_name
                  <> " failed: "
                  <> reason,
                ))
              _ ->
                Error(types.StepFailure(
                  message: "Kubernetes Job "
                  <> job_name
                  <> " in unexpected state",
                ))
            }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Job management — kubectl wrappers
// ---------------------------------------------------------------------------

/// Apply a Job manifest to the cluster via kubectl.
pub fn apply_manifest(
  config: KubernetesConfig,
  manifest: String,
) -> Result(String, String) {
  let args = kubectl_base_args(config)
  let full_args =
    list.append(args, [
      "apply",
      "-f",
      "-",
    ])
  case
    command_runner.run("sh", [
      "-c",
      "echo '"
        <> escape_single_quotes(manifest)
        <> "' | "
        <> kubectl_command(config)
        <> " "
        <> string.join(full_args, " "),
    ])
  {
    Ok(output) ->
      case output.exit_code {
        0 -> Ok(string.trim(output.stdout))
        _ ->
          Error(
            "kubectl apply failed (exit "
            <> int.to_string(output.exit_code)
            <> "): "
            <> output.stderr,
          )
      }
    Error(msg) -> Error("Failed to run kubectl: " <> msg)
  }
}

/// Wait for a Kubernetes Job to reach a terminal state.
pub fn wait_for_job(
  config: KubernetesConfig,
  job_name: String,
) -> Result(JobStatus, String) {
  let args = kubectl_base_args(config)
  let wait_args =
    list.append(args, [
      "wait",
      "--for=condition=complete",
      "--timeout=1800s",
      "job/" <> job_name,
    ])
  case command_runner.run(kubectl_command(config), wait_args) {
    Ok(output) ->
      case output.exit_code {
        0 -> Ok(JobSucceeded)
        _ -> {
          // Check if the job failed rather than timed out
          case get_job_status(config, job_name) {
            Ok(status) -> Ok(status)
            Error(msg) -> Error(msg)
          }
        }
      }
    Error(msg) -> Error("Failed to wait for job: " <> msg)
  }
}

/// Get the current status of a Kubernetes Job.
pub fn get_job_status(
  config: KubernetesConfig,
  job_name: String,
) -> Result(JobStatus, String) {
  let args = kubectl_base_args(config)
  let status_args =
    list.append(args, [
      "get",
      "job/" <> job_name,
      "-o",
      "jsonpath={.status.conditions[0].type}",
    ])
  case command_runner.run(kubectl_command(config), status_args) {
    Ok(output) ->
      case output.exit_code {
        0 -> Ok(parse_job_status(string.trim(output.stdout)))
        _ -> Error("Failed to get job status: " <> output.stderr)
      }
    Error(msg) -> Error("Failed to query job status: " <> msg)
  }
}

/// Retrieve logs from the pod(s) of a Kubernetes Job.
pub fn get_logs(
  config: KubernetesConfig,
  job_name: String,
) -> Result(String, String) {
  let args = kubectl_base_args(config)
  let log_args = list.append(args, ["logs", "job/" <> job_name, "--tail=1000"])
  case command_runner.run(kubectl_command(config), log_args) {
    Ok(output) ->
      case output.exit_code {
        0 -> Ok(string.trim(output.stdout))
        _ -> Error("Failed to get logs: " <> output.stderr)
      }
    Error(msg) -> Error("Failed to retrieve logs: " <> msg)
  }
}

/// Delete a Kubernetes Job and its associated pods.
pub fn delete_job(
  config: KubernetesConfig,
  job_name: String,
) -> Result(String, String) {
  let args = kubectl_base_args(config)
  let delete_args =
    list.append(args, [
      "delete",
      "job/" <> job_name,
      "--ignore-not-found",
    ])
  case command_runner.run(kubectl_command(config), delete_args) {
    Ok(output) ->
      case output.exit_code {
        0 -> Ok(string.trim(output.stdout))
        _ -> Error("Failed to delete job: " <> output.stderr)
      }
    Error(msg) -> Error("Failed to delete job: " <> msg)
  }
}

// ---------------------------------------------------------------------------
// Job manifest generation
// ---------------------------------------------------------------------------

/// Build a Kubernetes Job YAML manifest from the config and command.
pub fn build_job_yaml(
  config: KubernetesConfig,
  job_name: String,
  command: List(String),
) -> String {
  let command_yaml = build_command_yaml(command)
  let sa_yaml = case config.service_account {
    "" -> ""
    sa -> "\n      serviceAccountName: " <> sa
  }

  string.join(
    [
      "apiVersion: batch/v1",
      "kind: Job",
      "metadata:",
      "  name: " <> job_name,
      "  namespace: " <> config.namespace,
      "spec:",
      "  ttlSecondsAfterFinished: " <> int.to_string(config.ttl_seconds),
      "  backoffLimit: 0",
      "  template:",
      "    spec:",
      "      restartPolicy: " <> config.restart_policy,
      sa_yaml,
      "      containers:",
      "        - name: step",
      "          image: " <> config.image,
      command_yaml,
      "          resources:",
      "            requests:",
      "              cpu: " <> config.requests.cpu,
      "              memory: " <> config.requests.memory,
      "            limits:",
      "              cpu: " <> config.limits.cpu,
      "              memory: " <> config.limits.memory,
    ],
    "\n",
  )
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn kubectl_command(config: KubernetesConfig) -> String {
  case config.kubeconfig {
    "" -> "kubectl"
    path -> "kubectl --kubeconfig=" <> path
  }
}

fn kubectl_base_args(config: KubernetesConfig) -> List(String) {
  ["-n", config.namespace]
}

fn build_command_yaml(command: List(String)) -> String {
  case command {
    [] -> ""
    [program, ..args] -> {
      let cmd_line = "          command: [\"" <> program <> "\"]"
      case args {
        [] -> cmd_line
        _ -> {
          let args_items =
            list.map(args, fn(a) { "            - \"" <> a <> "\"" })
          cmd_line <> "\n          args:\n" <> string.join(args_items, "\n")
        }
      }
    }
  }
}

fn parse_job_status(raw: String) -> JobStatus {
  case string.lowercase(raw) {
    "complete" -> JobSucceeded
    "failed" -> JobFailed(reason: "Job condition: Failed")
    "" -> JobPending
    other -> JobUnknown(raw: other)
  }
}

fn escape_single_quotes(s: String) -> String {
  string.replace(s, "'", "'\\''")
}
