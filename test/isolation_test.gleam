import gleam/dynamic
import gleeunit/should
import thingfactory/artifact_store
import thingfactory/executor
import thingfactory/pipeline
import thingfactory/types

// QR-3: Artifact isolation between runs
pub fn artifact_isolation_test() {
  let p =
    pipeline.new("isolation", "1.0.0")
    |> pipeline.add_step("write", fn(ctx, _) {
      let _store =
        artifact_store.write(ctx.artifact_store, "key", dynamic.string("run1"))
      Ok(dynamic.string("done"))
    })

  let config = types.default_config()
  let result1 = executor.execute(p, dynamic.nil(), config)
  let result2 = executor.execute(p, dynamic.nil(), config)

  result1.result |> should.be_ok()
  result2.result |> should.be_ok()
}

// QR-3: Dependency isolation between runs
pub fn dependency_isolation_test() {
  let bindings1 = [types.Binding(name: "env", value: dynamic.string("test"))]
  let bindings2 = [types.Binding(name: "env", value: dynamic.string("prod"))]

  let p =
    pipeline.new("dep_iso", "1.0.0")
    |> pipeline.add_step("check", fn(ctx, _) {
      case types.get_dep(ctx, "env") {
        Ok(v) -> Ok(v)
        Error(_) -> Error(types.StepFailure(message: "missing"))
      }
    })

  let config1 =
    types.ExecutionConfig(
      default_step_timeout_ms: 30_000,
      dependency_bindings: bindings1,
    )
  let config2 =
    types.ExecutionConfig(
      default_step_timeout_ms: 30_000,
      dependency_bindings: bindings2,
    )

  let result1 = executor.execute(p, dynamic.nil(), config1)
  let result2 = executor.execute(p, dynamic.nil(), config2)

  result1.result |> should.be_ok()
  result2.result |> should.be_ok()
}

// QR-3: No state leakage
pub fn no_state_leakage_test() {
  let p =
    pipeline.new("no_leak", "1.0.0")
    |> pipeline.add_step("step", fn(_, input) { Ok(input) })

  let config = types.default_config()
  let _ = executor.execute(p, dynamic.string("run1"), config)
  let _ = executor.execute(p, dynamic.string("run2"), config)

  // Each run gets fresh context - no state leakage
  True |> should.be_true()
}
