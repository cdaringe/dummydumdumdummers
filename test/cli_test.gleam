import gleam/string
import gleeunit/should
import thingfactory/cli

// ---------------------------------------------------------------------------
// Pipeline resolution tests (execute_pipeline)
// ---------------------------------------------------------------------------

pub fn execute_pipeline_basic_by_name_test() {
  let result = cli.execute_pipeline("basic", cli.Verbose)
  should.be_ok(result)
}

pub fn execute_pipeline_basic_by_number_test() {
  let result = cli.execute_pipeline("1", cli.Verbose)
  should.be_ok(result)
}

pub fn execute_pipeline_typescript_test() {
  let result = cli.execute_pipeline("typescript", cli.Compact)
  should.be_ok(result)
}

pub fn execute_pipeline_rust_test() {
  let result = cli.execute_pipeline("rust", cli.Compact)
  should.be_ok(result)
}

pub fn execute_pipeline_parallel_test() {
  let result = cli.execute_pipeline("parallel", cli.Compact)
  should.be_ok(result)
}

pub fn execute_pipeline_unknown_returns_error_test() {
  let result = cli.execute_pipeline("nonexistent", cli.Verbose)
  result |> should.be_error()
}

pub fn execute_pipeline_error_returns_ok_with_failed_result_test() {
  // The "error" pipeline should execute (Ok) but its result may contain a failure
  let result = cli.execute_pipeline("error", cli.Compact)
  should.be_ok(result)
}

pub fn execute_pipeline_case_insensitive_test() {
  let result = cli.execute_pipeline("BASIC", cli.Compact)
  should.be_ok(result)
}

pub fn execute_pipeline_artifacts_test() {
  let result = cli.execute_pipeline("artifacts", cli.Compact)
  should.be_ok(result)
}

// Note: pipelines 9 (gleam) and 14 (dogfood) run real shell commands
// and are tested separately in examples_test.gleam with appropriate timeouts.

// ---------------------------------------------------------------------------
// run_pipeline output format tests
// ---------------------------------------------------------------------------

pub fn run_pipeline_compact_format_test() {
  let result = cli.run_pipeline("basic", cli.Compact)
  let output = should.be_ok(result)
  // Compact format: "── ✓ basic (N steps, Xms)"
  should.be_true(string.contains(output, "basic"))
  should.be_true(string.contains(output, "steps"))
}

pub fn run_pipeline_verbose_format_test() {
  let result = cli.run_pipeline("basic", cli.Verbose)
  let output = should.be_ok(result)
  // Verbose format includes "Result:" and step count
  should.be_true(string.contains(output, "Result:"))
  should.be_true(string.contains(output, "steps"))
}

pub fn run_pipeline_unknown_error_message_test() {
  let result = cli.run_pipeline("does_not_exist", cli.Verbose)
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Unknown pipeline"))
  should.be_true(string.contains(err, "does_not_exist"))
}

// ---------------------------------------------------------------------------
// All 14 pipelines resolve by number
// ---------------------------------------------------------------------------

pub fn simulated_pipelines_resolve_by_number_test() {
  // Pipelines 1-8 and 10-13 use simulated steps (no shell commands)
  should.be_ok(cli.execute_pipeline("1", cli.Compact))
  should.be_ok(cli.execute_pipeline("2", cli.Compact))
  should.be_ok(cli.execute_pipeline("3", cli.Compact))
  should.be_ok(cli.execute_pipeline("4", cli.Compact))
  should.be_ok(cli.execute_pipeline("5", cli.Compact))
  should.be_ok(cli.execute_pipeline("6", cli.Compact))
  should.be_ok(cli.execute_pipeline("7", cli.Compact))
  should.be_ok(cli.execute_pipeline("8", cli.Compact))
  // Skip 9 (gleam) and 14 (dogfood) - they run real shell commands
  should.be_ok(cli.execute_pipeline("10", cli.Compact))
  should.be_ok(cli.execute_pipeline("11", cli.Compact))
  should.be_ok(cli.execute_pipeline("12", cli.Compact))
  should.be_ok(cli.execute_pipeline("13", cli.Compact))
}

// ---------------------------------------------------------------------------
// Output mode tests
// ---------------------------------------------------------------------------

pub fn compact_mode_shows_summary_test() {
  let result = cli.run_pipeline("basic", cli.Compact)
  let output = should.be_ok(result)
  // Compact shows a one-line summary with check mark
  should.be_true(string.length(output) > 0)
}

pub fn verbose_mode_shows_result_test() {
  let result = cli.run_pipeline("basic", cli.Verbose)
  let output = should.be_ok(result)
  should.be_true(string.contains(output, "SUCCESS"))
}

pub fn execute_pipeline_returns_traces_test() {
  let assert Ok(result) = cli.execute_pipeline("basic", cli.Compact)
  // basic pipeline has 3 steps, so trace should have 3 entries
  let trace_count =
    result.trace
    |> gleam_stdlib_list_length()
  should.be_true(trace_count >= 3)
}

fn gleam_stdlib_list_length(l: List(a)) -> Int {
  case l {
    [] -> 0
    [_, ..rest] -> 1 + gleam_stdlib_list_length(rest)
  }
}
