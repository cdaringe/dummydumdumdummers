/// A reusable step library demonstrating how pipeline steps can be packaged,
/// exported from a Gleam module, and imported into other pipelines alongside
/// locally-defined steps.
///
/// This module simulates the pattern of an external library providing reusable
/// step factory functions. Any Gleam module (local or third-party package) can
/// export step factories with the signature:
///
///   fn(Context, Dynamic) -> StepResult(Dynamic)
///
/// Those steps integrate seamlessly with locally-defined steps via the
/// standard pipeline builder API.
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/string
import thingfactory/types

/// Validate that string input is non-empty.
/// Returns Ok(input) unchanged, or Error(StepFailure) if empty/non-string.
pub fn validate_non_empty() -> fn(types.Context, Dynamic) ->
  types.StepResult(Dynamic) {
  fn(_ctx: types.Context, input: Dynamic) {
    case decode.run(input, decode.string) {
      Ok("") -> Error(types.StepFailure(message: "Input must not be empty"))
      Ok(s) -> Ok(dynamic.string(s))
      Error(_) -> Error(types.StepFailure(message: "Input must be a string"))
    }
  }
}

/// Transform string input to uppercase.
pub fn to_uppercase() -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  fn(_ctx: types.Context, input: Dynamic) {
    case decode.run(input, decode.string) {
      Ok(s) -> Ok(dynamic.string(string.uppercase(s)))
      Error(_) -> Error(types.StepFailure(message: "Input must be a string"))
    }
  }
}

/// Prepend a label to string input.
pub fn prefix(
  label: String,
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  fn(_ctx: types.Context, input: Dynamic) {
    case decode.run(input, decode.string) {
      Ok(s) -> Ok(dynamic.string(label <> s))
      Error(_) -> Error(types.StepFailure(message: "Input must be a string"))
    }
  }
}
