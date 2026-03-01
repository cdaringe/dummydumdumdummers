import gleam/string
import gleeunit/should
import thingfactory/cli

pub fn parse_list_command_test() {
  let parsed = cli.parse_args(["list"])
  should.equal(parsed, Ok(cli.ListPipelines))
}

pub fn parse_run_command_with_flags_test() {
  let parsed =
    cli.parse_args([
      "run",
      "-f",
      "src/thingfactory/examples.gleam",
      "-c",
      "-o",
      "./out",
      "basic_pipeline",
    ])

  let assert Ok(command) = parsed
  case command {
    cli.Run(pipeline_selector, source_file, compact, interactive, output_dir) -> {
      should.equal(pipeline_selector, "basic_pipeline")
      should.equal(source_file, Ok("src/thingfactory/examples.gleam"))
      should.equal(compact, True)
      should.equal(interactive, False)
      should.equal(output_dir, Ok("./out"))
    }
    _ -> should.fail()
  }
}

pub fn parse_inspect_command_test() {
  let parsed =
    cli.parse_args([
      "inspect",
      "-f",
      "src/thingfactory/examples.gleam",
      "basic_pipeline",
    ])

  let assert Ok(command) = parsed
  case command {
    cli.Inspect(pipeline_selector, source_file) -> {
      should.equal(pipeline_selector, "basic_pipeline")
      should.equal(source_file, Ok("src/thingfactory/examples.gleam"))
    }
    _ -> should.fail()
  }
}

pub fn parse_results_command_test() {
  let parsed = cli.parse_args(["results", "thingfactory@examples:basic_pipeline"])
  let assert Ok(command) = parsed
  case command {
    cli.Results(pipeline_selector, source_file) -> {
      should.equal(pipeline_selector, "thingfactory@examples:basic_pipeline")
      should.equal(source_file, Error(Nil))
    }
    _ -> should.fail()
  }
}

pub fn parse_artifacts_command_test() {
  let parsed =
    cli.parse_args([
      "artifacts",
      "-f",
      "src/thingfactory/examples.gleam",
      "-o",
      "./artifacts",
      "artifacts_pipeline",
    ])

  let assert Ok(command) = parsed
  case command {
    cli.Artifacts(pipeline_selector, source_file, output_dir) -> {
      should.equal(pipeline_selector, "artifacts_pipeline")
      should.equal(source_file, Ok("src/thingfactory/examples.gleam"))
      should.equal(output_dir, "./artifacts")
    }
    _ -> should.fail()
  }
}

pub fn parse_artifacts_requires_output_dir_test() {
  let parsed = cli.parse_args(["artifacts", "thingfactory@examples:basic_pipeline"])
  let err = should.be_error(parsed)
  should.be_true(string.contains(err, "output-dir"))
}

pub fn execute_pipeline_runtime_ref_test() {
  let result =
    cli.execute_pipeline("thingfactory@examples:basic_pipeline", cli.Verbose)
  should.be_ok(result)
}

pub fn execute_pipeline_invalid_ref_format_returns_error_test() {
  let result = cli.execute_pipeline("basic", cli.Verbose)
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Invalid pipeline reference"))
}

pub fn execute_pipeline_unknown_module_returns_error_test() {
  let result =
    cli.execute_pipeline("missing@module:basic_pipeline", cli.Verbose)
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Pipeline module not loadable"))
}

pub fn execute_pipeline_unknown_function_returns_error_test() {
  let result =
    cli.execute_pipeline("thingfactory@examples:not_a_pipeline", cli.Compact)
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Pipeline function not found"))
}

pub fn execute_pipeline_from_file_test() {
  let result =
    cli.execute_pipeline_from_file(
      "src/thingfactory/examples.gleam",
      "basic_pipeline",
      cli.Verbose,
    )
  should.be_ok(result)
}

pub fn execute_pipeline_from_missing_file_returns_error_test() {
  let result =
    cli.execute_pipeline_from_file(
      "src/thingfactory/missing.gleam",
      "basic_pipeline",
      cli.Verbose,
    )
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Pipeline source file not found"))
}

pub fn run_pipeline_compact_format_test() {
  let result =
    cli.run_pipeline("thingfactory@examples:basic_pipeline", cli.Compact)
  let output = should.be_ok(result)
  should.be_true(string.contains(output, "thingfactory@examples:basic_pipeline"))
  should.be_true(string.contains(output, "steps"))
}

pub fn run_pipeline_verbose_format_test() {
  let result =
    cli.run_pipeline("thingfactory@examples:basic_pipeline", cli.Verbose)
  let output = should.be_ok(result)
  should.be_true(string.contains(output, "Result:"))
  should.be_true(string.contains(output, "steps"))
}

pub fn run_pipeline_unknown_error_message_test() {
  let result = cli.run_pipeline("does_not_exist", cli.Verbose)
  let err = should.be_error(result)
  should.be_true(string.contains(err, "Invalid pipeline reference"))
}

pub fn execute_pipeline_returns_traces_test() {
  let assert Ok(result) =
    cli.execute_pipeline("thingfactory@examples:basic_pipeline", cli.Compact)
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
