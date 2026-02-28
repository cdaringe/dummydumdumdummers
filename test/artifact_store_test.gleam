import gleam/dynamic
import gleam/list
import gleeunit/should
import thingfactory/artifact_store
import thingfactory/types

// FR-4: Artifact write/read works
pub fn write_and_read_test() {
  let store = artifact_store.new()
  let value = dynamic.string("test_value")
  let store = artifact_store.write(store, "key1", value)

  let result = artifact_store.read(store, "key1")
  result |> should.be_ok()
  result |> should.equal(Ok(value))
}

// FR-4: Reading missing key returns ArtifactNotFound
pub fn read_missing_key_test() {
  let store = artifact_store.new()
  let result = artifact_store.read(store, "missing")

  result |> should.be_error()
  case result {
    Ok(_) -> panic as "expected error"
    Error(types.ArtifactNotFound(key: "missing")) -> Nil
    Error(_) -> panic as "wrong error type"
  }
}

// QR-3: Isolation between runs
pub fn isolation_test() {
  let store1 = artifact_store.new()
  let store2 = artifact_store.new()

  let store1 = artifact_store.write(store1, "key", dynamic.string("value1"))
  let store2 = artifact_store.write(store2, "key", dynamic.string("value2"))

  let result1 = artifact_store.read(store1, "key")
  let result2 = artifact_store.read(store2, "key")

  result1 |> should.equal(Ok(dynamic.string("value1")))
  result2 |> should.equal(Ok(dynamic.string("value2")))
}

// FR-4: has_key works
pub fn has_key_test() {
  let store = artifact_store.new()
  let store = artifact_store.write(store, "key", dynamic.int(42))

  artifact_store.has_key(store, "key") |> should.be_true()
  artifact_store.has_key(store, "missing") |> should.be_false()
}

// FR-4: keys returns all keys
pub fn keys_test() {
  let store = artifact_store.new()
  let store = artifact_store.write(store, "a", dynamic.int(1))
  let store = artifact_store.write(store, "b", dynamic.int(2))

  let keys = artifact_store.keys(store)
  let has_a = list.contains(keys, "a")
  let has_b = list.contains(keys, "b")
  let length = list.length(keys)

  has_a |> should.be_true()
  has_b |> should.be_true()
  length |> should.equal(2)
}
