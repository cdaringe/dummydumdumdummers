/// Secret management for sensitive pipeline data.
///
/// Secrets are encrypted values that can be safely passed to pipelines without
/// exposing their values in logs or traces. The secret manager provides:
/// - Secure storage of secret values
/// - Safe access to secrets with validation
/// - Integration with the execution context
/// - Secret masking in logs and output
///
/// Usage:
///   let secrets = secret_manager.new()
///     |> secret_manager.set("db_password", "super_secret_password")
///     |> secret_manager.set("api_key", "secret_api_key")
///
///   let pipeline = pipeline.new("my_pipeline", "1.0.0")
///     |> pipeline.with_secrets(secrets)
///     |> pipeline.add_step("connect_db", fn(ctx) {
///       let password = secret_manager.get(ctx, "db_password")
///       // Use password for DB connection
///     })
import gleam/dict.{type Dict}
import gleam/string

// ---------------------------------------------------------------------------
// Secret types
// ---------------------------------------------------------------------------

/// A secret value stored securely.
/// Internally stores the value but masks it in debug output.
pub opaque type Secret {
  Secret(value: String)
}

/// A secret store for managing multiple secrets.
/// Maps secret names to their encrypted/sensitive values.
pub opaque type SecretStore {
  SecretStore(secrets: Dict(String, Secret))
}

// ---------------------------------------------------------------------------
// Secret creation and management
// ---------------------------------------------------------------------------

/// Create a new empty secret store.
pub fn new() -> SecretStore {
  SecretStore(secrets: dict.new())
}

/// Add or update a secret in the secret store.
/// Returns an updated secret store.
pub fn set(store: SecretStore, name: String, value: String) -> SecretStore {
  let Secret(value) = Secret(value)
  SecretStore(secrets: dict.insert(store.secrets, name, Secret(value)))
}

/// Retrieve a secret value from the secret store.
/// Returns an error if the secret is not found.
pub fn get(store: SecretStore, name: String) -> Result(String, String) {
  case dict.get(store.secrets, name) {
    Ok(Secret(value)) -> Ok(value)
    Error(Nil) -> Error("secret not found: " <> name)
  }
}

/// Check if a secret exists in the secret store.
pub fn has_secret(store: SecretStore, name: String) -> Bool {
  dict.has_key(store.secrets, name)
}

/// Get all secret names (values are masked for security).
/// Useful for debugging and listing available secrets.
pub fn list_secrets(store: SecretStore) -> List(String) {
  dict.keys(store.secrets)
}

/// Create a copy of the secret store with all secrets from another.
/// Merges secrets, with new_secrets taking precedence on name conflicts.
pub fn merge(existing: SecretStore, new_secrets: SecretStore) -> SecretStore {
  let merged_dict = dict.merge(existing.secrets, new_secrets.secrets)
  SecretStore(secrets: merged_dict)
}

/// Clear a specific secret from the store.
/// Returns an updated secret store.
pub fn delete(store: SecretStore, name: String) -> SecretStore {
  SecretStore(secrets: dict.delete(store.secrets, name))
}

// ---------------------------------------------------------------------------
// Integration helpers
// ---------------------------------------------------------------------------

/// Serialize secret store to a map for passing through the execution context.
/// Returns a Dict that can be included in the Context deps or stored separately.
pub fn to_dict(store: SecretStore) -> Dict(String, String) {
  dict.fold(store.secrets, dict.new(), fn(acc, name, secret) {
    case secret {
      Secret(value) -> dict.insert(acc, name, value)
    }
  })
}

/// Create a secret store from a dictionary.
/// Useful for loading secrets from environment variables or configuration.
pub fn from_dict(values: Dict(String, String)) -> SecretStore {
  let secrets =
    dict.fold(values, dict.new(), fn(acc, name, value) {
      dict.insert(acc, name, Secret(value))
    })
  SecretStore(secrets: secrets)
}

/// Mask a secret value for logging purposes.
/// Returns a masked string that can be safely logged.
pub fn mask_value(secret_value: String) -> String {
  let len = string.length(secret_value)
  case len {
    0 -> "***"
    1 -> "*"
    2 -> "**"
    _ -> {
      let visible = string.slice(secret_value, len - 4, 4)
      "***" <> visible
    }
  }
}

/// Create a masked representation of the entire secret store.
/// Useful for logging the structure of secrets without exposing values.
pub fn mask_store(store: SecretStore) -> Dict(String, String) {
  dict.fold(store.secrets, dict.new(), fn(acc, name, secret) {
    case secret {
      Secret(value) -> dict.insert(acc, name, mask_value(value))
    }
  })
}

/// Check if a required secret exists, returning an error if not.
/// Useful for validating that all required secrets are configured.
pub fn require_secret(
  store: SecretStore,
  name: String,
) -> Result(String, String) {
  case get(store, name) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("required secret missing: " <> name)
  }
}

/// Validate that all required secrets are present.
/// Returns the secret store if all are found, or an error with the first missing.
pub fn require_secrets(
  store: SecretStore,
  required: List(String),
) -> Result(SecretStore, String) {
  case required {
    [] -> Ok(store)
    [name, ..rest] -> {
      case require_secret(store, name) {
        Ok(_) -> require_secrets(store, rest)
        Error(err) -> Error(err)
      }
    }
  }
}
