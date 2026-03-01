/// Work queue for PULL-based pipeline patterns.
///
/// Provides a queue abstraction built on the message bus, enabling
/// workers to pull tasks from a shared queue. This complements the
/// default PUSH model (step output → next step input) with a PULL
/// model where workers retrieve work items from named queues.
///
/// ## Push vs Pull
///
/// - **PUSH**: `add_step("a", fn(_, _) { Ok(data) })` → data flows automatically
/// - **PULL**: Producer calls `enqueue(ctx, "tasks", item)`,
///             worker calls `pull_all(ctx, "tasks")` to retrieve items
import gleam/dynamic.{type Dynamic}
import gleam/list
import thingfactory/types.{type Context}

/// Queue topic prefix to separate queue messages from regular pub-sub topics.
const queue_prefix = "queue:"

/// Enqueue a work item to a named queue.
/// Returns an updated Context with the work item added.
pub fn enqueue(ctx: Context, queue_name: String, item: Dynamic) -> Context {
  types.publish_message(ctx, queue_prefix <> queue_name, item)
}

/// Pull all pending work items from a named queue.
/// Returns the payloads of all enqueued items.
pub fn pull_all(ctx: Context, queue_name: String) -> List(Dynamic) {
  types.get_messages(ctx, queue_prefix <> queue_name)
  |> list.map(fn(msg) { msg.payload })
}

/// Check if a queue has pending work items.
pub fn has_work(ctx: Context, queue_name: String) -> Bool {
  case types.get_messages(ctx, queue_prefix <> queue_name) {
    [] -> False
    _ -> True
  }
}

/// Get the number of items in a queue.
pub fn queue_size(ctx: Context, queue_name: String) -> Int {
  list.length(types.get_messages(ctx, queue_prefix <> queue_name))
}
