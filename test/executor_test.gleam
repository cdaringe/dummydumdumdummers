import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/executor
import thingfactory/pipeline
import thingfactory/types.{type StepEvent}

// FR-2: Sequential execution
pub fn sequential_execution_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(ctx, input) { Ok(dynamic.string("step1")) })
    |> pipeline.add_step("step2", fn(ctx, input) { Ok(dynamic.string("step2")) })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.string("input"), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// FR-3: Error propagation halts execution
pub fn error_propagation_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(ctx, input) { Ok(input) })
    |> pipeline.add_step("step2", fn(ctx, input) {
      Error(types.StepFailure(message: "fail"))
    })
    |> pipeline.add_step("step3", fn(ctx, input) { Ok(input) })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.string("input"), config)

  result.result |> should.be_error()
  list.length(result.trace) |> should.equal(3)
}

// QR-4: Linear execution only
pub fn linear_execution_order_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("a", fn(ctx, input) { Ok(input) })
    |> pipeline.add_step("b", fn(ctx, input) { Ok(input) })
    |> pipeline.add_step("c", fn(ctx, input) { Ok(input) })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)

  let names = result.trace |> list.map(fn(t) { t.step_name })
  names |> should.equal(["a", "b", "c"])
}

// execute_with_progress produces same results as execute
pub fn execute_with_progress_test() {
  let p =
    pipeline.new("progress_test", "1.0.0")
    |> pipeline.add_step("step_a", fn(_ctx, _input) {
      Ok(dynamic.string("a_out"))
    })
    |> pipeline.add_step("step_b", fn(_ctx, _input) {
      Ok(dynamic.string("b_out"))
    })
    |> pipeline.add_step("step_c", fn(_ctx, _input) {
      Ok(dynamic.string("c_out"))
    })

  let config = types.default_config()
  let noop = fn(_event: StepEvent) { Nil }
  let result = executor.execute_with_progress(p, dynamic.nil(), config, noop)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(3)
  let names = result.trace |> list.map(fn(t) { t.step_name })
  names |> should.equal(["step_a", "step_b", "step_c"])
}

// execute_with_progress reports errors correctly
pub fn execute_with_progress_error_test() {
  let p =
    pipeline.new("progress_err", "1.0.0")
    |> pipeline.add_step("ok_step", fn(_ctx, input) { Ok(input) })
    |> pipeline.add_step("fail_step", fn(_ctx, _input) {
      Error(types.StepFailure(message: "boom"))
    })
    |> pipeline.add_step("skipped_step", fn(_ctx, input) { Ok(input) })

  let config = types.default_config()
  let noop = fn(_event: StepEvent) { Nil }
  let result = executor.execute_with_progress(p, dynamic.nil(), config, noop)

  result.result |> should.be_error()
  list.length(result.trace) |> should.equal(3)

  let statuses =
    result.trace
    |> list.map(fn(t) {
      case t.status {
        types.StepOk -> "ok"
        types.StepFailed(_) -> "failed"
        types.StepSkipped -> "skipped"
      }
    })
  statuses |> should.equal(["ok", "failed", "skipped"])
}
