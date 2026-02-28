import gleam/dynamic
import gleeunit/should
import thingfactory/registry
import thingfactory/types

// FR-6: Register and resolve works
pub fn register_and_resolve_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "test", version: "1.0.0")
  let artifact = registry.create_artifact(id, dynamic.string("pipeline"))

  let reg = registry.register(reg, id, artifact) |> should.be_ok()
  let result = registry.resolve(reg, id)

  result |> should.be_ok()
  case result {
    Ok(a) -> a.pipeline |> should.equal(dynamic.string("pipeline"))
    Error(_) -> panic as "expected ok"
  }
}

// FR-6: Version conflict detection
pub fn version_conflict_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "test", version: "1.0.0")
  let artifact = registry.create_artifact(id, dynamic.string("v1"))

  let reg = registry.register(reg, id, artifact) |> should.be_ok()
  let artifact2 = registry.create_artifact(id, dynamic.string("v2"))
  let result = registry.register(reg, id, artifact2)

  result |> should.be_error()
  case result {
    Error(types.VersionConflict(conflict_id)) -> conflict_id |> should.equal(id)
    _ -> panic as "expected VersionConflict"
  }
}

// FR-6: Not found error
pub fn not_found_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "missing", version: "1.0.0")
  let result = registry.resolve(reg, id)

  result |> should.be_error()
  case result {
    Error(types.NotFound(missing_id)) -> missing_id |> should.equal(id)
    _ -> panic as "expected NotFound"
  }
}

// FR-6: Multiple versions coexist
pub fn multiple_versions_test() {
  let reg = registry.new()
  let id1 = types.PipelineId(name: "test", version: "1.0.0")
  let id2 = types.PipelineId(name: "test", version: "2.0.0")

  let reg =
    registry.register(
      reg,
      id1,
      registry.create_artifact(id1, dynamic.string("v1")),
    )
    |> should.be_ok()
  let reg =
    registry.register(
      reg,
      id2,
      registry.create_artifact(id2, dynamic.string("v2")),
    )
    |> should.be_ok()

  registry.resolve(reg, id1) |> should.be_ok()
  registry.resolve(reg, id2) |> should.be_ok()
}

// FR-6: has_pipeline works
pub fn has_pipeline_test() {
  let reg = registry.new()
  let id = types.PipelineId(name: "test", version: "1.0.0")

  registry.has_pipeline(reg, id) |> should.be_false()

  let reg =
    registry.register(reg, id, registry.create_artifact(id, dynamic.int(1)))
    |> should.be_ok()
  registry.has_pipeline(reg, id) |> should.be_true()
}
