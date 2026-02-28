/// Message bus for inter-step communication and broadcasting.
///
/// Enables pipeline tasks to publish and receive messages, supporting
/// coordination and data sharing patterns beyond artifact storage.
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list

// ---------------------------------------------------------------------------
// Message type
// ---------------------------------------------------------------------------

/// A message with a topic and payload.
/// Messages are broadcast on topics, allowing multiple steps to listen.
pub type Message {
  Message(topic: String, payload: Dynamic)
}

// ---------------------------------------------------------------------------
// Message Store (internal)
// ---------------------------------------------------------------------------

/// Internal storage for messages organized by topic.
pub type MessageStore =
  Dict(String, List(Message))

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Create a new empty message store.
pub fn new() -> MessageStore {
  dict.new()
}

/// Publish a message to a topic.
/// The message is appended to the list of messages for that topic.
pub fn publish(
  store: MessageStore,
  topic: String,
  payload: Dynamic,
) -> MessageStore {
  let message = Message(topic: topic, payload: payload)
  case dict.get(store, topic) {
    Ok(messages) -> dict.insert(store, topic, list.append(messages, [message]))
    Error(Nil) -> dict.insert(store, topic, [message])
  }
}

/// Retrieve all messages published on a given topic.
/// Returns an empty list if the topic has no messages.
pub fn get_messages(store: MessageStore, topic: String) -> List(Message) {
  case dict.get(store, topic) {
    Ok(messages) -> messages
    Error(Nil) -> []
  }
}

/// Clear all messages from a specific topic.
pub fn clear_topic(store: MessageStore, topic: String) -> MessageStore {
  dict.delete(store, topic)
}

/// Get all topics that have messages.
pub fn topics(store: MessageStore) -> List(String) {
  dict.keys(store)
}

/// Check if a topic has any messages.
pub fn has_messages(store: MessageStore, topic: String) -> Bool {
  get_messages(store, topic) != []
}
