/// Tests for example pipelines
import gleam/list
import gleeunit/should
import thingfactory/examples
import thingfactory/pipeline
import thingfactory/types

pub fn basic_example_test() {
  let result = examples.run_basic_example()
  result.result |> should.be_ok()
}

pub fn error_example_test() {
  let result = examples.run_error_example()
  result.result |> should.be_error()
  // Should have 3 traces: step1 OK, step2 FAILED, step3 SKIPPED
  list.length(result.trace) |> should.equal(3)
}

pub fn dependency_injection_test() {
  let result = examples.run_with_dependencies()
  result.result |> should.be_ok()
}

pub fn mockable_pipeline_test() {
  let result = examples.run_mockable_with_mocks()
  result.result |> should.be_ok()
}

pub fn typescript_build_pipeline_test() {
  // Structure-only test: the typescript build pipeline uses real command_runner.step_in_dir()
  // calls (npm install, npm run lint, npm run build, npm run test) against examples/typescript-lib/.
  // Running these in tests would be slow (npm install). Instead we verify the pipeline is
  // correctly constructed with real commands.
  let p = examples.typescript_build_pipeline()
  pipeline.id(p) |> should.equal(types.PipelineId("typescript_build", "1.0.0"))
  list.length(pipeline.steps(p)) |> should.equal(4)
}

pub fn rust_build_pipeline_test() {
  let result = examples.run_rust_build()
  result.result |> should.be_ok()
  // Should have 5 steps
  list.length(result.trace) |> should.equal(5)
}

pub fn full_stack_pipeline_test() {
  let result = examples.run_full_stack()
  result.result |> should.be_ok()
  // Should have 5 steps
  list.length(result.trace) |> should.equal(5)
}

pub fn gleam_build_pipeline_test() {
  // Structure-only test: the gleam build pipeline uses real command_runner.step()
  // calls (gleam check, gleam test, etc.), so executing it here would recursively
  // invoke gleam test. Instead we verify the pipeline is correctly constructed.
  let p = examples.gleam_build_pipeline()
  pipeline.id(p) |> should.equal(types.PipelineId("gleam_build", "1.0.0"))
  list.length(pipeline.steps(p)) |> should.equal(6)
}

pub fn artifact_sharing_pipeline_test() {
  let result = examples.run_artifact_sharing()
  result.result |> should.be_ok()
  // Should have 4 steps
  list.length(result.trace) |> should.equal(4)
}

pub fn go_build_pipeline_test() {
  // Structure-only test: the go build pipeline uses real command_runner.step_in_dir()
  // calls (go mod download, go test, go build, go vet) against examples/go-lib/.
  // Running these requires Go to be installed; tests validate structure instead.
  let p = examples.go_build_pipeline()
  pipeline.id(p) |> should.equal(types.PipelineId("go_build", "1.0.0"))
  list.length(pipeline.steps(p)) |> should.equal(4)
}

pub fn custom_runner_pipeline_test() {
  let result = examples.run_custom_runner()
  result.result |> should.be_ok()
  // Should have 4 steps demonstrating custom command runner factory
  list.length(result.trace) |> should.equal(4)
}

pub fn parallel_build_pipeline_test() {
  let result = examples.run_parallel_build()
  result.result |> should.be_ok()
  // Should have 5 steps: clone, lint, test, build, package
  list.length(result.trace) |> should.equal(5)
}

pub fn parallel_multi_target_pipeline_test() {
  let result = examples.run_parallel_multi_target()
  result.result |> should.be_ok()
  // Should have 7 steps: setup, compile_a, compile_b, test_a, test_b, integration, deploy
  list.length(result.trace) |> should.equal(7)
}

pub fn distributed_parallel_pipeline_structure_test() {
  // Structure-only: this example runs Kubernetes jobs, so we validate DAG shape.
  let p = examples.distributed_parallel_pipeline()
  pipeline.id(p)
  |> should.equal(types.PipelineId("distributed_parallel", "1.0.0"))

  let steps = pipeline.steps(p)
  list.length(steps) |> should.equal(4)
  deps_for_step(steps, "seed") |> should.equal([])
  deps_for_step(steps, "async_left")
  |> should.equal(["seed"])
  deps_for_step(steps, "async_right")
  |> should.equal(["seed"])
  deps_for_step(steps, "merge")
  |> should.equal([
    "async_left",
    "async_right",
  ])
}

