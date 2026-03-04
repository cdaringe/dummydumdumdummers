/// Tests for typed step identifiers
import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/executor
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/test_helpers
import thingfactory/types

// ---------------------------------------------------------------------------
// Static typed IDs
// ---------------------------------------------------------------------------

type BuildStep {
  Checkout
  Lint
  Test
  Build
  Package
}

fn build_step_to_string(step: BuildStep) -> String {
  case step {
    Checkout -> "checkout"
    Lint -> "lint"
    Test -> "test"
    Build -> "build"
    Package -> "package"
  }
}

pub fn typed_static_pipeline_test() {
  let p =
    pipeline.typed("typed_build", "1.0.0", build_step_to_string)
    |> pipeline.add_step(Checkout, fn(_ctx, _input) {
      Ok(dynamic.string("checked out"))
    })
    |> pipeline.add_step(Lint, fn(_ctx, _input) {
      Ok(dynamic.string("lint passed"))
    })
    |> pipeline.add_step(Build, fn(_ctx, _input) {
      Ok(dynamic.string("build done"))
    })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(3)
}

pub fn typed_static_deps_test() {
  let p =
    pipeline.typed("typed_deps", "1.0.0", build_step_to_string)
    |> pipeline.add_step_with_deps(
      Checkout,
      fn(_ctx, _input) { Ok(dynamic.string("checked out")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      Lint,
      fn(_ctx, _input) { Ok(dynamic.string("lint passed")) },
      [Checkout],
    )
    |> pipeline.add_step_with_deps(
      Test,
      fn(_ctx, _input) { Ok(dynamic.string("tests passed")) },
      [Checkout],
    )
    |> pipeline.add_step_with_deps(
      Build,
      fn(_ctx, _input) { Ok(dynamic.string("build done")) },
      [Lint, Test],
    )
    |> pipeline.add_step_with_deps(
      Package,
      fn(_ctx, _input) { Ok(dynamic.string("package created")) },
      [Build],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(5)
}

// ---------------------------------------------------------------------------
// Dynamic IDs
// ---------------------------------------------------------------------------

type DynamicStep {
  Named(String)
  Indexed(String, Int)
}

fn dynamic_step_to_string(step: DynamicStep) -> String {
  case step {
    Named(name) -> name
    Indexed(name, idx) -> name <> "_" <> int_to_string(idx)
  }
}

pub fn typed_dynamic_ids_test() {
  let p =
    pipeline.typed("dynamic_ids", "1.0.0", dynamic_step_to_string)
    |> pipeline.add_step(Named("setup"), fn(_ctx, _input) {
      Ok(dynamic.string("setup"))
    })
    |> pipeline.add_step(Indexed("task", 1), fn(_ctx, _input) {
      Ok(dynamic.string("task_1"))
    })
    |> pipeline.add_step(Indexed("task", 2), fn(_ctx, _input) {
      Ok(dynamic.string("task_2"))
    })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(3)
  // Verify compiled step names
  let names = list.map(result.trace, fn(t) { t.step_name })
  names |> should.equal(["setup", "task_1", "task_2"])
}

pub fn typed_dynamic_unique_instances_test() {
  // Custom("a") != Custom("b"), Indexed("task", 1) != Indexed("task", 2)
  let p =
    pipeline.typed("unique_dynamic", "1.0.0", dynamic_step_to_string)
    |> pipeline.add_step_with_deps(
      Named("init"),
      fn(_ctx, _input) { Ok(dynamic.string("init")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      Indexed("worker", 1),
      fn(_ctx, _input) { Ok(dynamic.string("w1")) },
      [Named("init")],
    )
    |> pipeline.add_step_with_deps(
      Indexed("worker", 2),
      fn(_ctx, _input) { Ok(dynamic.string("w2")) },
      [Named("init")],
    )
    |> pipeline.add_step_with_deps(
      Named("merge"),
      fn(_ctx, _input) { Ok(dynamic.string("merged")) },
      [Indexed("worker", 1), Indexed("worker", 2)],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(4)
}

// ---------------------------------------------------------------------------
// Mixed static + dynamic
// ---------------------------------------------------------------------------

type MixedStep {
  StaticSetup
  StaticBuild
  Custom(String)
}

fn mixed_to_string(step: MixedStep) -> String {
  case step {
    StaticSetup -> "setup"
    StaticBuild -> "build"
    Custom(name) -> "custom_" <> name
  }
}

pub fn typed_mixed_static_dynamic_test() {
  let p =
    pipeline.typed("mixed", "1.0.0", mixed_to_string)
    |> pipeline.add_step_with_deps(
      StaticSetup,
      fn(_ctx, _input) { Ok(dynamic.string("setup done")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      Custom("lint"),
      fn(_ctx, _input) { Ok(dynamic.string("lint done")) },
      [StaticSetup],
    )
    |> pipeline.add_step_with_deps(
      Custom("test"),
      fn(_ctx, _input) { Ok(dynamic.string("test done")) },
      [StaticSetup],
    )
    |> pipeline.add_step_with_deps(
      StaticBuild,
      fn(_ctx, _input) { Ok(dynamic.string("build done")) },
      [Custom("lint"), Custom("test")],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(4)
  let names = list.map(result.trace, fn(t) { t.step_name })
  list.contains(names, "setup") |> should.be_true()
  list.contains(names, "custom_lint") |> should.be_true()
  list.contains(names, "custom_test") |> should.be_true()
  list.contains(names, "build") |> should.be_true()
}

// ---------------------------------------------------------------------------
// Compile correctness
// ---------------------------------------------------------------------------

pub fn compile_produces_correct_names_test() {
  let p =
    pipeline.typed("compile_test", "1.0.0", build_step_to_string)
    |> pipeline.add_step_with_deps(
      Checkout,
      fn(_ctx, _input) { Ok(dynamic.string("ok")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      Build,
      fn(_ctx, _input) { Ok(dynamic.string("ok")) },
      [Checkout],
    )

  let compiled = pipeline.compile(p)
  let steps = pipeline.steps(compiled)
  let first = list.first(steps)
  first |> should.be_ok()
  case first {
    Ok(step) -> {
      step.name |> should.equal("checkout")
      step.depends_on |> should.equal([])
    }
    Error(_) -> Nil
  }
  let second = list.last(steps)
  second |> should.be_ok()
  case second {
    Ok(step) -> {
      step.name |> should.equal("build")
      step.depends_on |> should.equal(["checkout"])
    }
    Error(_) -> Nil
  }
}

// ---------------------------------------------------------------------------
// Typed IDs with loops
// ---------------------------------------------------------------------------

pub fn typed_with_loop_test() {
  let p =
    pipeline.typed("loop_typed", "1.0.0", build_step_to_string)
    |> pipeline.add_step(Checkout, fn(_ctx, _input) {
      Ok(dynamic.string("checked out"))
    })
    |> pipeline.add_step_with_loop(
      Build,
      fn(_ctx, _input) { Ok(dynamic.string("build attempt")) },
      types.FixedCount(count: 3),
    )

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  // 1 checkout + 3 build loop iterations
  list.length(result.trace) |> should.equal(4)
}

// ---------------------------------------------------------------------------
// Typed IDs with mocks
// ---------------------------------------------------------------------------

pub fn typed_with_mocks_test() {
  let p =
    pipeline.typed("mock_typed", "1.0.0", build_step_to_string)
    |> pipeline.add_step(Checkout, fn(_ctx, _input) {
      Ok(dynamic.string("real checkout"))
    })
    |> pipeline.add_step(Build, fn(_ctx, _input) {
      Ok(dynamic.string("real build"))
    })

  let mocks = [
    test_helpers.mock_step_success(Checkout, dynamic.string("mocked checkout")),
  ]
  let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// ---------------------------------------------------------------------------
// Typed IDs with context/artifacts
// ---------------------------------------------------------------------------

pub fn typed_with_context_test() {
  let p =
    pipeline.typed("ctx_typed", "1.0.0", build_step_to_string)
    |> pipeline.add_step_with_ctx(Checkout, fn(ctx, _input) {
      let updated =
        types.publish_message(ctx, "status", dynamic.string("checked out"))
      Ok(#(dynamic.string("done"), updated))
    })
    |> pipeline.add_step(Build, fn(ctx, _input) {
      let msgs = types.get_messages(ctx, "status")
      case msgs {
        [] -> Error(types.StepFailure(message: "no status messages"))
        _ -> Ok(dynamic.string("build with context"))
      }
    })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_ok()
}

// ---------------------------------------------------------------------------
// String-based pipelines still work (backwards compatibility)
// ---------------------------------------------------------------------------

pub fn string_pipeline_still_works_test() {
  let p =
    pipeline.new("string_pipeline", "1.0.0")
    |> pipeline.add_step("step_a", fn(_ctx, _input) { Ok(dynamic.string("a")) })
    |> pipeline.add_step("step_b", fn(_ctx, _input) { Ok(dynamic.string("b")) })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

pub fn string_deps_still_work_test() {
  let p =
    pipeline.new("string_deps", "1.0.0")
    |> pipeline.add_step_with_deps(
      "root",
      fn(_ctx, _input) { Ok(dynamic.string("root")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "child",
      fn(_ctx, _input) { Ok(dynamic.string("child")) },
      ["root"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)
  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// ---------------------------------------------------------------------------
// Error cases with typed IDs
// ---------------------------------------------------------------------------

pub fn typed_invalid_dep_detected_test() {
  let p =
    pipeline.typed("invalid_dep", "1.0.0", build_step_to_string)
    |> pipeline.add_step_with_deps(
      Checkout,
      fn(_ctx, _input) { Ok(dynamic.string("ok")) },
      [],
    )
    // Package depends on Build, but Build is not in the pipeline
    |> pipeline.add_step_with_deps(
      Package,
      fn(_ctx, _input) { Ok(dynamic.string("ok")) },
      [Build],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)
  result.result |> should.be_error()
}

pub fn typed_error_propagation_test() {
  let p =
    pipeline.typed("error_typed", "1.0.0", build_step_to_string)
    |> pipeline.add_step(Checkout, fn(_ctx, _input) {
      Error(types.StepFailure(message: "checkout failed"))
    })
    |> pipeline.add_step(Build, fn(_ctx, _input) {
      Ok(dynamic.string("should not run"))
    })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.nil(), config)
  result.result |> should.be_error()
  list.length(result.trace) |> should.equal(2)
  // First step failed, second skipped
  let first_trace = list.first(result.trace)
  case first_trace {
    Ok(t) -> t.step_name |> should.equal("checkout")
    Error(_) -> Nil
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

import gleam/int

fn int_to_string(n: Int) -> String {
  int.to_string(n)
}
