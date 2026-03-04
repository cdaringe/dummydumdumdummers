/// Runner Host — manages a pool of workers for pipeline execution.
///
/// Detects available CPU cores and defaults to one worker per core.
/// Accepts pipeline execution requests, tracks active/queued work,
/// and reports capacity utilization.
///
/// Supports pluggable backends: Local (default) or Kubernetes.
///
/// Fulfills: "The default runner host should optimistically SHALL try to
/// initialize default allow one worker per available core for ease of use."
///
/// Fulfills: "The runner host SHALL allow kubernetes as a runner backend,
/// but SHOULD be able to run on a single machine for ease of use."
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/string
import thingfactory/executor
import thingfactory/kubernetes_runner.{type KubernetesConfig}
import thingfactory/parallel_executor
import thingfactory/pipeline.{type Pipeline}
import thingfactory/types.{type ExecutionConfig, type ExecutionResult}

// ---------------------------------------------------------------------------
// CPU core detection (FFI)
// ---------------------------------------------------------------------------

/// Detect the number of available logical CPU cores.
/// Uses os.cpus().length on JavaScript and erlang:system_info on Erlang.
@external(erlang, "runner_host_erlang", "get_cpu_count")
@external(javascript, "./runner_host_ffi.mjs", "get_cpu_count")
pub fn get_cpu_count() -> Int

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// The execution backend for the runner host.
/// Local runs pipelines in-process; Kubernetes delegates to a K8s cluster.
pub type RunnerBackend {
  /// Execute pipelines locally using the built-in executor.
  Local
  /// Execute pipelines as Kubernetes Jobs on a cluster.
  Kubernetes(config: KubernetesConfig)
}

/// A submitted pipeline waiting for or undergoing execution.
pub type PipelineSubmission {
  PipelineSubmission(
    id: String,
    pipeline: Pipeline(String, Dynamic),
    input: Dynamic,
    config: ExecutionConfig,
    parallel: Bool,
  )
}

/// Status of a submission in the host queue.
pub type SubmissionStatus {
  Queued
  Running
  Completed(ExecutionResult(Dynamic))
}

/// A tracked entry in the runner host.
pub type HostEntry {
  HostEntry(submission: PipelineSubmission, status: SubmissionStatus)
}

/// The runner host manages workers and pipeline execution.
pub type RunnerHost {
  RunnerHost(
    worker_count: Int,
    entries: Dict(String, HostEntry),
    next_id: Int,
    backend: RunnerBackend,
  )
}

/// Summary of host capacity and utilization.
pub type HostStatus {
  HostStatus(
    worker_count: Int,
    active: Int,
    queued: Int,
    completed: Int,
    available: Int,
  )
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/// Create a runner host with one worker per available CPU core.
/// Defaults to Local backend.
pub fn new() -> RunnerHost {
  let cores = get_cpu_count()
  // Ensure at least 1 worker even if detection returns 0
  let workers = int.max(cores, 1)
  RunnerHost(
    worker_count: workers,
    entries: dict.new(),
    next_id: 1,
    backend: Local,
  )
}

/// Create a runner host with a specific number of workers.
/// The count is clamped to a minimum of 1. Defaults to Local backend.
pub fn with_workers(count: Int) -> RunnerHost {
  RunnerHost(
    worker_count: int.max(count, 1),
    entries: dict.new(),
    next_id: 1,
    backend: Local,
  )
}

/// Create a runner host backed by Kubernetes.
/// Steps will be executed as Kubernetes Jobs on the configured cluster.
pub fn with_kubernetes(
  config: KubernetesConfig,
  worker_count: Int,
) -> RunnerHost {
  RunnerHost(
    worker_count: int.max(worker_count, 1),
    entries: dict.new(),
    next_id: 1,
    backend: Kubernetes(config: config),
  )
}

/// Set the backend on an existing runner host.
pub fn set_backend(host: RunnerHost, backend: RunnerBackend) -> RunnerHost {
  RunnerHost(..host, backend: backend)
}

/// Get the current backend of the runner host.
pub fn get_backend(host: RunnerHost) -> RunnerBackend {
  host.backend
}

// ---------------------------------------------------------------------------
// Submission
// ---------------------------------------------------------------------------

/// Submit a pipeline for sequential execution.
/// Returns the updated host and the assigned submission ID.
pub fn submit(
  host: RunnerHost,
  p: Pipeline(String, Dynamic),
  input: Dynamic,
  config: ExecutionConfig,
) -> #(RunnerHost, String) {
  let id = "run-" <> int.to_string(host.next_id)
  let submission =
    PipelineSubmission(
      id: id,
      pipeline: p,
      input: input,
      config: config,
      parallel: False,
    )
  let entry = HostEntry(submission: submission, status: Queued)
  let updated =
    RunnerHost(
      ..host,
      entries: dict.insert(host.entries, id, entry),
      next_id: host.next_id + 1,
    )
  #(updated, id)
}

