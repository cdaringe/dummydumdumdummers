import gleeunit/should
import thingfactory/loader
import thingfactory/registry
import thingfactory/types

// FR-8: Load existing pipeline
pub fn load_existing_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "test", version: "1.0.0")
  let artifact = registry.create_artifact(id, "pipeline_value")
  let reg = registry.register(reg, id, artifact) |> should.be_ok()

  let result = loader.load(reg, id)
  result |> should.be_ok()
}

// FR-8: Load returns LoadError for missing
pub fn load_missing_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "missing", version: "1.0.0")

  let result = loader.load(reg, id)
  result |> should.be_error()
  case result {
    Error(types.LoadError(_reason)) -> Nil
    _ -> panic as "expected LoadError"
  }
}

// FR-8: load_pipeline extracts value
pub fn load_pipeline_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "test", version: "1.0.0")
  let artifact = registry.create_artifact(id, 42)
  let reg = registry.register(reg, id, artifact) |> should.be_ok()

  let result = loader.load_pipeline(reg, id)
  result |> should.equal(Ok(42))
}
