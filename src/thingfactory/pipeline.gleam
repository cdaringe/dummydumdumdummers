/// Pipeline DSL — builder API for defining linear step sequences.
///
/// Design:
///   - Pipeline(id, output) is parameterised on the step-identifier type
///     and the final output type.
///   - Steps are stored internally as fn(Context) -> Result(Dynamic, StepError)
///     (type-erased). The public add_step wraps typed fns at the boundary.
///   - Type safety: the Gleam compiler enforces that each step's fn argument
///     type matches what the caller passes. Intermediate inter-step types are
///     erased at runtime (documented trade-off in s1-decisions.md).
///   - Linear execution only — no branching or loops (QR-4).
///
/// Usage (typed IDs — compile-time safety, no to_string needed):
///   type StepId { Fetch Transform }
///   pipeline.new("my_pipeline", "1.0.0")
///   |> pipeline.add_step(Fetch, fn(ctx) { ... })
///   |> pipeline.add_step(Transform, fn(ctx) { ... })
///
/// Usage (string IDs — simplest):
///   pipeline.new("my_pipeline", "1.0.0")
///   |> pipeline.add_step("fetch", fn(ctx) { ... })
///   |> pipeline.add_step("transform", fn(ctx) { ... })
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import thingfactory/secret_manager.{type SecretStore}
import thingfactory/types.{
  type Context, type Loop, type PipelineId, type Schedule, type StepError,
  NoSchedule, PipelineId,
}
import thingfactory/webhook_trigger.{type Trigger, NoTrigger}

// ---------------------------------------------------------------------------
// Internal step representation
// ---------------------------------------------------------------------------

