/// Tests for the work queue module
import gleam/dict
import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/message_store
import thingfactory/secret_manager
import thingfactory/types
import thingfactory/work_queue

fn empty_context() -> types.Context {
  types.Context(
    artifact_store: dict.new(),
    message_store: message_store.new(),
    deps: dict.new(),
    secret_store: secret_manager.new(),
  )
}

pub fn enqueue_and_pull_test() {
  let ctx = empty_context()
  let ctx = work_queue.enqueue(ctx, "tasks", dynamic.string("task_1"))
  let ctx = work_queue.enqueue(ctx, "tasks", dynamic.string("task_2"))

  let items = work_queue.pull_all(ctx, "tasks")
  list.length(items) |> should.equal(2)
}

pub fn has_work_empty_test() {
  let ctx = empty_context()
  work_queue.has_work(ctx, "tasks") |> should.equal(False)
}

pub fn has_work_with_items_test() {
  let ctx = empty_context()
  let ctx = work_queue.enqueue(ctx, "tasks", dynamic.string("task_1"))
  work_queue.has_work(ctx, "tasks") |> should.equal(True)
}

pub fn queue_size_test() {
  let ctx = empty_context()
  work_queue.queue_size(ctx, "tasks") |> should.equal(0)
  let ctx = work_queue.enqueue(ctx, "tasks", dynamic.string("task_1"))
  work_queue.queue_size(ctx, "tasks") |> should.equal(1)
  let ctx = work_queue.enqueue(ctx, "tasks", dynamic.string("task_2"))
  work_queue.queue_size(ctx, "tasks") |> should.equal(2)
}

pub fn separate_queues_test() {
  let ctx = empty_context()
  let ctx = work_queue.enqueue(ctx, "build", dynamic.string("build_task"))
  let ctx = work_queue.enqueue(ctx, "deploy", dynamic.string("deploy_task"))

  work_queue.queue_size(ctx, "build") |> should.equal(1)
  work_queue.queue_size(ctx, "deploy") |> should.equal(1)
  work_queue.queue_size(ctx, "other") |> should.equal(0)
}

pub fn pull_empty_queue_test() {
  let ctx = empty_context()
  let items = work_queue.pull_all(ctx, "nonexistent")
  list.length(items) |> should.equal(0)
}
