import gleam/dynamic
import gleeunit/should
import thingfactory/pipeline
import thingfactory/test_helpers
import thingfactory/types

// FR-7: Mock success
pub fn mock_success_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(_, _) { panic as "should not call real" })

  let mocks = [
    test_helpers.mock_step_success("step1", dynamic.string("mocked")),
  ]
  let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())

  result.result |> should.equal(Ok(dynamic.string("mocked")))
}

// FR-7: Mock error
pub fn mock_error_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(_, _) { panic as "should not call" })

  let mocks = [
    test_helpers.mock_step_error(
      "step1",
      types.StepFailure(message: "mock fail"),
    ),
  ]
  let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())

  result.result |> should.be_error()
}

// FR-7: Partial mocks (only some steps mocked)
pub fn partial_mocks_test() {
  let p =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_step("step1", fn(_, _) { Ok(dynamic.string("real")) })
    |> pipeline.add_step("step2", fn(_, _) { panic as "should not call" })

  let mocks = [
    test_helpers.mock_step_success("step2", dynamic.string("mocked")),
  ]
  let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())

  result.result |> should.be_ok()
}
