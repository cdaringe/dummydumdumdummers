/// Tests for message_store module
import gleam/dynamic
import gleam/list
import gleeunit
import gleeunit/should
import thingfactory/message_store

// ---------------------------------------------------------------------------
// Message Store Tests
// ---------------------------------------------------------------------------

pub fn message_store_publish_single_message_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))

  let messages = message_store.get_messages(store, "topic1")
  list.length(messages) |> should.equal(1)
}

pub fn message_store_publish_multiple_messages_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic1", dynamic.string("msg2"))
  let store = message_store.publish(store, "topic1", dynamic.string("msg3"))

  let messages = message_store.get_messages(store, "topic1")
  list.length(messages) |> should.equal(3)
}

pub fn message_store_multiple_topics_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic2", dynamic.string("msg2"))
  let store = message_store.publish(store, "topic3", dynamic.string("msg3"))

  list.length(message_store.get_messages(store, "topic1"))
  |> should.equal(1)
  list.length(message_store.get_messages(store, "topic2"))
  |> should.equal(1)
  list.length(message_store.get_messages(store, "topic3"))
  |> should.equal(1)
}

pub fn message_store_empty_topic_test() {
  let store = message_store.new()
  let messages = message_store.get_messages(store, "nonexistent")
  list.length(messages) |> should.equal(0)
}

pub fn message_store_clear_topic_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic1", dynamic.string("msg2"))
  let store = message_store.clear_topic(store, "topic1")

  let messages = message_store.get_messages(store, "topic1")
  list.length(messages) |> should.equal(0)
}

pub fn message_store_clear_preserves_other_topics_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic2", dynamic.string("msg2"))
  let store = message_store.clear_topic(store, "topic1")

  list.length(message_store.get_messages(store, "topic1"))
  |> should.equal(0)
  list.length(message_store.get_messages(store, "topic2"))
  |> should.equal(1)
}

pub fn message_store_topics_list_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic2", dynamic.string("msg2"))

  let topics = message_store.topics(store)
  list.length(topics) |> should.equal(2)
}

pub fn message_store_has_messages_test() {
  let store = message_store.new()
  message_store.has_messages(store, "topic1")
  |> should.be_false()

  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  message_store.has_messages(store, "topic1")
  |> should.be_true()
}

pub fn message_store_has_messages_multiple_test() {
  let store = message_store.new()
  let store = message_store.publish(store, "topic1", dynamic.string("msg1"))
  let store = message_store.publish(store, "topic1", dynamic.string("msg2"))

  message_store.has_messages(store, "topic1")
  |> should.be_true()
  list.length(message_store.get_messages(store, "topic1"))
  |> should.equal(2)
}
