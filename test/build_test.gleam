/// Structure test for the canonical self-build pipeline (scenario 60).
/// Verifies the full DAG shape — real command_runner steps, correct
/// dependency edges, trigger, and timeout — without executing the pipeline.
///
/// Tests use BuildStep enum values directly (not strings) to validate deps,
/// demonstrating scenario 28: no stringly-typed step references.
import gleam/list
import gleeunit/should
import thingfactory/build.{
  type BuildStep, CliShipment, DockerBuildCli, DockerBuildWeb, GleamBuildErl,
  GleamBuildJs, GleamCheck, GleamFormat, GleamTest, HexPublish, SemanticRelease,
  WebBuild, WebInstall, WebLint,
}
import thingfactory/pipeline
import thingfactory/types
import thingfactory/webhook_trigger

pub fn build_pipeline_id_test() {
  let p = build.build()
  pipeline.id(p)
  |> should.equal(types.PipelineId("thingfactory-build", "1.0.0"))
}

pub fn build_pipeline_step_count_test() {
  // 13 steps: gleam_check, gleam_format, web_install,
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
  deps_for(steps, GleamCheck) |> should.equal([])
  deps_for(steps, GleamFormat) |> should.equal([])
  deps_for(steps, WebInstall) |> should.equal([])
}

pub fn build_pipeline_tier1_test_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, GleamTest)
  |> should.equal([GleamCheck, GleamFormat])
  deps_for(steps, WebLint)
  |> should.equal([WebInstall])
}

pub fn build_pipeline_tier2_build_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, GleamBuildErl) |> should.equal([GleamTest])
  deps_for(steps, GleamBuildJs) |> should.equal([GleamTest])
  deps_for(steps, WebBuild) |> should.equal([WebLint])
}

pub fn build_pipeline_tier3_package_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, CliShipment) |> should.equal([GleamBuildErl])
  deps_for(steps, DockerBuildCli) |> should.equal([CliShipment])
  deps_for(steps, DockerBuildWeb) |> should.equal([WebBuild])
}

pub fn build_pipeline_tier4_publish_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, HexPublish)
  |> should.equal([GleamBuildErl, GleamBuildJs])
}

pub fn build_pipeline_tier5_release_deps_test() {
  let steps = pipeline.steps(build.build())
  deps_for(steps, SemanticRelease)
  |> should.equal([DockerBuildCli, DockerBuildWeb, HexPublish])
}

fn deps_for(
  steps: List(pipeline.Step(BuildStep)),
  target: BuildStep,
) -> List(BuildStep) {
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