/// A step as stored inside the pipeline — name + type-erased function.
/// The run function returns both the output and an (optionally updated) Context,
/// enabling inter-step artifact and message sharing.
pub type Step(id) {
  Step(
    name: id,
    run: fn(Context, Dynamic) -> Result(#(Dynamic, Context), StepError),
    timeout_ms: Int,
    depends_on: List(id),
    loop: Option(Loop),
  )
}

// ---------------------------------------------------------------------------
// Pipeline type
// ---------------------------------------------------------------------------

/// A pipeline definition: an ordered list of steps.
/// The `id` type parameter controls step identifier types (enum or String).
/// The `output` phantom type represents the final output type.
pub type Pipeline(id, output) {
  Pipeline(
    id: PipelineId,
    steps: List(Step(id)),
    default_timeout_ms: Int,
    schedule: Schedule,
    trigger: Trigger,
    secrets: SecretStore,
    id_to_string: fn(id) -> String,
  )
}

// ---------------------------------------------------------------------------
// Builder API
// ---------------------------------------------------------------------------

/// Create a new empty pipeline. Step IDs can be any type — use a typed enum
/// for compile-time safety, or plain String for convenience.
///
/// When compiled for execution, step IDs are serialised via `step_id_to_string`:
/// String IDs are used verbatim; all other types are formatted with string.inspect.
///
/// Default per-step timeout is 30 minutes (1_800_000 ms).
/// Default schedule is NoSchedule (on-demand only).
/// Default trigger is NoTrigger (manual triggering only).
/// Default secrets store is empty.
pub fn new(name: String, version: String) -> Pipeline(id, Nil) {
  Pipeline(
    id: PipelineId(name: name, version: version),
    steps: [],
    default_timeout_ms: 1_800_000,
    schedule: NoSchedule,
    trigger: NoTrigger,
    secrets: secret_manager.new(),
    id_to_string: step_id_to_string,
  )
}

/// Convert any step ID to a String for traces, logs, and execution.
///
/// - If `id` is a `String`, it is returned as-is. `string.inspect` wraps
///   strings in surrounding double-quotes, so this function strips them.
/// - Otherwise, `string.inspect` is used:
///     GleamCheck  → "GleamCheck"
///     Worker(3)   → "Worker(3)"
///
/// This allows typed enum IDs without requiring a manual to_string converter.
pub fn step_id_to_string(id: a) -> String {
  let inspected = string.inspect(id)
  case string.starts_with(inspected, "\""), string.ends_with(inspected, "\"") {
    True, True -> string.slice(inspected, 1, string.length(inspected) - 2)
    _, _ -> inspected
  }
}

/// Compile a typed pipeline into a String-based pipeline for execution.
/// Converts all step IDs using the pipeline's `id_to_string` function.
/// Executors call this internally — users typically don't need to.
pub fn compile(p: Pipeline(id, output)) -> Pipeline(String, output) {
  let to_s = p.id_to_string
  Pipeline(
    id: p.id,
    steps: list.map(p.steps, fn(step) {
      Step(
        name: to_s(step.name),
        run: step.run,
        timeout_ms: step.timeout_ms,
        depends_on: list.map(step.depends_on, to_s),
        loop: step.loop,
      )
    }),
    default_timeout_ms: p.default_timeout_ms,
    schedule: p.schedule,
    trigger: p.trigger,
    secrets: p.secrets,
    id_to_string: fn(s) { s },
  )
}

/// Set the default per-step timeout for this pipeline (in milliseconds).
pub fn with_timeout(
  pipeline: Pipeline(id, a),
  timeout_ms: Int,
) -> Pipeline(id, a) {
  Pipeline(..pipeline, default_timeout_ms: timeout_ms)
}

/// Set the schedule for this pipeline.
/// The schedule determines when the pipeline should be automatically triggered.
pub fn with_schedule(
  pipeline: Pipeline(id, a),
  schedule: Schedule,
) -> Pipeline(id, a) {
  Pipeline(..pipeline, schedule: schedule)
}

/// Set the webhook trigger for this pipeline.
/// The trigger determines if and when the pipeline should be triggered by webhooks.
pub fn with_trigger(
  pipeline: Pipeline(id, a),
  trigger: Trigger,
) -> Pipeline(id, a) {
  Pipeline(..pipeline, trigger: trigger)
}

/// Set the secrets store for this pipeline.
/// Secrets can be accessed by steps during execution through the Context.
pub fn with_secrets(
  pipeline: Pipeline(id, a),
  secrets: SecretStore,
) -> Pipeline(id, a) {
  Pipeline(..pipeline, secrets: secrets)
}

/// Add a secret to the pipeline's secret store.
/// Returns an updated pipeline with the secret added.
pub fn add_secret(
  pipeline: Pipeline(id, a),
  name: String,
  value: String,
) -> Pipeline(id, a) {
  let updated_secrets = secret_manager.set(pipeline.secrets, name, value)
  Pipeline(..pipeline, secrets: updated_secrets)
}

/// Add a step to the pipeline.
///
/// The step function receives:
///   - ctx: Context  (artifact store + injected deps)
///   - input: Dynamic  (output of the previous step, or initial_input)
///
/// The step function returns Result(Dynamic, StepError).
///
/// Type safety note: the Gleam compiler enforces the fn signature at the
/// call site. Intermediate types are erased to Dynamic between steps
/// (see s1-decisions.md [q1]).
pub fn add_step(
  pipeline: Pipeline(id, a),
  name: id,
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
) -> Pipeline(id, Dynamic) {
  let step =
    Step(
      name: name,
      run: wrap_step(run),
      timeout_ms: pipeline.default_timeout_ms,
      depends_on: [],
      loop: None,
    )
  Pipeline(
    id: pipeline.id,
    steps: list_append(pipeline.steps, [step]),
    default_timeout_ms: pipeline.default_timeout_ms,
    schedule: pipeline.schedule,
    trigger: pipeline.trigger,
    secrets: pipeline.secrets,
    id_to_string: pipeline.id_to_string,
  )
}

/// Add a step that returns an updated Context alongside its output.
/// Use this for steps that write artifacts or publish messages.
pub fn add_step_with_ctx(
  pipeline: Pipeline(id, a),
  name: id,
  run: fn(Context, Dynamic) -> Result(#(Dynamic, Context), StepError),
) -> Pipeline(id, Dynamic) {
  let step =
    Step(
      name: name,
      run: run,
      timeout_ms: pipeline.default_timeout_ms,
      depends_on: [],
      loop: None,
    )
  Pipeline(
    id: pipeline.id,
    steps: list_append(pipeline.steps, [step]),
    default_timeout_ms: pipeline.default_timeout_ms,
    schedule: pipeline.schedule,
    trigger: pipeline.trigger,
    secrets: pipeline.secrets,
    id_to_string: pipeline.id_to_string,
  )
}

/// Add a step with a custom per-step timeout override (in milliseconds).
pub fn add_step_with_timeout(
  pipeline: Pipeline(id, a),
  name: id,
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
  timeout_ms: Int,
) -> Pipeline(id, Dynamic) {
  let step =
    Step(
      name: name,
      run: wrap_step(run),
      timeout_ms: timeout_ms,
      depends_on: [],
      loop: None,
    )
  Pipeline(
    id: pipeline.id,
    steps: list_append(pipeline.steps, [step]),
    default_timeout_ms: pipeline.default_timeout_ms,
    schedule: pipeline.schedule,
    trigger: pipeline.trigger,
    secrets: pipeline.secrets,
    id_to_string: pipeline.id_to_string,
  )
}

/// Add a step with explicit dependencies on other steps.
/// The step will only execute after all its dependencies have completed successfully.
/// If any dependency fails, this step is skipped.
///
/// This enables parallel execution where multiple independent steps can run concurrently.
pub fn add_step_with_deps(
  pipeline: Pipeline(id, a),
  name: id,
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
  depends_on: List(id),
) -> Pipeline(id, Dynamic) {
  let step =
    Step(
      name: name,
      run: wrap_step(run),
      timeout_ms: pipeline.default_timeout_ms,
      depends_on: depends_on,
      loop: None,
    )
  Pipeline(
    id: pipeline.id,
    steps: list_append(pipeline.steps, [step]),
    default_timeout_ms: pipeline.default_timeout_ms,
    schedule: pipeline.schedule,
    trigger: pipeline.trigger,
    secrets: pipeline.secrets,
    id_to_string: pipeline.id_to_string,
  )
}

/// Add a step with loop configuration.
/// The step will be executed multiple times according to the loop strategy.
pub fn add_step_with_loop(
  pipeline: Pipeline(id, a),
  name: id,
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
  loop: Loop,
) -> Pipeline(id, Dynamic) {
  let step =
    Step(
      name: name,
      run: wrap_step(run),
      timeout_ms: pipeline.default_timeout_ms,
      depends_on: [],
      loop: Some(loop),
    )
  Pipeline(
    id: pipeline.id,
    steps: list_append(pipeline.steps, [step]),
    default_timeout_ms: pipeline.default_timeout_ms,
    schedule: pipeline.schedule,
    trigger: pipeline.trigger,
    secrets: pipeline.secrets,
    id_to_string: pipeline.id_to_string,
  )
}

// ---------------------------------------------------------------------------
// Accessors (used by executor and registry)
// ---------------------------------------------------------------------------

/// Return the PipelineId for this pipeline.
pub fn id(pipeline: Pipeline(id, a)) -> PipelineId {
  pipeline.id
}

/// Return the ordered list of steps.
pub fn steps(pipeline: Pipeline(id, a)) -> List(Step(id)) {
  pipeline.steps
}

/// Return the default timeout for this pipeline.
pub fn default_timeout(pipeline: Pipeline(id, a)) -> Int {
  pipeline.default_timeout_ms
}

/// Return the schedule for this pipeline.
pub fn schedule(pipeline: Pipeline(id, a)) -> Schedule {
  pipeline.schedule
}

/// Return the trigger for this pipeline.
pub fn trigger(pipeline: Pipeline(id, a)) -> Trigger {
  pipeline.trigger
}

/// Return the secrets store for this pipeline.
pub fn secrets(pipeline: Pipeline(id, a)) -> SecretStore {
  pipeline.secrets
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn list_append(xs: List(a), ys: List(a)) -> List(a) {
  case xs {
    [] -> ys
    [head, ..tail] -> [head, ..list_append(tail, ys)]
  }
}

/// Wrap a simple step function (that doesn't modify context) into the internal
/// representation that returns both output and the original context.
fn wrap_step(
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
) -> fn(Context, Dynamic) -> Result(#(Dynamic, Context), StepError) {
  fn(ctx, input) {
    case run(ctx, input) {
      Ok(output) -> Ok(#(output, ctx))
      Error(err) -> Error(err)
    }
  }
}
