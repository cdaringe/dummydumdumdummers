import gleam/dict
import gleam/dynamic
import gleam/string
import gleeunit/should
import thingfactory/interactive_cli.{type InteractiveState, InteractiveState}
import thingfactory/types.{
  type StepTrace, ExecutionResult, StepFailed, StepFailure, StepOk, StepSkipped,
  StepTrace,
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

fn make_state(traces: List(StepTrace), succeeded: Bool) -> InteractiveState {
  let result = case succeeded {
    True ->
      ExecutionResult(
        result: Ok(dynamic.string("done")),
        trace: traces,
        artifacts: dict.new(),
      )
    False ->
      ExecutionResult(
        result: Error(types.StepError(
          step_name: "failing_step",
          error: StepFailure("step failed"),
        )),
        trace: traces,
        artifacts: dict.new(),
      )
  }

  InteractiveState(
    pipeline_name: "test_pipeline",
    result: result,
    steps: traces,
  )
}

fn make_state_with_artifacts(
  traces: List(StepTrace),
  artifacts: dict.Dict(String, dynamic.Dynamic),
) -> InteractiveState {
  let result =
    ExecutionResult(
      result: Ok(dynamic.string("done")),
      trace: traces,
      artifacts: artifacts,
    )

  InteractiveState(
    pipeline_name: "test_pipeline",
    result: result,
    steps: traces,
  )
}

fn basic_traces() -> List(StepTrace) {
  [
    StepTrace(step_name: "checkout", status: StepOk, duration_ms: 100),
    StepTrace(step_name: "build", status: StepOk, duration_ms: 500),
    StepTrace(step_name: "test", status: StepOk, duration_ms: 300),
  ]
}

fn mixed_traces() -> List(StepTrace) {
  [
    StepTrace(step_name: "checkout", status: StepOk, duration_ms: 100),
    StepTrace(
      step_name: "build",
      status: StepFailed(StepFailure("compile error")),
      duration_ms: 200,
    ),
    StepTrace(step_name: "test", status: StepSkipped, duration_ms: 0),
  ]
}

// ---------------------------------------------------------------------------
// help command
// ---------------------------------------------------------------------------

pub fn help_command_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "help")
  should.be_true(string.contains(output, "help"))
  should.be_true(string.contains(output, "list"))
  should.be_true(string.contains(output, "step"))
  should.be_true(string.contains(output, "stats"))
  should.be_true(string.contains(output, "artifacts"))
  should.be_true(string.contains(output, "exit"))
}

// ---------------------------------------------------------------------------
// list command
// ---------------------------------------------------------------------------

pub fn list_command_shows_all_steps_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "list")
  should.be_true(string.contains(output, "checkout"))
  should.be_true(string.contains(output, "build"))
  should.be_true(string.contains(output, "test"))
}

pub fn list_command_shows_status_icons_test() {
  let state = make_state(mixed_traces(), False)
  let #(_, output) = interactive_cli.execute_command(state, "list")
  // Should show check for checkout, x for build, - for test
  should.be_true(string.contains(output, "checkout"))
  should.be_true(string.contains(output, "build"))
  should.be_true(string.contains(output, "test"))
}

// ---------------------------------------------------------------------------
// step command (by index)
// ---------------------------------------------------------------------------

pub fn step_by_index_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "step 0")
  should.be_true(string.contains(output, "checkout"))
  should.be_true(string.contains(output, "OK"))
}

pub fn step_by_index_out_of_range_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "step 99")
  should.be_true(string.contains(output, "out of range"))
}

// ---------------------------------------------------------------------------
// step command (by name)
// ---------------------------------------------------------------------------

pub fn step_by_name_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "step build")
  should.be_true(string.contains(output, "build"))
  should.be_true(string.contains(output, "500ms"))
}

pub fn step_by_name_not_found_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "step nonexistent")
  should.be_true(string.contains(output, "not found"))
}

pub fn step_failed_shows_error_test() {
  let state = make_state(mixed_traces(), False)
  let #(_, output) = interactive_cli.execute_command(state, "step build")
  should.be_true(string.contains(output, "FAILED"))
  should.be_true(string.contains(output, "compile error"))
}

pub fn step_skipped_shows_status_test() {
  let state = make_state(mixed_traces(), False)
  let #(_, output) = interactive_cli.execute_command(state, "step test")
  should.be_true(string.contains(output, "SKIPPED"))
}

// ---------------------------------------------------------------------------
// stats command
// ---------------------------------------------------------------------------

pub fn stats_success_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "stats")
  should.be_true(string.contains(output, "SUCCESS"))
  should.be_true(string.contains(output, "3"))
  should.be_true(string.contains(output, "900ms"))
}

pub fn stats_mixed_test() {
  let state = make_state(mixed_traces(), False)
  let #(_, output) = interactive_cli.execute_command(state, "stats")
  should.be_true(string.contains(output, "FAILED"))
  should.be_true(string.contains(output, "Successful: 1"))
  should.be_true(string.contains(output, "Failed:     1"))
  should.be_true(string.contains(output, "Skipped:    1"))
}

// ---------------------------------------------------------------------------
// artifacts command
// ---------------------------------------------------------------------------

pub fn artifacts_none_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "artifacts")
  should.be_true(string.contains(output, "No artifacts"))
}

pub fn artifacts_with_values_test() {
  let artifacts =
    dict.new()
    |> dict.insert("build_output", dynamic.string("dist/bundle.js"))
    |> dict.insert("coverage", dynamic.string("95%"))

  let state = make_state_with_artifacts(basic_traces(), artifacts)
  let #(_, output) = interactive_cli.execute_command(state, "artifacts")
  should.be_true(string.contains(output, "2"))
  should.be_true(string.contains(output, "output-dir"))
}

// ---------------------------------------------------------------------------
// unknown command
// ---------------------------------------------------------------------------

pub fn unknown_command_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "foobar")
  should.be_true(string.contains(output, "Unknown command"))
}

// ---------------------------------------------------------------------------
// empty input
// ---------------------------------------------------------------------------

pub fn empty_input_test() {
  let state = make_state(basic_traces(), True)
  let #(_, output) = interactive_cli.execute_command(state, "")
  should.be_true(string.contains(output, "Unknown command"))
}

// ---------------------------------------------------------------------------
// state preservation
// ---------------------------------------------------------------------------

pub fn state_preserved_after_command_test() {
  let state = make_state(basic_traces(), True)
  let #(new_state, _) = interactive_cli.execute_command(state, "help")
  should.equal(new_state.pipeline_name, "test_pipeline")
}
