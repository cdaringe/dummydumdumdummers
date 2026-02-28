import gleam/dict
import gleam/list
import gleam/string
import gleeunit/should
import thingfactory/pipeline
import thingfactory/secret_manager

// Create a new empty secret store
pub fn new_secret_store_test() {
  let store = secret_manager.new()
  let secrets = secret_manager.list_secrets(store)
  secrets |> should.equal([])
}

// Set and get a secret
pub fn set_and_get_secret_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("db_password", "super_secret")

  let result = secret_manager.get(store, "db_password")
  result |> should.equal(Ok("super_secret"))
}

// Get a non-existent secret returns error
pub fn get_missing_secret_test() {
  let store = secret_manager.new()
  let result = secret_manager.get(store, "missing")
  result |> should.be_error()
}

// List secrets shows all secret names
pub fn list_secrets_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("db_password", "secret1")
    |> secret_manager.set("api_key", "secret2")

  let secrets = secret_manager.list_secrets(store)
  // Check that we have 2 secrets
  list.length(secrets) |> should.equal(2)
}

// Check if secret exists
pub fn has_secret_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("db_password", "secret")

  secret_manager.has_secret(store, "db_password") |> should.be_true()
  secret_manager.has_secret(store, "missing") |> should.be_false()
}

// Merge secrets from two stores
pub fn merge_secrets_test() {
  let store1 =
    secret_manager.new()
    |> secret_manager.set("password", "pass1")

  let store2 =
    secret_manager.new()
    |> secret_manager.set("api_key", "key1")

  let merged = secret_manager.merge(store1, store2)
  secret_manager.has_secret(merged, "password") |> should.be_true()
  secret_manager.has_secret(merged, "api_key") |> should.be_true()
}

// Delete a secret
pub fn delete_secret_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("db_password", "secret")
    |> secret_manager.delete("db_password")

  secret_manager.has_secret(store, "db_password") |> should.be_false()
}

// Convert to dict
pub fn to_dict_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("password", "pass1")
    |> secret_manager.set("api_key", "key1")

  let d = secret_manager.to_dict(store)
  dict.size(d) |> should.equal(2)
}

// Convert from dict
pub fn from_dict_test() {
  let d = dict.new() |> dict.insert("password", "pass1")
  let store = secret_manager.from_dict(d)

  let result = secret_manager.get(store, "password")
  result |> should.equal(Ok("pass1"))
}

// Mask value hides most of the secret
pub fn mask_value_test() {
  let masked = secret_manager.mask_value("super_secret_password")
  // The masked value should start with ***
  masked |> string.starts_with("***") |> should.be_true()
}

// Require secret returns secret value when it exists
pub fn require_secret_exists_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("db_password", "secret")

  let result = secret_manager.require_secret(store, "db_password")
  result |> should.equal(Ok("secret"))
}

// Require secret returns error when missing
pub fn require_secret_missing_test() {
  let store = secret_manager.new()
  let result = secret_manager.require_secret(store, "missing")
  result |> should.be_error()
}

// Require all secrets passes when all present
pub fn require_secrets_all_present_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("password", "pass")
    |> secret_manager.set("api_key", "key")

  let result = secret_manager.require_secrets(store, ["password", "api_key"])
  result |> should.equal(Ok(store))
}

// Require all secrets fails when any missing
pub fn require_secrets_missing_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("password", "pass")

  let result = secret_manager.require_secrets(store, ["password", "api_key"])
  result |> should.be_error()
}

// Pipeline with secrets integration
pub fn pipeline_with_secrets_test() {
  let pipeline_obj =
    pipeline.new("test", "1.0.0")
    |> pipeline.add_secret("db_password", "secret")

  let secrets = pipeline.secrets(pipeline_obj)
  let result = secret_manager.get(secrets, "db_password")
  result |> should.equal(Ok("secret"))
}

// Pipeline with_secrets builder
pub fn pipeline_with_secrets_builder_test() {
  let store =
    secret_manager.new()
    |> secret_manager.set("api_key", "key123")

  let pipeline_obj =
    pipeline.new("test", "1.0.0")
    |> pipeline.with_secrets(store)

  let secrets = pipeline.secrets(pipeline_obj)
  let result = secret_manager.get(secrets, "api_key")
  result |> should.equal(Ok("key123"))
}
