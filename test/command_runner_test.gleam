import gleam/dict
import gleam/dynamic
import gleam/string
import gleeunit/should
import thingfactory/command_runner
import thingfactory/message_store
import thingfactory/secret_manager
import thingfactory/types

pub fn run_echo_test() {
  let result = command_runner.run("echo", ["hello"])
  result |> should.be_ok()
  let assert Ok(output) = result
  output.exit_code |> should.equal(0)
  string.contains(output.stdout, "hello") |> should.be_true()
}

pub fn run_with_multiple_args_test() {
  let result = command_runner.run("echo", ["hello", "world"])
  result |> should.be_ok()
  let assert Ok(output) = result
  output.exit_code |> should.equal(0)
  string.contains(output.stdout, "hello world") |> should.be_true()
}

pub fn run_nonexistent_command_test() {
  let result = command_runner.run("nonexistent_command_xyz_42", [])
  result |> should.be_error()
}

pub fn run_failing_command_test() {
  // `false` is a standard Unix command that always exits with code 1
  let result = command_runner.run("false", [])
  result |> should.be_ok()
  let assert Ok(output) = result
  // exit code should be non-zero
  { output.exit_code != 0 } |> should.be_true()
}

pub fn step_success_test() {
  let step_fn = command_runner.step("echo", ["ok"])
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  let result = step_fn(ctx, dynamic.nil())
  result |> should.be_ok()
}

pub fn step_failure_test() {
  let step_fn = command_runner.step("false", [])
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  let result = step_fn(ctx, dynamic.nil())
  result |> should.be_error()
}

pub fn step_not_found_test() {
  let step_fn = command_runner.step("nonexistent_command_xyz_42", [])
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  let result = step_fn(ctx, dynamic.nil())
  result |> should.be_error()
}

pub fn sh_wrapper_success_test() {
  let step_fn = command_runner.sh("echo wrapped")
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  let result = step_fn(ctx, dynamic.nil())
  result |> should.be_ok()
}

pub fn sh_in_dir_success_test() {
  let step_fn = command_runner.sh_in_dir("echo wrapped_dir", ".")
  let ctx =
    types.Context(
      artifact_store: dict.new(),
      message_store: message_store.new(),
      deps: dict.new(),
      secret_store: secret_manager.new(),
    )
  let result = step_fn(ctx, dynamic.nil())
  result |> should.be_ok()
}
