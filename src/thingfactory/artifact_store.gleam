/// Artifact Store — per-run keyed store for inter-step data sharing.
///
/// Each pipeline run gets its own isolated ArtifactStore (QR-3).
/// Steps can write and read Dynamic values by string key (FR-4).
/// Reading a missing key returns ArtifactNotFound — no silent failures (QR-2).
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import thingfactory/types.{type StepError, ArtifactNotFound}

/// An artifact store scoped to a single pipeline run.
pub type ArtifactStore =
  Dict(String, Dynamic)

/// Create a new, empty artifact store.
pub fn new() -> ArtifactStore {
  dict.new()
}

/// Write a value to the artifact store under the given key.
/// Returns the updated store (pure functional — no mutation).
pub fn write(store: ArtifactStore, key: String, value: Dynamic) -> ArtifactStore {
  dict.insert(store, key, value)
}

/// Read a value from the artifact store by key.
/// Returns Ok(value) if found, Error(ArtifactNotFound(key)) if not.
pub fn read(store: ArtifactStore, key: String) -> Result(Dynamic, StepError) {
  case dict.get(store, key) {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error(ArtifactNotFound(key))
  }
}

/// Check whether a key exists in the store.
pub fn has_key(store: ArtifactStore, key: String) -> Bool {
  dict.has_key(store, key)
}

/// Return all keys currently in the store.
pub fn keys(store: ArtifactStore) -> List(String) {
  dict.keys(store)
}
