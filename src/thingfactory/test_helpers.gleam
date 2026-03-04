/// Test Helpers — mock creation and pipeline execution with mocks.
///
/// Implements FR-7 (Testing with Mocks).
/// String-keyed mock registration per [q1] decision (documented trade-off).
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import thingfactory/executor
import thingfactory/message_store
import thingfactory/pipeline.{type Pipeline, Pipeline, Step}
import thingfactory/secret_manager
import thingfactory/types.{
  type Context, type ExecutionResult, type StepError, Context,
}

/// A mock step function that returns a predefined result.
pub type Mock(id) =
  #(id, fn(Context, Dynamic) -> Result(Dynamic, StepError))

/// Create a mock that returns a successful result.
pub fn mock_step_success(name: id, output: Dynamic) -> Mock(id) {
  let fn_mock = fn(_ctx, _input) { Ok(output) }
  #(name, fn_mock)
}

/// Create a mock that returns an error.
pub fn mock_step_error(name: id, error: StepError) -> Mock(id) {
  let fn_mock = fn(_ctx, _input) { Error(error) }
  #(name, fn_mock)
}

/// Create a mock with a custom function.
pub fn mock_step_fn(
  name: id,
  step_fn: fn(Context, Dynamic) -> Result(Dynamic, StepError),
) -> Mock(id) {
  #(name, step_fn)
}

/// Execute a pipeline with mocks substituted for real steps.
/// Mocked steps bypass timeout enforcement and return their predefined results.
pub fn run_with_mocks(
  p: Pipeline(id, Dynamic),
  mocks: List(Mock(id)),
  initial_input: Dynamic,
) -> ExecutionResult(Dynamic) {
  let compiled = pipeline.compile(p)
  let to_s = pipeline.get_id_to_string(p)
  let string_mocks = list.map(mocks, fn(mock) { #(to_s(mock.0), mock.1) })
  let mock_dict = dict.from_list(string_mocks)
  let wrapped_pipeline = wrap_pipeline_with_mocks(compiled, mock_dict)
  let ctx =
    Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  executor.execute_with_context(wrapped_pipeline, initial_input, ctx)
}

/// Wrap a pipeline's steps with mock substitutions.
fn wrap_pipeline_with_mocks(
  p: Pipeline(String, Dynamic),
  mock_dict: Dict(String, fn(Context, Dynamic) -> Result(Dynamic, StepError)),
) -> Pipeline(String, Dynamic) {
  let steps = p.steps
  let wrapped_steps =
    list.map(steps, fn(step) {
      case dict.get(mock_dict, step.name) {
        Ok(mock_fn) -> {
          let wrapped = fn(ctx, input) {
            case mock_fn(ctx, input) {
              Ok(output) -> Ok(#(output, ctx))
              Error(err) -> Error(err)
            }
          }
          Step(step.name, wrapped, step.timeout_ms, step.depends_on, step.loop)
        }
        Error(Nil) -> step
      }
    })
  Pipeline(
    p.id,
    wrapped_steps,
    p.default_timeout_ms,
    p.schedule,
    p.trigger,
    p.secrets,
    p.id_to_string,
  )
}
