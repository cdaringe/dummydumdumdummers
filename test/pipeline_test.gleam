import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/pipeline
import thingfactory/types

// FR-1: Pipeline creation
pub fn pipeline_creation_test() {
  let p = pipeline.new("test", "1.0.0")
  pipeline.id(p)
  |> should.equal(types.PipelineId(name: "test", version: "1.0.0"))
}

// FR-1: Add step
pub fn add_step_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(_, _) { Ok(dynamic.nil()) })

  list.length(pipeline.steps(p)) |> should.equal(1)
}

// FR-1: Multiple steps
pub fn multiple_steps_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("a", fn(_, _) { Ok(dynamic.nil()) })
    |> pipeline.add_step("b", fn(_, _) { Ok(dynamic.nil()) })
    |> pipeline.add_step("c", fn(_, _) { Ok(dynamic.nil()) })

  list.length(pipeline.steps(p)) |> should.equal(3)
}

// FR-5: Custom timeout
pub fn custom_timeout_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.with_timeout(5000)

  pipeline.default_timeout(p) |> should.equal(5000)
}

// FR-5: Default timeout
pub fn default_timeout_test() {
  let p = pipeline.new("test", "1.0.0")
  pipeline.default_timeout(p) |> should.equal(1_800_000)
}
