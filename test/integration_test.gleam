import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/artifact_store
import thingfactory/executor
import thingfactory/loader
import thingfactory/pipeline
import thingfactory/registry
import thingfactory/test_helpers
import thingfactory/types

// FR-1 + FR-2 + FR-8: Full pipeline execution
pub fn full_pipeline_execution_test() {
  let p =
    pipeline.new("integration", "1.0.0")
    |> pipeline.add_step("step1", fn(_, _input) {
      Ok(dynamic.string("processed"))
    })
    |> pipeline.add_step("step2", fn(_, input) { Ok(input) })

  let config = types.default_config()
  let result = executor.execute(p, dynamic.string("input"), config)

  result.result |> should.be_ok()
  list.length(result.trace) |> should.equal(2)
}

// FR-3 + FR-7: Error handling with mocks
pub fn error_handling_with_mocks_test() {
  let p =
    pipeline.new("error_test", "1.0.0")
    |> pipeline.add_step("fail", fn(_, _) {
      Error(types.StepFailure(message: "boom"))
    })

  let mocks = [
    test_helpers.mock_step_error(
      "fail",
      types.StepFailure(message: "mocked boom"),
    ),
  ]
  let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())

  result.result |> should.be_error()
}

// FR-4 + FR-9: Artifact sharing with dependencies
pub fn artifact_and_deps_test() {
  let bindings = [types.Binding(name: "config", value: dynamic.string("prod"))]
  let p =
    pipeline.new("artifact_test", "1.0.0")
    |> pipeline.add_step_with_ctx("write", fn(ctx, _) {
      let updated_store =
        artifact_store.write(ctx.artifact_store, "data", dynamic.int(42))
      let updated_ctx = types.Context(..ctx, artifact_store: updated_store)
      Ok(#(dynamic.string("written"), updated_ctx))
    })
    |> pipeline.add_step("read", fn(ctx, _) {
      case artifact_store.read(ctx.artifact_store, "data") {
        Ok(v) -> Ok(v)
        Error(_) -> Error(types.StepFailure(message: "missing"))
      }
    })

  let config =
    types.ExecutionConfig(
      default_step_timeout_ms: 30_000,
      dependency_bindings: bindings,
    )
  let result = executor.execute(p, dynamic.nil(), config)

  result.result |> should.be_ok()
}

// FR-6: Registry integration
pub fn registry_integration_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "reg_test", version: "1.0.0")
  let p = pipeline.new("reg_test", "1.0.0")
  let artifact = registry.create_artifact(id, p)

  let reg = registry.register(reg, id, artifact) |> should.be_ok()
  registry.has_pipeline(reg, id) |> should.be_true()
}

// FR-8: Loader integration
pub fn loader_integration_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "load_test", version: "1.0.0")
  let p = pipeline.new("load_test", "1.0.0")
  let artifact = registry.create_artifact(id, p)
  let reg = registry.register(reg, id, artifact) |> should.be_ok()

  let result = loader.load_pipeline(reg, id)
  result |> should.be_ok()
}