pub fn distributed_accumulation_pipeline_structure_test() {
  // Structure-only: this example runs Kubernetes jobs, so we validate
  // sequential accumulation flow (no explicit dependencies).
  let p = examples.distributed_accumulation_pipeline()
  pipeline.id(p)
  |> should.equal(types.PipelineId("distributed_accumulation", "1.0.0"))

  let steps = pipeline.steps(p)
  list.length(steps) |> should.equal(4)
  list.all(steps, fn(step) {
    let pipeline.Step(_, _, _, depends_on, _) = step
    depends_on == []
  })
  |> should.be_true()
}

pub fn retry_example_test() {
  let result = examples.run_retry_example()
  result.result |> should.be_ok()
  // Should have setup + retry loop iterations
  list.length(result.trace) |> should.equal(2)
}

pub fn repeat_example_test() {
  let result = examples.run_repeat_example()
  result.result |> should.be_ok()
  // Should have initialize + 3 gather_data iterations
  list.length(result.trace) |> should.equal(4)
}

pub fn until_success_example_test() {
  let result = examples.run_until_success_example()
  result.result |> should.be_ok()
  // Should have start + until_success iteration
  list.length(result.trace) |> should.equal(2)
}

pub fn simple_messaging_example_test() {
  let result = examples.run_simple_messaging()
  result.result |> should.be_ok()
  // Should have publisher and subscriber steps
  list.length(result.trace) |> should.equal(2)
}

pub fn multi_topic_messaging_example_test() {
  let result = examples.run_multi_topic_messaging()
  result.result |> should.be_ok()
  // Should have task_a, task_b, and coordinator steps
  list.length(result.trace) |> should.equal(3)
}

pub fn event_driven_example_test() {
  let result = examples.run_event_driven()
  result.result |> should.be_ok()
  // Should have event_producer, event_handler_1, event_handler_2 steps
  list.length(result.trace) |> should.equal(3)
}

pub fn daily_health_check_example_test() {
  let result = examples.run_daily_health_check()
  result.result |> should.be_ok()
  // Should have 3 steps: check_api, check_database, check_cache
  list.length(result.trace) |> should.equal(3)
}

pub fn weekly_backup_example_test() {
  let result = examples.run_weekly_backup()
  result.result |> should.be_ok()
  // Should have 3 steps: prepare_snapshot, upload_to_storage, verify_backup
  list.length(result.trace) |> should.equal(3)
}

pub fn monthly_reporting_example_test() {
  let result = examples.run_monthly_reporting()
  result.result |> should.be_ok()
  // Should have 3 steps: collect_metrics, generate_report, send_to_stakeholders
  list.length(result.trace) |> should.equal(3)
}

pub fn frequent_health_check_example_test() {
  let result = examples.run_frequent_health_check()
  result.result |> should.be_ok()
  // Should have 2 steps: ping_service, record_metrics
  list.length(result.trace) |> should.equal(2)
}

pub fn cron_cleanup_example_test() {
  let result = examples.run_cron_cleanup()
  result.result |> should.be_ok()
  // Should have 3 steps: cleanup_temp_files, vacuum_database, archive_logs
  list.length(result.trace) |> should.equal(3)
}

pub fn queue_worker_example_test() {
  let result = examples.run_queue_worker()
  result.result |> should.be_ok()
  // Should have 3 steps: produce_work, worker, summarize
  list.length(result.trace) |> should.equal(3)
}

pub fn library_import_pipeline_test() {
  // Verify that steps imported from a library module compose correctly with
  // locally-defined steps in the same pipeline.
  let p = examples.library_import_pipeline()
  pipeline.id(p) |> should.equal(types.PipelineId("library_import", "1.0.0"))
  list.length(pipeline.steps(p)) |> should.equal(5)

  let result = examples.run_library_import()
  result.result |> should.be_ok()
  // 5 traces: seed, validate, local_enrich, uppercase, prefix
  list.length(result.trace) |> should.equal(5)
}

pub fn dogfood_pipeline_test() {
  // Structure-only test: the dogfood pipeline uses real command_runner.step()
  // calls (gleam check, gleam build, npm install/build), so executing it here
  // would be slow and environment-dependent. Instead we verify the pipeline
  // is correctly constructed with the right shape and dependencies.
  let p = examples.dogfood_pipeline()
  pipeline.id(p) |> should.equal(types.PipelineId("dogfood", "1.0.0"))
  // 7 steps: gleam_check, gleam_format, gleam_build_js, gleam_build_erl,
  //          web_install, web_build, verify
  list.length(pipeline.steps(p)) |> should.equal(7)
}

fn deps_for_step(
  steps: List(pipeline.Step(String)),
  target: String,
) -> List(String) {
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
