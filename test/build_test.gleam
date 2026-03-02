/// Structure test for the canonical self-build pipeline (scenario 60).
/// Verifies the full DAG shape — real command_runner steps, correct
/// dependency edges, trigger, and timeout — without executing the pipeline.
import gleam/list
import gleeunit/should
import thingfactory/build
import thingfactory/pipeline
import thingfactory/types
import thingfactory/webhook_trigger

pub fn build_pipeline_id_test() {
  let p = build.build()
  pipeline.id(p)
  |> should.equal(types.PipelineId("thingfactory-build", "1.0.0"))
}

pub fn build_pipeline_step_count_test() {
  // 14 steps: gleam_check, gleam_format, web_install,
  //           gleam_test, web_lint,
  //           gleam_build_erl, gleam_build_js, web_build,
  //           cli_shipment, docker_build_cli, docker_build_web,
  //           hex_publish, semantic_release
  let p = build.build()
  list.length(pipeline.steps(p)) |> should.equal(13)
}

pub fn build_pipeline_trigger_test() {
  let p = build.build()
  pipeline.trigger(p)
  |> should.equal(webhook_trigger.BranchUpdate("main"))
}

pub fn build_pipeline_timeout_test() {
  let p = build.build()
  pipeline.default_timeout(p) |> should.equal(600_000)
}

pub fn build_pipeline_tier0_no_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "gleam_check") |> should.equal([])
  deps_for(steps, "gleam_format") |> should.equal([])
  deps_for(steps, "web_install") |> should.equal([])
}

pub fn build_pipeline_tier1_test_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "gleam_test")
  |> should.equal([
    pipeline.StepRef("gleam_check"),
    pipeline.StepRef("gleam_format"),
  ])
  deps_for(steps, "web_lint")
  |> should.equal([pipeline.StepRef("web_install")])
}

pub fn build_pipeline_tier2_build_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "gleam_build_erl")
  |> should.equal([pipeline.StepRef("gleam_test")])
  deps_for(steps, "gleam_build_js")
  |> should.equal([pipeline.StepRef("gleam_test")])
  deps_for(steps, "web_build")
  |> should.equal([pipeline.StepRef("web_lint")])
}

pub fn build_pipeline_tier3_package_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "cli_shipment")
  |> should.equal([pipeline.StepRef("gleam_build_erl")])
  deps_for(steps, "docker_build_cli")
  |> should.equal([pipeline.StepRef("cli_shipment")])
  deps_for(steps, "docker_build_web")
  |> should.equal([pipeline.StepRef("web_build")])
}

pub fn build_pipeline_tier4_publish_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "hex_publish")
  |> should.equal([
    pipeline.StepRef("gleam_build_erl"),
    pipeline.StepRef("gleam_build_js"),
  ])
}

pub fn build_pipeline_tier5_release_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, "semantic_release")
  |> should.equal([
    pipeline.StepRef("docker_build_cli"),
    pipeline.StepRef("docker_build_web"),
    pipeline.StepRef("hex_publish"),
  ])
}

fn deps_for(
  steps: List(pipeline.Step),
  target: String,
) -> List(pipeline.StepRef) {
  case
    list.find(steps, fn(step) {
      let pipeline.Step(name, _, _, _, _) = step
      name == target
    })
  {
    Ok(found) -> {
      let pipeline.Step(_, _, _, depends_on, _) = found
      depends_on
    }
    Error(Nil) -> []
  }
}
