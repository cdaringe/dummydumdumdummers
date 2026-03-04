/// Canonical CI/CD pipeline for Thingfactory — builds, tests, packages,
/// and publishes the entire project.
///
/// Run with the Thingfactory CLI:
///
///   thingfactory run -f src/thingfactory/build.gleam build
///
/// DAG structure (parallel where possible):
///
///   ┌─ gleam_check ─────┐
///   ├─ gleam_format ─────┤
///   │                    ├─ gleam_test ─┬─ gleam_build_erl ─┬─ cli_shipment ─┬─ docker_build_cli ─┐
///   │                    │              └─ gleam_build_js ──┤                │                    │
///   │                    │                                  │                │                    │
///   └─ web_install ──────┴─ web_lint ── web_build ──────────┴─ docker_build_web ─┐               │
///                                                                               │               │
///                                          hex_publish (erl+js) ────────────────┤               │
///                                                                               │               │
///                                                                   semantic_release ───────────┘
///
/// Fulfills scenario 60: "The project SHALL host a pipeline file in the root
/// such that a deployed instance of the project can build itself."
import gleam/dynamic.{type Dynamic}
import thingfactory/command_runner
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/types
import thingfactory/webhook_trigger

/// Full CI/CD pipeline — validate, test, build, package, and publish.
///
/// Run with:
///   thingfactory run -f src/thingfactory/build.gleam build
pub fn build() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("thingfactory-build", "1.0.0")
  |> pipeline.with_timeout(600_000)
  |> pipeline.with_trigger(webhook_trigger.on_branch_update("main"))
  // ── Tier 0: Validate (no deps, all parallel) ──────────────────────
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
    "web_install",
    command_runner.step("npm", ["--prefix", "web", "ci"]),
    [],
  )
  // ── Tier 1: Test ──────────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    "gleam_test",
    command_runner.step("gleam", ["test"]),
    ["gleam_check", "gleam_format"],
  )
  |> pipeline.add_step_with_deps(
    "web_lint",
    command_runner.step("npm", ["--prefix", "web", "run", "lint"]),
    ["web_install"],
  )
  // ── Tier 2: Build ─────────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    "gleam_build_erl",
    command_runner.step("gleam", ["build", "--target", "erlang"]),
    ["gleam_test"],
  )
  |> pipeline.add_step_with_deps(
    "gleam_build_js",
    command_runner.step("gleam", ["build", "--target", "javascript"]),
    ["gleam_test"],
  )
  |> pipeline.add_step_with_deps(
    "web_build",
    command_runner.step("npm", ["--prefix", "web", "run", "build"]),
    ["web_lint"],
  )
  // ── Tier 3: Package ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    "cli_shipment",
    command_runner.step("gleam", ["export", "erlang-shipment"]),
    ["gleam_build_erl"],
  )
  |> pipeline.add_step_with_deps(
    "docker_build_cli",
    command_runner.sh("docker build -t thingfactory-cli -f Dockerfile ."),
    ["cli_shipment"],
  )
  |> pipeline.add_step_with_deps(
    "docker_build_web",
    command_runner.sh("docker build -t thingfactory-web -f web/Dockerfile web"),
    ["web_build"],
  )
  // ── Tier 4: Publish ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    "hex_publish",
    command_runner.sh("gleam hex publish --yes"),
    [
      "gleam_build_erl",
      "gleam_build_js",
    ],
  )
  // ── Tier 5: Release ───────────────────────────────────────────────
  |> pipeline.add_step_with_deps(
    "semantic_release",
    command_runner.sh("npx semantic-release --no-ci"),
    [
      "docker_build_cli",
      "docker_build_web",
      "hex_publish",
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
