/// Dependency Injector — builds the deps Dict from ExecutionConfig bindings.
///
/// Steps receive dependencies via Context.deps and call types.get_dep/2 (FR-9).
/// Missing dependencies produce a typed StepFailure — no silent failures (QR-2).
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import thingfactory/types.{type Binding}

/// Build a dependency map from a list of Binding values.
/// The resulting Dict is passed into the Context for each step.
pub fn build(bindings: List(Binding)) -> Dict(String, Dynamic) {
  list.fold(bindings, dict.new(), fn(acc, binding) {
    dict.insert(acc, binding.name, binding.value)
  })
}