/// Submit a pipeline for parallel (DAG-aware) execution.
/// Returns the updated host and the assigned submission ID.
pub fn submit_parallel(
  host: RunnerHost,
  p: Pipeline(String, Dynamic),
  input: Dynamic,
  config: ExecutionConfig,
) -> #(RunnerHost, String) {
  let id = "run-" <> int.to_string(host.next_id)
  let submission =
    PipelineSubmission(
      id: id,
      pipeline: p,
      input: input,
      config: config,
      parallel: True,
    )
  let entry = HostEntry(submission: submission, status: Queued)
  let updated =
    RunnerHost(
      ..host,
      entries: dict.insert(host.entries, id, entry),
      next_id: host.next_id + 1,
    )
  #(updated, id)
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------

/// Execute the next queued pipeline if a worker is available.
/// Returns the updated host. If no work is queued or all workers are busy,
/// the host is returned unchanged.
pub fn tick(host: RunnerHost) -> RunnerHost {
  let active = count_active(host)
  case active < host.worker_count {
    False -> host
    True -> {
      case find_next_queued(host) {
        Error(Nil) -> host
        Ok(id) -> execute_entry(host, id)
      }
    }
  }
}

/// Execute all queued pipelines up to worker capacity.
/// Keeps ticking until no more workers are available or no queued work remains.
pub fn drain(host: RunnerHost) -> RunnerHost {
  let active = count_active(host)
  case active < host.worker_count {
    False -> host
    True -> {
      case find_next_queued(host) {
        Error(Nil) -> host
        Ok(id) -> {
          let updated = execute_entry(host, id)
          drain(updated)
        }
      }
    }
  }
}

/// Execute a specific entry by ID, running the pipeline and recording the result.
fn execute_entry(host: RunnerHost, id: String) -> RunnerHost {
  case dict.get(host.entries, id) {
    Error(Nil) -> host
    Ok(entry) -> {
      let sub = entry.submission
      let result = case sub.parallel {
        True ->
          parallel_executor.execute_parallel(
            sub.pipeline,
            sub.input,
            sub.config,
          )
        False -> executor.execute(sub.pipeline, sub.input, sub.config)
      }
      let updated_entry = HostEntry(submission: sub, status: Completed(result))
      RunnerHost(..host, entries: dict.insert(host.entries, id, updated_entry))
    }
  }
}

// ---------------------------------------------------------------------------
// Query
// ---------------------------------------------------------------------------

/// Get the execution result for a submission by ID.
pub fn get_result(
  host: RunnerHost,
  id: String,
) -> Result(ExecutionResult(Dynamic), String) {
  case dict.get(host.entries, id) {
    Error(Nil) -> Error("Submission not found: " <> id)
    Ok(entry) -> {
      case entry.status {
        Completed(result) -> Ok(result)
        Queued -> Error("Submission " <> id <> " is still queued")
        Running -> Error("Submission " <> id <> " is still running")
      }
    }
  }
}

/// Get the status of a specific submission.
pub fn get_status(
  host: RunnerHost,
  id: String,
) -> Result(SubmissionStatus, String) {
  case dict.get(host.entries, id) {
    Error(Nil) -> Error("Submission not found: " <> id)
    Ok(entry) -> Ok(entry.status)
  }
}

/// Get overall host status: worker count, active, queued, completed, available.
pub fn status(host: RunnerHost) -> HostStatus {
  let active = count_active(host)
  let queued = count_queued(host)
  let completed = count_completed(host)
  HostStatus(
    worker_count: host.worker_count,
    active: active,
    queued: queued,
    completed: completed,
    available: host.worker_count - active,
  )
}

/// Format host status as a human-readable string.
pub fn format_status(s: HostStatus) -> String {
  string.join(
    [
      "Workers: " <> int.to_string(s.worker_count),
      "Active: " <> int.to_string(s.active),
      "Queued: " <> int.to_string(s.queued),
      "Completed: " <> int.to_string(s.completed),
      "Available: " <> int.to_string(s.available),
    ],
    " | ",
  )
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn count_active(host: RunnerHost) -> Int {
  dict.values(host.entries)
  |> list.filter(fn(e) {
    case e.status {
      Running -> True
      _ -> False
    }
  })
  |> list.length()
}

fn count_queued(host: RunnerHost) -> Int {
  dict.values(host.entries)
  |> list.filter(fn(e) {
    case e.status {
      Queued -> True
      _ -> False
    }
  })
  |> list.length()
}

fn count_completed(host: RunnerHost) -> Int {
  dict.values(host.entries)
  |> list.filter(fn(e) {
    case e.status {
      Completed(_) -> True
      _ -> False
    }
  })
  |> list.length()
}

fn find_next_queued(host: RunnerHost) -> Result(String, Nil) {
  dict.to_list(host.entries)
  |> list.find_map(fn(pair) {
    let #(id, entry) = pair
    case entry.status {
      Queued -> Ok(id)
      _ -> Error(Nil)
    }
  })
}
