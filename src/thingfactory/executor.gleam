/// Step Executor — runs pipeline steps sequentially with timeout enforcement.
///
/// Implements FR-2 (sequential execution), FR-3 (error propagation),
/// FR-5 (timeout enforcement), FR-9 (dependency injection via Context),
/// QR-2 (no silent failures), QR-4 (linear execution only).
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import thingfactory/artifact_store
import thingfactory/dependency_injector
import thingfactory/message_store
import thingfactory/pipeline.{type Pipeline, type Step}
import thingfactory/timing
import thingfactory/types.{
  type Context, type ExecutionConfig, type ExecutionResult, type Loop,
  type StepEvent, type StepTrace, Context, ExecutionResult, FixedCount,
  RetryOnFailure, StepError, StepFailed, StepFinished, StepOk, StepSkipped,
  StepStarting, StepTrace, UntilSuccess,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Execute a pipeline with the given initial input and config.
/// Returns an ExecutionResult containing the pipeline result and step traces.
pub fn execute(
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
  run_steps(pipeline.steps(p), initial_input, ctx, [])
}

/// Execute a pipeline with a pre-built context (used by test_helpers).
pub fn execute_with_context(
  p: Pipeline(Dynamic),
  initial_input: Dynamic,
  ctx: Context,
) -> ExecutionResult(Dynamic) {
  run_steps(pipeline.steps(p), initial_input, ctx, [])
}

/// Execute a pipeline with real-time progress callbacks.
/// The on_progress function is called before and after each step executes,
/// enabling compact/verbose CLI output during execution.
pub fn execute_with_progress(
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
  let total = list.length(pipeline.steps(p))
  run_steps_with_progress(
    pipeline.steps(p),
    initial_input,
    ctx,
    [],
    on_progress,
    1,
    total,
  )
}

// ---------------------------------------------------------------------------
// Internal step runner
// ---------------------------------------------------------------------------

fn run_steps_with_progress(
  steps: List(Step),
  current_input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
  on_progress: fn(StepEvent) -> Nil,
  index: Int,
  total: Int,
) -> ExecutionResult(Dynamic) {
  case steps {
    [] ->
      ExecutionResult(
        result: Ok(current_input),
        trace: list.reverse(traces),
        artifacts: ctx.artifact_store,
      )

    [step, ..rest] -> {
      case step.loop {
        None -> {
          on_progress(StepStarting(name: step.name, index: index, total: total))
          let #(duration_ms, step_result) =
            timing.measure(fn() { step.run(ctx, current_input) })

          case step_result {
            Ok(#(output, updated_ctx)) -> {
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepOk,
                  duration_ms: duration_ms,
                )
              on_progress(StepFinished(
                name: step.name,
                index: index,
                total: total,
                status: StepOk,
                duration_ms: duration_ms,
              ))
              run_steps_with_progress(
                rest,
                output,
                updated_ctx,
                [trace, ..traces],
                on_progress,
                index + 1,
                total,
              )
            }

            Error(step_err) -> {
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepFailed(step_err),
                  duration_ms: duration_ms,
                )
              on_progress(StepFinished(
                name: step.name,
                index: index,
                total: total,
                status: StepFailed(step_err),
                duration_ms: duration_ms,
              ))
              let skipped_traces = mark_skipped(rest)
              let all_traces =
                list.reverse([trace, ..traces])
                |> list.append(skipped_traces)
              let pipeline_err =
                StepError(step_name: step.name, error: step_err)
              ExecutionResult(
                result: Error(pipeline_err),
                trace: all_traces,
                artifacts: ctx.artifact_store,
              )
            }
          }
        }

        Some(loop_config) -> {
          on_progress(StepStarting(name: step.name, index: index, total: total))
          let loop_result = run_loop(step, loop_config, current_input, ctx, [])
          case loop_result {
            Ok(#(output, loop_traces)) -> {
              let total_duration =
                list.fold(loop_traces, 0, fn(acc, t: StepTrace) {
                  acc + t.duration_ms
                })
              on_progress(StepFinished(
                name: step.name,
                index: index,
                total: total,
                status: StepOk,
                duration_ms: total_duration,
              ))
              run_steps_with_progress(
                rest,
                output,
                ctx,
                list.append(traces, loop_traces),
                on_progress,
                index + 1,
                total,
              )
            }

            Error(#(step_err, loop_traces)) -> {
              let total_duration =
                list.fold(loop_traces, 0, fn(acc, t: StepTrace) {
                  acc + t.duration_ms
                })
              on_progress(StepFinished(
                name: step.name,
                index: index,
                total: total,
                status: StepFailed(step_err),
                duration_ms: total_duration,
              ))
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepFailed(step_err),
                  duration_ms: 0,
                )
              let skipped_traces = mark_skipped(rest)
              let all_traces =
                list.append(list.append(traces, loop_traces), [trace])
                |> list.append(skipped_traces)
              let pipeline_err =
                StepError(step_name: step.name, error: step_err)
              ExecutionResult(
                result: Error(pipeline_err),
                trace: all_traces,
                artifacts: ctx.artifact_store,
              )
            }
          }
        }
      }
    }
  }
}

