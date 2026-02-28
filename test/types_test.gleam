import gleeunit/should
import thingfactory/types

// FR-3: Error types are properly defined
pub fn step_failure_test() {
  let error = types.StepFailure(message: "test error")
  error |> should.equal(types.StepFailure(message: "test error"))
}

pub fn step_timeout_test() {
  let error = types.StepTimeout(step: "step1", limit_ms: 1000)
  error |> should.equal(types.StepTimeout(step: "step1", limit_ms: 1000))
}

pub fn artifact_not_found_test() {
  let error = types.ArtifactNotFound(key: "missing")
  error |> should.equal(types.ArtifactNotFound(key: "missing"))
}

pub fn pipeline_error_test() {
  let step_err = types.StepFailure(message: "inner")
  let error = types.StepError(step_name: "step1", error: step_err)
  error |> should.equal(types.StepError(step_name: "step1", error: step_err))
}

pub fn load_error_test() {
  let error = types.LoadError(reason: "not found")
  error |> should.equal(types.LoadError(reason: "not found"))
}

// QR-2: All error types are explicit
pub fn validation_error_test() {
  let error = types.ValidationError(reason: "invalid")
  error |> should.equal(types.ValidationError(reason: "invalid"))
}
