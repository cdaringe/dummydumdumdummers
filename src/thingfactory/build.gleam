/// Canonical CI/CD pipeline for Thingfactory — builds, tests, packages,
/// and publishes the entire project.
///
/// Run with the Thingfactory CLI:
///
///   thingfactory run -f src/thingfactory/build.gleam build
///
/// DAG structure (parallel where possible):
///
///   ┌─ GleamCheck ─────┐
///   ├─ GleamFormat ─────┤
///   │                    ├─ GleamTest ─┬─ GleamBuildErl ─┬─ CliShipment ─┬─ DockerBuildCli ─┐
///   │                    │              └─ GleamBuildJs ──┤                │                   │
///   │                    │                                │                │                   │
///   └─ WebInstall ───────┴─ WebLint ── WebBuild ──────────┴─ DockerBuildWeb ─┐                │
///                                                                             │                │
///                                          HexPublish (erl+js) ──────────────┤                │
///                                                                             │                │
///                                                              SemanticRelease ───────────────┘
///
/// Fulfills scenario 60: "The project SHALL host a pipeline file in the root
/// such that a deployed instance of the project can build itself."
///
/// Fulfills scenario 28: "The pipeline tasks SHALL NOT be stringly typed."
/// All step references use the BuildStep enum — the Gleam compiler catches
/// unknown or misspelled step names at build time.
import gleam/dynamic.{type Dynamic}
import thingfactory/command_runner
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/types
import thingfactory/webhook_trigger

// ---------------------------------------------------------------------------
// Typed step identifiers — eliminates string-based step references
// ---------------------------------------------------------------------------

/// All steps in the self-build pipeline.
/// Using enum variants as step IDs provides compile-time safety:
/// misspelled or removed step names cause a type error, not a runtime failure.
pub type BuildStep {
  GleamCheck
  GleamFormat
  WebInstall
  GleamTest
  WebLint
  GleamBuildErl
  GleamBuildJs
  WebBuild
  CliShipment
  DockerBuildCli
  DockerBuildWeb
  HexPublish
  SemanticRelease
}

pub fn build_step_to_string(step: BuildStep) -> String {
  case step {
    GleamCheck -> "gleam_check"
    GleamFormat -> "gleam_format"
    WebInstall -> "web_install"
    GleamTest -> "gleam_test"
    WebLint -> "web_lint"
    GleamBuildErl -> "gleam_build_erl"
    GleamBuildJs -> "gleam_build_js"
    WebBuild -> "web_build"
    CliShipment -> "cli_shipment"
    DockerBuildCli -> "docker_build_cli"
    DockerBuildWeb -> "docker_build_web"
    HexPublish -> "hex_publish"
    SemanticRelease -> "semantic_release"
  }
}

// ---------------------------------------------------------------------------
// Pipeline definition
// ---------------------------------------------------------------------------

/// Full CI/CD pipeline — validate, test, build, package, and publish.
///
/// Run with:
///   thingfactory run -f src/thingfactory/build.gleam build
pub fn build() -> pipeline.Pipeline(BuildStep, Dynamic) {
  pipeline.typed("thingfactory-build", "1.0.0", build_step_to_string)
  |> pipeline.with_timeout(600_000)
  |> pipeline.with_trigger(webhook_trigger.on_branch_update("main"))
  // ── Tier 0: Validate (no deps, all parallel) ──────────────────────
  |> pipeline.add_step_with_deps(
    GleamCheck,
    command_runner.step("gleam", ["check"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    GleamFormat,
    command_runner.step("gleam", ["format", "--check"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    WebInstall,
    command_runner.step("npm", ["--prefix", "web", "ci"]),
    [],
  )
  // ── Tier 1: Test ──────────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    GleamTest,
    command_runner.step("gleam", ["test"]),
    [GleamCheck, GleamFormat],
  )
  |> pipeline.add_step_with_deps(
    WebLint,
    command_runner.step("npm", ["--prefix", "web", "run", "lint"]),
    [WebInstall],
  )
  // ── Tier 2: Build ─────────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    GleamBuildErl,
    command_runner.step("gleam", ["build", "--target", "erlang"]),
    [GleamTest],
  )
  |> pipeline.add_step_with_deps(
    GleamBuildJs,
    command_runner.step("gleam", ["build", "--target", "javascript"]),
    [GleamTest],
  )
  |> pipeline.add_step_with_deps(
    WebBuild,
    command_runner.step("npm", ["--prefix", "web", "run", "build"]),
    [WebLint],
  )
  // ── Tier 3: Package ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    CliShipment,
    command_runner.step("gleam", ["export", "erlang-shipment"]),
    [GleamBuildErl],
  )
  |> pipeline.add_step_with_deps(
    DockerBuildCli,
    command_runner.sh("docker build -t thingfactory-cli -f Dockerfile ."),
    [CliShipment],
  )
  |> pipeline.add_step_with_deps(
    DockerBuildWeb,
    command_runner.sh("docker build -t thingfactory-web -f web/Dockerfile web"),
    [WebBuild],
  )
  // ── Tier 4: Publish ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    HexPublish,
    command_runner.sh("gleam hex publish --yes"),
    [GleamBuildErl, GleamBuildJs],
  )
  // ── Tier 5: Release ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    SemanticRelease,
    command_runner.sh("npx semantic-release --no-ci"),
    [DockerBuildCli, DockerBuildWeb, HexPublish],
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
