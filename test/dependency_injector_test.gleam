import gleam/dict
import gleam/dynamic
import gleeunit/should
import thingfactory/dependency_injector
import thingfactory/message_store
import thingfactory/secret_manager
import thingfactory/types

// FR-9: Build creates dict from bindings
pub fn build_test() {
  let bindings = [
    types.Binding(name: "db", value: dynamic.string("postgres")),
    types.Binding(name: "api", value: dynamic.string("rest")),
  ]

  let deps = dependency_injector.build(bindings)
  let size = dict.size(deps)

  size |> should.equal(2)
}

// FR-9: Missing dependency returns error
pub fn missing_dependency_test() {
  let bindings = [types.Binding(name: "db", value: dynamic.string("postgres"))]
  let deps = dependency_injector.build(bindings)
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: deps,
      secret_store: secret_manager.new(),
    )

  let result = types.get_dep(ctx, "missing")
  result |> should.be_error()
}

// FR-9: Present dependency returns value
pub fn present_dependency_test() {
  let bindings = [types.Binding(name: "db", value: dynamic.string("postgres"))]
  let deps = dependency_injector.build(bindings)
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: deps,
      secret_store: secret_manager.new(),
    )

  let result = types.get_dep(ctx, "db")
  result |> should.equal(Ok(dynamic.string("postgres")))
}
