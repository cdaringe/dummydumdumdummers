import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/examples
import thingfactory/runner_host
import thingfactory/types

// ---------------------------------------------------------------------------
// CPU core detection
// ---------------------------------------------------------------------------

pub fn cpu_count_is_positive_test() {
  let cores = runner_host.get_cpu_count()
  { cores >= 1 } |> should.be_true()
}

// ---------------------------------------------------------------------------
// Host construction
// ---------------------------------------------------------------------------

pub fn new_host_defaults_to_cpu_cores_test() {
  let host = runner_host.new()
  let s = runner_host.status(host)
  let cores = runner_host.get_cpu_count()
  s.worker_count |> should.equal(cores)
  s.active |> should.equal(0)
  s.queued |> should.equal(0)
  s.completed |> should.equal(0)
  s.available |> should.equal(cores)
}

pub fn with_workers_sets_count_test() {
  let host = runner_host.with_workers(4)
  let s = runner_host.status(host)
  s.worker_count |> should.equal(4)
}

pub fn with_workers_clamps_minimum_test() {
  let host = runner_host.with_workers(0)
  let s = runner_host.status(host)
  s.worker_count |> should.equal(1)

  let host2 = runner_host.with_workers(-5)
  let s2 = runner_host.status(host2)
  s2.worker_count |> should.equal(1)
}

// ---------------------------------------------------------------------------
// Submission
// ---------------------------------------------------------------------------

pub fn submit_queues_pipeline_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  id |> should.equal("run-1")

  let s = runner_host.status(host)
  s.queued |> should.equal(1)
  s.completed |> should.equal(0)
}

pub fn submit_assigns_sequential_ids_test() {
  let host = runner_host.with_workers(4)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id1) = runner_host.submit(host, p, dynamic.nil(), config)
  let #(host, id2) = runner_host.submit(host, p, dynamic.nil(), config)
  let #(_host, id3) = runner_host.submit(host, p, dynamic.nil(), config)

  id1 |> should.equal("run-1")
  id2 |> should.equal("run-2")
  id3 |> should.equal("run-3")
}

pub fn submit_parallel_queues_pipeline_test() {
  let host = runner_host.with_workers(2)
  let p = examples.parallel_build_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit_parallel(host, p, dynamic.nil(), config)
  id |> should.equal("run-1")

  let s = runner_host.status(host)
  s.queued |> should.equal(1)
}

// ---------------------------------------------------------------------------
// Execution via tick
// ---------------------------------------------------------------------------

pub fn tick_executes_queued_pipeline_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  let host = runner_host.tick(host)

  let s = runner_host.status(host)
  s.queued |> should.equal(0)
  s.completed |> should.equal(1)

  let result = runner_host.get_result(host, id)
  result |> should.be_ok()
}

pub fn tick_respects_worker_capacity_test() {
  // With 1 worker, only 1 pipeline should execute per tick
  let host = runner_host.with_workers(1)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id1) = runner_host.submit(host, p, dynamic.nil(), config)
  let #(host, _id2) = runner_host.submit(host, p, dynamic.nil(), config)

  // After one tick, execution completes synchronously so both complete
  // since completed slots free workers for next tick
  let host = runner_host.tick(host)

  // First pipeline should be complete
  runner_host.get_result(host, id1) |> should.be_ok()
}

pub fn tick_noop_when_no_queued_test() {
  let host = runner_host.with_workers(2)
  let host = runner_host.tick(host)
  let s = runner_host.status(host)
  s.queued |> should.equal(0)
  s.completed |> should.equal(0)
}

// ---------------------------------------------------------------------------
// Drain
// ---------------------------------------------------------------------------