fn run_steps(
  steps: List(Step),
  current_input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
) -> ExecutionResult(Dynamic) {
  case steps {
    [] ->
      ExecutionResult(
        result: Ok(current_input),
        trace: list.reverse(traces),
        artifacts: ctx.artifact_store,
      )

    [step, ..rest] -> {
      case step.loop {
        None -> {
          // No looping: execute once
          let #(duration_ms, step_result) =
            timing.measure(fn() { step.run(ctx, current_input) })

          case step_result {
            Ok(#(output, updated_ctx)) -> {
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepOk,
                  duration_ms: duration_ms,
                )
              run_steps(rest, output, updated_ctx, [trace, ..traces])
            }

            Error(step_err) -> {
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepFailed(step_err),
                  duration_ms: duration_ms,
                )
              let skipped_traces = mark_skipped(rest)
              let all_traces =
                list.reverse([trace, ..traces])
                |> list.append(skipped_traces)
              let pipeline_err =
                StepError(step_name: step.name, error: step_err)
              ExecutionResult(
                result: Error(pipeline_err),
                trace: all_traces,
                artifacts: ctx.artifact_store,
              )
            }
          }
        }

        Some(loop_config) -> {
          // Execute with looping
          let loop_result = run_loop(step, loop_config, current_input, ctx, [])
          case loop_result {
            Ok(#(output, loop_traces)) ->
              run_steps(rest, output, ctx, list.append(traces, loop_traces))

            Error(#(step_err, loop_traces)) -> {
              let trace =
                StepTrace(
                  step_name: step.name,
                  status: StepFailed(step_err),
                  duration_ms: 0,
                )
              let skipped_traces = mark_skipped(rest)
              let all_traces =
                list.append(list.append(traces, loop_traces), [trace])
                |> list.append(skipped_traces)
              let pipeline_err =
                StepError(step_name: step.name, error: step_err)
              ExecutionResult(
                result: Error(pipeline_err),
                trace: all_traces,
                artifacts: ctx.artifact_store,
              )
            }
          }
        }
      }
    }
  }
}

fn run_loop(
  step: Step,
  loop_config: Loop,
  input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
) {
  case loop_config {
    FixedCount(count) -> run_fixed_count(step, count, 1, input, ctx, traces)

    RetryOnFailure(max_attempts) ->
      run_retry_on_failure(step, max_attempts, 1, input, ctx, traces)

    UntilSuccess(max_attempts) ->
      run_until_success(step, max_attempts, 1, input, ctx, traces)
  }
}

fn run_fixed_count(
  step: Step,
  count: Int,
  attempt: Int,
  input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
) {
  case attempt > count {
    True -> Ok(#(input, list.reverse(traces)))
    False -> {
      let #(duration_ms, step_result) =
        timing.measure(fn() { step.run(ctx, input) })

      case step_result {
        Ok(#(output, updated_ctx)) -> {
          let trace =
            StepTrace(
              step_name: step.name <> "[" <> int_to_string(attempt) <> "]",
              status: StepOk,
              duration_ms: duration_ms,
            )
          run_fixed_count(step, count, attempt + 1, output, updated_ctx, [
            trace,
            ..traces
          ])
        }

        Error(step_err) -> {
          let trace =
            StepTrace(
              step_name: step.name <> "[" <> int_to_string(attempt) <> "]",
              status: StepFailed(step_err),
              duration_ms: duration_ms,
            )
          Error(#(step_err, list.reverse([trace, ..traces])))
        }
      }
    }
  }
}

fn run_retry_on_failure(
  step: Step,
  max_attempts: Int,
  attempt: Int,
  input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
) {
  let #(duration_ms, step_result) =
    timing.measure(fn() { step.run(ctx, input) })

  case step_result {
    Ok(#(output, _updated_ctx)) -> {
      let trace =
        StepTrace(
          step_name: step.name <> "[retry:" <> int_to_string(attempt) <> "]",
          status: StepOk,
          duration_ms: duration_ms,
        )
      Ok(#(output, list.reverse([trace, ..traces])))
    }

    Error(step_err) -> {
      let trace =
        StepTrace(
          step_name: step.name <> "[retry:" <> int_to_string(attempt) <> "]",
          status: StepFailed(step_err),
          duration_ms: duration_ms,
        )
      case attempt < max_attempts {
        True ->
          run_retry_on_failure(step, max_attempts, attempt + 1, input, ctx, [
            trace,
            ..traces
          ])

        False -> Error(#(step_err, list.reverse([trace, ..traces])))
      }
    }
  }
}

fn run_until_success(
  step: Step,
  max_attempts: Int,
  attempt: Int,
  input: Dynamic,
  ctx: Context,
  traces: List(StepTrace),
) {
  let #(duration_ms, step_result) =
    timing.measure(fn() { step.run(ctx, input) })

  case step_result {
    Ok(#(output, _updated_ctx)) -> {
      let trace =
        StepTrace(
          step_name: step.name <> "[attempt:" <> int_to_string(attempt) <> "]",
          status: StepOk,
          duration_ms: duration_ms,
        )
      Ok(#(output, list.reverse([trace, ..traces])))
    }

    Error(step_err) -> {
      let trace =
        StepTrace(
          step_name: step.name <> "[attempt:" <> int_to_string(attempt) <> "]",
          status: StepFailed(step_err),
          duration_ms: duration_ms,
        )
      case attempt < max_attempts {
        True ->
          run_until_success(step, max_attempts, attempt + 1, input, ctx, [
            trace,
            ..traces
          ])

        False -> Error(#(step_err, list.reverse([trace, ..traces])))
      }
    }
  }
}

fn int_to_string(n: Int) -> String {
  int.to_string(n)
}

fn mark_skipped(steps: List(Step)) -> List(StepTrace) {
  list.map(steps, fn(s) {
    StepTrace(step_name: s.name, status: StepSkipped, duration_ms: 0)
  })
}
