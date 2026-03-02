/// Build pipeline for Thingfactory itself
///
/// This is the canonical root-level pipeline file for building and testing
/// the Thingfactory project. Run it with the Thingfactory CLI:
///
///   thingfactory run -f src/thingfactory/build.gleam build
///
/// The pipeline runs in parallel where possible:
///
///   gleam_check (no deps) ──────┐
///   gleam_format (no deps) ─────┼─→ gleam_build_erl (check + format)
///   web_install (no deps) ──────┼─→ web_build (web_install)
///                               └─→ verify (gleam_build_erl + web_build)
///
/// Fulfills scenario 60: "The project SHALL host a pipeline file in the root
/// such that a deployed instance of the project can build itself."
import gleam/dynamic.{type Dynamic}
import thingfactory/command_runner
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/types

/// Self-build pipeline — checks, formats, compiles, and verifies the project.
///
/// Run with:
///   thingfactory run -f src/thingfactory/build.gleam build
pub fn build() -> pipeline.Pipeline(Dynamic) {
  pipeline.new("thingfactory-build", "1.0.0")
  |> pipeline.with_timeout(300_000)
  |> pipeline.add_step_with_deps(
    "gleam_check",
    command_runner.step("gleam", ["check"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "gleam_format",
    command_runner.step("gleam", ["format", "--check"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "gleam_build_erl",
    command_runner.step("gleam", ["build", "--target", "erlang"]),
    [pipeline.step_ref("gleam_check"), pipeline.step_ref("gleam_format")],
  )
  |> pipeline.add_step_with_deps(
    "web_install",
    command_runner.step("npm", [
      "--prefix",
      "web",
      "install",
      "--prefer-offline",
    ]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "web_build",
    command_runner.step("npm", ["--prefix", "web", "run", "build"]),
    [pipeline.step_ref("web_install")],
  )
  |> pipeline.add_step_with_deps(
    "verify",
    fn(_ctx, _input) { Ok(dynamic.string("build=ok")) },
    [
      pipeline.step_ref("gleam_build_erl"),
      pipeline.step_ref("web_build"),
    ],
  )
}

/// Execute the build pipeline programmatically (e.g. from tests or scripts).
pub fn run() -> types.ExecutionResult(Dynamic) {
  parallel_executor.execute_parallel(
    build(),
    dynamic.nil(),
    types.default_config(),
  )
}
