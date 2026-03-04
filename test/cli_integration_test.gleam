/// Integration tests for the CLI (Scenario 49).
///
/// These tests cover all major CLI features:
///   - Isolation mode resolution (docker / local / invalid)
///   - All five CLI commands as subprocess invocations (list, run, results,
///     artifacts, inspect-via-run)
///   - Compact and verbose output modes
///   - File-based pipeline loading
///   - Docker isolation path invocation
///
/// The subprocess tests run `gleam run -m thingfactory/cli` which re-uses the
/// already-compiled BEAM artefacts from the same test build, so no recompile
/// occurs for each invocation.
import gleam/list
import gleam/string
import gleeunit/should
import thingfactory/cli
import thingfactory/command_runner

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn run_cli(args: List(String)) -> Result(command_runner.CommandOutput, String) {
  command_runner.run(
    "gleam",
    list.append(["run", "-m", "thingfactory/cli", "--"], args),
  )
}

// ---------------------------------------------------------------------------
// Isolation mode resolution
// ---------------------------------------------------------------------------

pub fn isolation_defaults_to_docker_test() {
  let assert Ok(mode) =
    cli.resolve_isolation_mode(Error(Nil), Error(Nil), False)
  mode
  |> should.equal(cli.DockerIsolation("ghcr.io/gleam-lang/gleam:v1.13.0-erlang"))
}

pub fn isolation_explicit_local_test() {
  let assert Ok(mode) =
    cli.resolve_isolation_mode(Ok("local"), Error(Nil), False)
  mode |> should.equal(cli.LocalIsolation)
}

pub fn isolation_docker_with_custom_image_test() {
  let assert Ok(mode) =
    cli.resolve_isolation_mode(Ok("docker"), Ok("alpine:3"), False)
  mode |> should.equal(cli.DockerIsolation("alpine:3"))
}

pub fn isolation_interactive_forces_local_test() {
  // Interactive mode must use LocalIsolation to keep stdin/stdout accessible.
  let assert Ok(mode) =
    cli.resolve_isolation_mode(Ok("docker"), Error(Nil), True)
  mode |> should.equal(cli.LocalIsolation)
}

pub fn isolation_invalid_isolator_returns_error_test() {
  let err =
    should.be_error(cli.resolve_isolation_mode(Ok("k8s"), Error(Nil), False))
  should.be_true(string.contains(err, "Invalid isolator"))
}

// ---------------------------------------------------------------------------
// Subprocess integration tests – all major CLI commands
// ---------------------------------------------------------------------------

/// `list` command: CLI binary runs and prints usage information.
pub fn subprocess_list_command_test() {
  let assert Ok(out) = run_cli(["list"])
  should.be_true(string.length(out.stdout) > 0)
  should.be_true(string.contains(out.stdout, "thingfactory run"))
}

/// `run` command (verbose, local): executes basic pipeline and prints result.
pub fn subprocess_run_local_verbose_test() {
  let assert Ok(out) =
    run_cli([
      "run", "--isolator", "local", "thingfactory@examples:basic_pipeline",
    ])
  should.be_true(string.contains(out.stdout, "Result:"))
}

/// `run` command (compact, local): summary line contains "steps".
pub fn subprocess_run_local_compact_test() {
  let assert Ok(out) =
    run_cli([
      "run", "-c", "--isolator", "local", "thingfactory@examples:basic_pipeline",
    ])
  should.be_true(string.contains(out.stdout, "steps"))
}

/// `run` command with `-f` flag: loads pipeline from source file.
pub fn subprocess_run_from_file_test() {
  let assert Ok(out) =
    run_cli([
      "run", "--isolator", "local", "-f", "src/thingfactory/examples.gleam",
      "basic_pipeline",
    ])
  should.be_true(string.contains(out.stdout, "Result:"))
}

/// `results` command: structured report with "Pipeline Results" header.
/// Note: `results` has no --isolator flag; it always runs locally.
pub fn subprocess_results_command_test() {
  let assert Ok(out) =
    run_cli(["results", "thingfactory@examples:basic_pipeline"])
  should.be_true(string.contains(out.stdout, "Pipeline Results"))
  should.be_true(string.contains(out.stdout, "SUCCESS"))
}

/// `artifacts` command: runs pipeline and mentions artifacts (or absence thereof).
/// Note: `artifacts` has no --isolator flag; it always runs locally.
pub fn subprocess_artifacts_command_test() {
  let assert Ok(out) =
    run_cli([
      "artifacts", "-o", "/tmp/thingfactory_integration_artifacts",
      "thingfactory@examples:basic_pipeline",
    ])
  // Either "No artifacts" or "artifact" appears when extraction is attempted.
  should.be_true(
    string.contains(out.stdout, "artifact")
    || string.contains(out.stdout, "No artifact"),
  )
}

/// Invalid pipeline reference: CLI emits an error message (not a crash).
pub fn subprocess_invalid_ref_emits_error_test() {
  let assert Ok(out) = run_cli(["run", "--isolator", "local", "not_valid"])
  should.be_true(string.contains(out.stdout, "Error"))
}

// ---------------------------------------------------------------------------
// Docker isolation path integration test
// ---------------------------------------------------------------------------

/// Docker isolation path is invoked when `--isolator docker` is specified.
/// Verifies that the CLI correctly routes to the docker execution branch:
/// the output must not contain a CLI parse error or logic error regardless
/// of whether a Docker daemon is reachable at test time.
pub fn subprocess_docker_isolation_invoked_test() {
  let assert Ok(out) =
    run_cli([
      "run", "--isolator", "docker", "--docker-image",
      "ghcr.io/gleam-lang/gleam:v1.13.0-erlang",
      "thingfactory@examples:basic_pipeline",
    ])
  // Absence of these strings confirms the CLI reached the docker execution
  // path rather than failing at argument parsing or isolation resolution.
  should.be_false(string.contains(out.stdout, "Invalid pipeline reference"))
  should.be_false(string.contains(out.stdout, "Invalid isolator"))
}

/// Docker isolation end-to-end: when Docker is reachable, actually execute
/// a pipeline inside a container and assert the pipeline completes successfully.
/// When Docker is NOT available the test passes immediately (graceful skip).
pub fn subprocess_docker_isolation_executes_pipeline_test() {
  let docker_available = case command_runner.run("docker", ["info"]) {
    Ok(result) -> result.exit_code == 0
    Error(_) -> False
  }
  case docker_available {
    False -> {
      // Docker daemon not reachable – skip gracefully.
      True |> should.be_true
    }
    True -> {
      // Docker is running – verify real end-to-end container execution.
      let assert Ok(out) =
        run_cli([
          "run", "--isolator", "docker", "--docker-image",
          "ghcr.io/gleam-lang/gleam:v1.13.0-erlang",
          "thingfactory@examples:basic_pipeline",
        ])
      should.be_true(string.contains(out.stdout, "Result:"))
    }
  }
}