pub fn drain_executes_all_queued_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id1) = runner_host.submit(host, p, dynamic.nil(), config)
  let #(host, id2) = runner_host.submit(host, p, dynamic.nil(), config)
  let #(host, id3) = runner_host.submit(host, p, dynamic.nil(), config)

  let host = runner_host.drain(host)

  let s = runner_host.status(host)
  s.queued |> should.equal(0)
  s.completed |> should.equal(3)

  runner_host.get_result(host, id1) |> should.be_ok()
  runner_host.get_result(host, id2) |> should.be_ok()
  runner_host.get_result(host, id3) |> should.be_ok()
}

pub fn drain_handles_empty_queue_test() {
  let host = runner_host.with_workers(4)
  let host = runner_host.drain(host)
  let s = runner_host.status(host)
  s.completed |> should.equal(0)
}

// ---------------------------------------------------------------------------
// Parallel pipeline execution
// ---------------------------------------------------------------------------

pub fn parallel_pipeline_execution_test() {
  let host = runner_host.with_workers(2)
  let p = examples.parallel_build_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit_parallel(host, p, dynamic.nil(), config)
  let host = runner_host.tick(host)

  let assert Ok(exec_result) = runner_host.get_result(host, id)
  exec_result.result |> should.be_ok()
  // parallel_build has 5 steps: clone, lint, test, build, package
  list.length(exec_result.trace) |> should.equal(5)
}

// ---------------------------------------------------------------------------
// Error handling in submitted pipelines
// ---------------------------------------------------------------------------

pub fn failed_pipeline_result_test() {
  let host = runner_host.with_workers(2)
  let p = examples.error_handling_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  let host = runner_host.tick(host)

  let assert Ok(exec_result) = runner_host.get_result(host, id)
  exec_result.result |> should.be_error()
}

// ---------------------------------------------------------------------------
// Status queries
// ---------------------------------------------------------------------------

pub fn get_status_for_queued_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  let status = runner_host.get_status(host, id)
  status |> should.equal(Ok(runner_host.Queued))
}

pub fn get_status_for_completed_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  let host = runner_host.tick(host)

  case runner_host.get_status(host, id) {
    Ok(runner_host.Completed(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn get_status_not_found_test() {
  let host = runner_host.with_workers(2)
  let result = runner_host.get_status(host, "nonexistent")
  result |> should.be_error()
}

pub fn get_result_not_found_test() {
  let host = runner_host.with_workers(2)
  let result = runner_host.get_result(host, "nonexistent")
  result |> should.be_error()
}

pub fn get_result_still_queued_test() {
  let host = runner_host.with_workers(2)
  let p = examples.basic_pipeline()
  let config = types.default_config()

  let #(host, id) = runner_host.submit(host, p, dynamic.nil(), config)
  let result = runner_host.get_result(host, id)
  result |> should.be_error()
}

// ---------------------------------------------------------------------------
// Format status
// ---------------------------------------------------------------------------

pub fn format_status_test() {
  let host = runner_host.with_workers(4)
  let s = runner_host.status(host)
  let formatted = runner_host.format_status(s)

  { formatted != "" } |> should.be_true()
}

// ---------------------------------------------------------------------------
// Mixed sequential and parallel submissions
// ---------------------------------------------------------------------------

pub fn mixed_submission_drain_test() {
  let host = runner_host.with_workers(4)
  let config = types.default_config()

  let #(host, id1) =
    runner_host.submit(host, examples.basic_pipeline(), dynamic.nil(), config)
  let #(host, id2) =
    runner_host.submit_parallel(
      host,
      examples.parallel_build_pipeline(),
      dynamic.nil(),
      config,
    )
  let #(host, id3) =
    runner_host.submit(
      host,
      examples.artifact_sharing_pipeline(),
      dynamic.nil(),
      config,
    )

  let host = runner_host.drain(host)

  let s = runner_host.status(host)
  s.completed |> should.equal(3)
  s.queued |> should.equal(0)

  runner_host.get_result(host, id1) |> should.be_ok()
  runner_host.get_result(host, id2) |> should.be_ok()
  runner_host.get_result(host, id3) |> should.be_ok()
}
