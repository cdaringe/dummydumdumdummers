/// Command runner for executing shell commands.
///
/// Provides cross-platform command execution via FFI (JavaScript and Erlang),
/// enabling pipelines to run real build tools, compilers, and scripts.
import gleam/dynamic.{type Dynamic}
import gleam/string
import thingfactory/types

/// Output from a shell command execution.
pub type CommandOutput {
  CommandOutput(exit_code: Int, stdout: String, stderr: String)
}

/// Run a shell command with the given program and arguments.
/// Returns Ok(CommandOutput) on execution (even if exit code is non-zero),
/// or Error(message) if the command could not be started.
pub fn run(program: String, args: List(String)) -> Result(CommandOutput, String) {
  case run_ffi(program, args) {
    Ok(#(exit_code, stdout, stderr)) ->
      Ok(CommandOutput(exit_code: exit_code, stdout: stdout, stderr: stderr))
    Error(msg) -> Error(msg)
  }
}

/// Run a shell command in a specific working directory.
pub fn run_in_dir(
  program: String,
  args: List(String),
  cwd: String,
) -> Result(CommandOutput, String) {
  case run_in_dir_ffi(program, args, cwd) {
    Ok(#(exit_code, stdout, stderr)) ->
      Ok(CommandOutput(exit_code: exit_code, stdout: stdout, stderr: stderr))
    Error(msg) -> Error(msg)
  }
}

/// Create a step function that runs a shell command.
/// Returns a function compatible with pipeline.add_step that:
/// - Runs the specified command with arguments
/// - Returns Ok(success_msg) if the command exits with code 0
/// - Returns Error(StepFailure) if the command fails or can't be started
pub fn step(
  program: String,
  args: List(String),
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  build_step(program, fn() { run(program, args) })
}

/// Create a step function that runs a shell command in a specific directory.
/// Use this to run build tools against example projects in subdirectories.
pub fn step_in_dir(
  program: String,
  args: List(String),
  cwd: String,
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  build_step(program, fn() { run_in_dir(program, args, cwd) })
}

/// Run a single shell command string via `sh -c`, trimming all boilerplate
/// down to the command itself. Useful for quick program invocations or
/// one-off scripts in pipelines.
pub fn sh(
  command: String,
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  build_step("sh -c " <> command, fn() { run("sh", ["-c", command]) })
}

/// Same as `sh/1`, but executes within the provided working directory.
pub fn sh_in_dir(
  command: String,
  cwd: String,
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  build_step("sh -c " <> command <> " in " <> cwd, fn() {
    run_in_dir("sh", ["-c", command], cwd)
  })
}

fn exit_code_to_string(code: Int) -> String {
  case code {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    127 -> "127"
    _ -> "non-zero"
  }
}

fn build_step(
  label: String,
  runner: fn() -> Result(CommandOutput, String),
) -> fn(types.Context, Dynamic) -> types.StepResult(Dynamic) {
  fn(_ctx: types.Context, _input: Dynamic) {
    case runner() {
      Ok(output) ->
        case output.exit_code {
          0 -> Ok(dynamic.string(string.trim(output.stdout)))
          _ ->
            Error(types.StepFailure(
              message: label
              <> " failed (exit "
              <> exit_code_to_string(output.exit_code)
              <> "):\n"
              <> output.stdout
              <> output.stderr,
            ))
        }
      Error(msg) ->
        Error(types.StepFailure(
          message: "Failed to start " <> label <> ": " <> msg,
        ))
    }
  }
}

@external(erlang, "command_runner_erlang", "run_command")
@external(javascript, "./command_runner_ffi.mjs", "run_command")
fn run_ffi(
  program: String,
  args: List(String),
) -> Result(#(Int, String, String), String)

@external(erlang, "command_runner_erlang", "run_command_in_dir")
@external(javascript, "./command_runner_ffi.mjs", "run_command_in_dir")
fn run_in_dir_ffi(
  program: String,
  args: List(String),
  cwd: String,
) -> Result(#(Int, String, String), String)
