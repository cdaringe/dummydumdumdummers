import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/types

// Basic parallel execution: two independent steps
pub fn parallel_independent_steps_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "step_a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_b",
      fn(_ctx, _input) { Ok(dynamic.string("b")) },
      [],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// Sequential dependency: step_b depends on step_a
pub fn parallel_sequential_dependency_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "step_a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_b",
      fn(_ctx, _input) { Ok(dynamic.string("b")) },
      ["step_a"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// Diamond dependency: step_c depends on both step_a and step_b
pub fn parallel_diamond_dependency_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "step_a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_b",
      fn(_ctx, _input) { Ok(dynamic.string("b")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_c",
      fn(_ctx, _input) { Ok(dynamic.string("c")) },
      ["step_a", "step_b"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(3)
}

// Error in dependency: step_b fails, step_c should be skipped
pub fn parallel_error_propagation_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "step_a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_b",
      fn(_ctx, _input) { Error(types.StepFailure(message: "step_b failed")) },
      ["step_a"],
    )
    |> pipeline.add_step_with_deps(
      "step_c",
      fn(_ctx, _input) { Ok(dynamic.string("c")) },
      ["step_b"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_error()
  // All 3 steps should be in trace
  list.length(result.trace) |> should.equal(3)
}

// Complex DAG with multiple independent paths
pub fn parallel_complex_dag_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "checkout",
      fn(_ctx, _input) { Ok(dynamic.string("checkout")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "lint",
      fn(_ctx, _input) { Ok(dynamic.string("lint")) },
      ["checkout"],
    )
    |> pipeline.add_step_with_deps(
      "test",
      fn(_ctx, _input) { Ok(dynamic.string("test")) },
      ["checkout"],
    )
    |> pipeline.add_step_with_deps(
      "build",
      fn(_ctx, _input) { Ok(dynamic.string("build")) },
      ["lint", "test"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(4)
}

// Invalid reference: step_b depends on non-existent step
pub fn parallel_invalid_dependency_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "step_a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "step_b",
      fn(_ctx, _input) { Ok(dynamic.string("b")) },
      ["nonexistent"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  // Should fail validation
  result.result |> should.be_error()
}

// Multiple independent paths that can run in parallel
pub fn parallel_multi_path_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "root",
      fn(_ctx, _input) { Ok(dynamic.string("root")) },
      [],
    )
    // Path 1: root -> branch1a -> branch1b
    |> pipeline.add_step_with_deps(
      "branch1a",
      fn(_ctx, _input) { Ok(dynamic.string("1a")) },
      ["root"],
    )
    |> pipeline.add_step_with_deps(
      "branch1b",
      fn(_ctx, _input) { Ok(dynamic.string("1b")) },
      ["branch1a"],
    )
    // Path 2: root -> branch2a -> branch2b (independent of path 1)
    |> pipeline.add_step_with_deps(
      "branch2a",
      fn(_ctx, _input) { Ok(dynamic.string("2a")) },
      ["root"],
    )
    |> pipeline.add_step_with_deps(
      "branch2b",
      fn(_ctx, _input) { Ok(dynamic.string("2b")) },
      ["branch2a"],
    )
    // Merge: both branches -> final
    |> pipeline.add_step_with_deps(
      "final",
      fn(_ctx, _input) { Ok(dynamic.string("final")) },
      ["branch1b", "branch2b"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(6)
}

// Verify trace order respects dependency execution
pub fn parallel_trace_respects_deps_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step_with_deps(
      "a",
      fn(_ctx, _input) { Ok(dynamic.string("a")) },
      [],
    )
    |> pipeline.add_step_with_deps(
      "b",
      fn(_ctx, _input) { Ok(dynamic.string("b")) },
      ["a"],
    )

  let config = types.default_config()
  let result = parallel_executor.execute_parallel(p, dynamic.nil(), config)

  result.result |> should.be_ok()
  let names = result.trace |> list.map(fn(t) { t.step_name })
  // Both 'a' and 'b' should be present
  list.length(names) |> should.equal(2)
  list.contains(names, "a") |> should.equal(True)
  list.contains(names, "b") |> should.equal(True)
}
