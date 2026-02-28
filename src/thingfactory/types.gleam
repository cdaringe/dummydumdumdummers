/// Core types for the Thingfactory pipeline system.
///
/// All error types are explicit and typed — no silent failures (QR-2).
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import thingfactory/message_store.{type MessageStore}
import thingfactory/secret_manager.{type SecretStore}

// ---------------------------------------------------------------------------
// Identity / Pipeline IDs
// ---------------------------------------------------------------------------

/// Uniquely identifies a pipeline by name and semantic version.
pub type PipelineId {
  PipelineId(name: String, version: String)
}

// ---------------------------------------------------------------------------
// Step errors
// ---------------------------------------------------------------------------

/// Errors that can occur within a single step.
pub type StepError {
  /// The step returned a failure with a human-readable message.
  StepFailure(message: String)
  /// The step exceeded its configured timeout.
  StepTimeout(step: String, limit_ms: Int)
  /// A step attempted to read an artifact key that was never written.
  ArtifactNotFound(key: String)
}

// ---------------------------------------------------------------------------
// Pipeline errors
// ---------------------------------------------------------------------------

/// Errors that can occur at the pipeline level.
pub type PipelineError {
  /// A step error propagated to the pipeline level.
  StepError(step_name: String, error: StepError)
  /// The pipeline could not be loaded from the registry.
  LoadError(reason: String)
  /// Runtime validation failed before the first step executed.
  ValidationError(reason: String)
}

// ---------------------------------------------------------------------------
// Step result
// ---------------------------------------------------------------------------

/// The result of executing a single step.
pub type StepResult(a) =
  Result(a, StepError)

/// The result of executing a full pipeline.
pub type PipelineResult(a) =
  Result(a, PipelineError)

// ---------------------------------------------------------------------------
// Execution config
// ---------------------------------------------------------------------------

/// A named dependency binding supplied to the execution engine.
pub type Binding {
  Binding(name: String, value: Dynamic)
}

/// Configuration for a pipeline execution run.
pub type ExecutionConfig {
  ExecutionConfig(
    default_step_timeout_ms: Int,
    dependency_bindings: List(Binding),
  )
}

/// Returns a default ExecutionConfig with a 30-minute timeout and no bindings.
pub fn default_config() -> ExecutionConfig {
  ExecutionConfig(default_step_timeout_ms: 1_800_000, dependency_bindings: [])
}

// ---------------------------------------------------------------------------
// Step context (passed to every step function)
// ---------------------------------------------------------------------------

/// The context available to every step during execution.
/// Contains the artifact store, message bus, injected dependencies, and secrets.
pub type Context {
  Context(
    artifact_store: Dict(String, Dynamic),
    message_store: MessageStore,
    deps: Dict(String, Dynamic),
    secret_store: SecretStore,
  )
}

/// Read a dependency from the context by name.
/// Returns Error(StepFailure) if the dependency is not present.
pub fn get_dep(ctx: Context, name: String) -> StepResult(Dynamic) {
  case dict.get(ctx.deps, name) {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error(StepFailure("dependency not found: " <> name))
  }
}

/// Publish a message to the message bus on a specific topic.
/// Returns an updated Context with the message published.
pub fn publish_message(ctx: Context, topic: String, payload: Dynamic) -> Context {
  Context(
    artifact_store: ctx.artifact_store,
    message_store: message_store.publish(ctx.message_store, topic, payload),
    deps: ctx.deps,
    secret_store: ctx.secret_store,
  )
}

/// Retrieve all messages published on a given topic.
pub fn get_messages(ctx: Context, topic: String) -> List(message_store.Message) {
  message_store.get_messages(ctx.message_store, topic)
}

// ---------------------------------------------------------------------------
// Observability — step trace (q7 resolution)
// ---------------------------------------------------------------------------

/// The execution status of a single step in a trace.
pub type StepStatus {
  StepOk
  StepFailed(StepError)
  StepSkipped
}

/// A trace record for a single step execution.
pub type StepTrace {
  StepTrace(step_name: String, status: StepStatus, duration_ms: Int)
}

/// The full result of a pipeline execution, including the trace and artifacts.
pub type ExecutionResult(a) {
  ExecutionResult(
    result: PipelineResult(a),
    trace: List(StepTrace),
    artifacts: Dict(String, Dynamic),
  )
}

/// Progress events emitted during pipeline execution.
/// Used by CLI compact/verbose modes for real-time progress display.
pub type StepEvent {
  /// Emitted before a step begins execution.
  StepStarting(name: String, index: Int, total: Int)
  /// Emitted after a step finishes execution.
  StepFinished(
    name: String,
    index: Int,
    total: Int,
    status: StepStatus,
    duration_ms: Int,
  )
}

// ---------------------------------------------------------------------------
// Loop configuration
// ---------------------------------------------------------------------------

/// Loop configuration for step repetition.
pub type Loop {
  /// Repeat the step a fixed number of times (minimum 1).
  FixedCount(count: Int)
  /// Retry on failure: attempt the step, and if it fails, retry up to max_attempts times.
  RetryOnFailure(max_attempts: Int)
  /// Repeat until success: keep attempting the step until it succeeds or exceeds max_attempts.
  UntilSuccess(max_attempts: Int)
}

// ---------------------------------------------------------------------------
// Pipeline scheduling
// ---------------------------------------------------------------------------

/// Scheduling configuration for pipelines.
pub type Schedule {
  /// No schedule — pipeline runs only on-demand.
  NoSchedule
  /// Run at a fixed interval (in milliseconds).
  /// E.g., Interval(60_000) runs every 60 seconds.
  Interval(interval_ms: Int)
  /// Run daily at a specific time (hour and minute in UTC).
  /// E.g., Daily(9, 0) runs every day at 9:00 AM UTC.
  Daily(hour: Int, minute: Int)
  /// Run weekly on a specific day at a specific time.
  /// Day: 0=Monday, 1=Tuesday, ..., 6=Sunday
  /// E.g., Weekly(1, 14, 30) runs every Tuesday at 2:30 PM UTC.
  Weekly(day_of_week: Int, hour: Int, minute: Int)
  /// Run on specific days of the month.
  /// E.g., Monthly([1, 15], 10, 0) runs on the 1st and 15th at 10:00 AM UTC.
  Monthly(days: List(Int), hour: Int, minute: Int)
  /// Cron-like expression (simplified format).
  /// Format: "minute hour day month day_of_week"
  /// E.g., "0 9 * * 1-5" runs at 9:00 AM on weekdays.
  Cron(expression: String)
}

// ---------------------------------------------------------------------------
// Registry errors
// ---------------------------------------------------------------------------

/// Errors from the pipeline registry.
pub type RegistryError {
  NotFound(id: PipelineId)
  VersionConflict(id: PipelineId)
}
