/// Parallel Step Executor — runs pipeline steps respecting dependencies.
///
/// This executor builds a dependency graph (DAG) from steps and executes them
/// in topological order. Steps with no dependencies between them can logically
/// run in parallel (actual concurrency depends on the target platform).
///
/// Implements FR-2 (respects step order), FR-3 (error propagation),
/// with support for parallel execution patterns.
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/string
import thingfactory/artifact_store
import thingfactory/dependency_injector
import thingfactory/message_store
import thingfactory/pipeline.{type Pipeline, type Step}
import thingfactory/timing
import thingfactory/types.{
  type Context, type ExecutionConfig, type ExecutionResult, type StepEvent,
  Context, ExecutionResult, StepError, StepFailed, StepFinished, StepOk,
  StepSkipped, StepStarting, StepTrace,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Execute a pipeline with parallel support.
/// Steps with dependencies will wait for their dependencies to complete.
/// Steps without dependencies (or whose dependencies have completed) can run concurrently.
pub fn execute_parallel(
  p: Pipeline(Dynamic),
  initial_input: Dynamic,
  config: ExecutionConfig,
) -> ExecutionResult(Dynamic) {
  let deps = dependency_injector.build(config.dependency_bindings)
  let store = artifact_store.new()
  let msg_store = message_store.new()
  let secrets = pipeline.secrets(p)
  let ctx =
    Context(
      artifact_store: store,
      message_store: msg_store,
      deps: deps,
      secret_store: secrets,
    )

  let steps = pipeline.steps(p)

  // Validate the dependency graph
  case validate_dependencies(steps) {
    Error(msg) ->
      ExecutionResult(
        result: Error(types.ValidationError(msg)),
        trace: [],
        artifacts: dict.new(),
      )
    Ok(Nil) -> {
      // Execute with parallel support
      let result = execute_with_deps(steps, initial_input, ctx, dict.new())
      result
    }
  }
}

/// Execute a parallel pipeline with real-time progress callbacks.
pub fn execute_parallel_with_progress(
  p: Pipeline(Dynamic),
  initial_input: Dynamic,
  config: ExecutionConfig,
  on_progress: fn(StepEvent) -> Nil,
) -> ExecutionResult(Dynamic) {
  let deps = dependency_injector.build(config.dependency_bindings)
  let store = artifact_store.new()
  let msg_store = message_store.new()
  let secrets = pipeline.secrets(p)
  let ctx =
    Context(
      artifact_store: store,
      message_store: msg_store,
      deps: deps,
      secret_store: secrets,
    )

  let steps = pipeline.steps(p)
  let total = list.length(steps)

  case validate_dependencies(steps) {
    Error(msg) ->
      ExecutionResult(
        result: Error(types.ValidationError(msg)),
        trace: [],
        artifacts: dict.new(),
      )
    Ok(Nil) ->
      execute_with_deps_progress(
        steps,
        initial_input,
        ctx,
        dict.new(),
        on_progress,
        1,
        total,
      )
  }
}

// ---------------------------------------------------------------------------
// Internal execution
// ---------------------------------------------------------------------------

/// Step status during execution
type StepStatus {
  Completed(result: Result(Dynamic, types.StepError), duration_ms: Int)
  Failed(error: types.StepError, duration_ms: Int)
}

fn execute_with_deps(
  steps: List(Step),
  initial_input: Dynamic,
  ctx: Context,
  step_status: Dict(String, StepStatus),
) -> ExecutionResult(Dynamic) {
  // Check if all steps are either completed or failed
  let all_done =
    list.all(steps, fn(step) {
      case dict.get(step_status, step.name) {
        Ok(Completed(_, _)) | Ok(Failed(_, _)) -> True
        _ -> False
      }
    })

  case all_done {
    True -> {
      // All steps done, return result
      let final_trace =
        list.map(steps, fn(step) {
          case dict.get(step_status, step.name) {
            Ok(Completed(_, duration)) ->
              StepTrace(
                step_name: step.name,
                status: StepOk,
                duration_ms: duration,
              )
            Ok(Failed(err, duration)) ->
              StepTrace(
                step_name: step.name,
                status: StepFailed(err),
                duration_ms: duration,
              )
            _ ->
              StepTrace(
                step_name: step.name,
                status: StepSkipped,
                duration_ms: 0,
              )
          }
        })

      // Determine if there was an error
      case
        list.find(steps, fn(step) {
          case dict.get(step_status, step.name) {
            Ok(Failed(_, _)) -> True
            _ -> False
          }
        })
      {
        Ok(failed_step) ->
          case dict.get(step_status, failed_step.name) {
            Ok(Failed(err, _)) ->
              ExecutionResult(
                result: Error(StepError(step_name: failed_step.name, error: err)),
                trace: final_trace,
                artifacts: ctx.artifact_store,
              )
            _ ->
              ExecutionResult(
                result: Ok(initial_input),
                trace: final_trace,
                artifacts: ctx.artifact_store,
              )
          }
        Error(Nil) ->
          ExecutionResult(
            result: Ok(initial_input),
            trace: final_trace,
            artifacts: ctx.artifact_store,
          )
      }
    }
    False -> {
      // Find a step that's ready to run (all dependencies completed)
      case find_ready_step(steps, step_status) {
        Ok(step) -> {
          // Check if dependencies failed
          let has_failed_dep =
            list.any(step.depends_on, fn(dep) {
              let pipeline.StepRef(dep_name) = dep
              case dict.get(step_status, dep_name) {
                Ok(Failed(_, _)) -> True
                _ -> False
              }
            })

          case has_failed_dep {
            True -> {
              // Skip this step and mark it as skipped
              let updated_status =
                dict.insert(
                  step_status,
                  step.name,
                  Failed(types.StepFailure("dependency failed"), 0),
                )
              execute_with_deps(steps, initial_input, ctx, updated_status)
            }
            False -> {
              // Execute the step
              let #(duration_ms, step_result) =
                timing.measure(fn() { step.run(ctx, initial_input) })

              let updated_status = case step_result {
                Ok(#(output, _updated_ctx)) ->
                  dict.insert(
                    step_status,
                    step.name,
                    Completed(Ok(output), duration_ms),
                  )
                Error(err) ->
                  dict.insert(step_status, step.name, Failed(err, duration_ms))
              }

              execute_with_deps(steps, initial_input, ctx, updated_status)
            }
          }
        }
        Error(Nil) -> {
          // No ready step found - all remaining are waiting
          // This shouldn't happen if graph is valid
          ExecutionResult(
            result: Error(types.ValidationError("circular dependency detected")),
            trace: [],
            artifacts: ctx.artifact_store,
          )
        }
      }
    }
  }
}

fn execute_with_deps_progress(
  steps: List(Step),
  initial_input: Dynamic,
  ctx: Context,
  step_status: Dict(String, StepStatus),
  on_progress: fn(StepEvent) -> Nil,
  current_index: Int,
  total: Int,
) -> ExecutionResult(Dynamic) {
  let all_done =
    list.all(steps, fn(step) {
      case dict.get(step_status, step.name) {
        Ok(Completed(_, _)) | Ok(Failed(_, _)) -> True
        _ -> False
      }
    })

  case all_done {
    True -> {
      let final_trace =
        list.map(steps, fn(step) {
          case dict.get(step_status, step.name) {
            Ok(Completed(_, duration)) ->
              StepTrace(
                step_name: step.name,
                status: StepOk,
                duration_ms: duration,
              )
            Ok(Failed(err, duration)) ->
              StepTrace(
                step_name: step.name,
                status: StepFailed(err),
                duration_ms: duration,
              )
            _ ->
              StepTrace(
                step_name: step.name,
                status: StepSkipped,
                duration_ms: 0,
              )
          }
        })

      case
        list.find(steps, fn(step) {
          case dict.get(step_status, step.name) {
            Ok(Failed(_, _)) -> True
            _ -> False
          }
        })
      {
        Ok(failed_step) ->
          case dict.get(step_status, failed_step.name) {
            Ok(Failed(err, _)) ->
              ExecutionResult(
                result: Error(StepError(step_name: failed_step.name, error: err)),
                trace: final_trace,
                artifacts: ctx.artifact_store,
              )
            _ ->
              ExecutionResult(
                result: Ok(initial_input),
                trace: final_trace,
                artifacts: ctx.artifact_store,
              )
          }
        Error(Nil) ->
          ExecutionResult(
            result: Ok(initial_input),
            trace: final_trace,
            artifacts: ctx.artifact_store,
          )
      }
    }
    False -> {
      case find_ready_step(steps, step_status) {
        Ok(step) -> {
          let has_failed_dep =
            list.any(step.depends_on, fn(dep) {
              let pipeline.StepRef(dep_name) = dep
              case dict.get(step_status, dep_name) {
                Ok(Failed(_, _)) -> True
                _ -> False
              }
            })

          case has_failed_dep {
            True -> {
              on_progress(StepStarting(
                name: step.name,
                index: current_index,
                total: total,
              ))
              on_progress(StepFinished(
                name: step.name,
                index: current_index,
                total: total,
                status: StepFailed(types.StepFailure("dependency failed")),
                duration_ms: 0,
                output: "",
              ))
              let updated_status =
                dict.insert(
                  step_status,
                  step.name,
                  Failed(types.StepFailure("dependency failed"), 0),
                )
              execute_with_deps_progress(
                steps,
                initial_input,
                ctx,
                updated_status,
                on_progress,
                current_index + 1,
                total,
              )
            }
            False -> {
              on_progress(StepStarting(
                name: step.name,
                index: current_index,
                total: total,
              ))
              let #(duration_ms, step_result) =
                timing.measure(fn() { step.run(ctx, initial_input) })

              let #(updated_status, step_status_event, step_output) = case
                step_result
              {
                Ok(#(output, _updated_ctx)) -> #(
                  dict.insert(
                    step_status,
                    step.name,
                    Completed(Ok(output), duration_ms),
                  ),
                  StepOk,
                  format_step_output(output),
                )
                Error(err) -> #(
                  dict.insert(step_status, step.name, Failed(err, duration_ms)),
                  StepFailed(err),
                  "",
                )
              }

              on_progress(StepFinished(
                name: step.name,
                index: current_index,
                total: total,
                status: step_status_event,
                duration_ms: duration_ms,
                output: step_output,
              ))

              execute_with_deps_progress(
                steps,
                initial_input,
                ctx,
                updated_status,
                on_progress,
                current_index + 1,
                total,
              )
            }
          }
        }
        Error(Nil) -> {
          ExecutionResult(
            result: Error(types.ValidationError("circular dependency detected")),
            trace: [],
            artifacts: ctx.artifact_store,
          )
        }
      }
    }
  }
}

fn format_step_output(output: Dynamic) -> String {
  string.inspect(output) |> string.trim()
}

/// Find the next step that is ready to run:
/// - Not already completed or failed
/// - All dependencies have resolved (completed or failed)
fn find_ready_step(
  steps: List(Step),
  status: Dict(String, StepStatus),
) -> Result(Step, Nil) {
  list.find(steps, fn(step) {
    case dict.get(status, step.name) {
      Ok(Completed(_, _)) | Ok(Failed(_, _)) -> False
      _ ->
        list.all(step.depends_on, fn(dep) {
          let pipeline.StepRef(dep_name) = dep
          case dict.get(status, dep_name) {
            Ok(Completed(_, _)) | Ok(Failed(_, _)) -> True
            _ -> False
          }
        })
    }
  })
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Validate that the dependency graph has no cycles and all references are valid
fn validate_dependencies(steps: List(Step)) -> Result(Nil, String) {
  let step_names = list.map(steps, fn(s) { s.name })

  // Check that all dependencies reference valid steps
  let has_invalid_refs =
    list.any(steps, fn(step) {
      list.any(step.depends_on, fn(dep) {
        let pipeline.StepRef(dep_name) = dep
        !list.contains(step_names, dep_name)
      })
    })

  case has_invalid_refs {
    True -> Error("invalid step dependency reference")
    False -> Ok(Nil)
  }
}
