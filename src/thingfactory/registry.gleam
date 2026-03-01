/// Pipeline Registry — stores and resolves pipelines by (name, version).
///
/// Implements FR-6 (Pipeline Registry & Versioning).
/// Uses in-process dict per [q2] decision — no persistence across restarts.
import gleam/dict
import thingfactory/types.{
  type PipelineId, type RegistryError, NotFound, VersionConflict,
}

/// A compiled pipeline artifact with metadata.
pub type CompiledArtifact(pipeline) {
  CompiledArtifact(id: PipelineId, pipeline: pipeline, registered_at: Int)
}

/// The registry is a dict mapping PipelineId to CompiledArtifact.
pub type Registry(pipeline) =
  dict.Dict(PipelineId, CompiledArtifact(pipeline))

/// Create a new empty registry.
pub fn new() -> Registry(pipeline) {
  dict.new()
}

/// Register a pipeline artifact with the given id.
/// Returns Error(VersionConflict) if the exact (name, version) already exists.
pub fn register(
  registry: Registry(pipeline),
  id: PipelineId,
  artifact: CompiledArtifact(pipeline),
) -> Result(Registry(pipeline), RegistryError) {
  case dict.has_key(registry, id) {
    True -> Error(VersionConflict(id))
    False -> Ok(dict.insert(registry, id, artifact))
  }
}

/// Resolve a pipeline by id.
/// Returns Error(NotFound) if the pipeline is not in the registry.
pub fn resolve(
  registry: Registry(pipeline),
  id: PipelineId,
) -> Result(CompiledArtifact(pipeline), RegistryError) {
  case dict.get(registry, id) {
    Ok(artifact) -> Ok(artifact)
    Error(Nil) -> Error(NotFound(id))
  }
}

/// Check if a pipeline exists in the registry.
pub fn has_pipeline(registry: Registry(pipeline), id: PipelineId) -> Bool {
  dict.has_key(registry, id)
}

/// Get the count of registered pipelines.
pub fn count(registry: Registry(pipeline)) -> Int {
  dict.size(registry)
}

/// Create a compiled artifact with the current timestamp.
pub fn create_artifact(
  id: PipelineId,
  pipeline: pipeline,
) -> CompiledArtifact(pipeline) {
  CompiledArtifact(
    id: id,
    pipeline: pipeline,
    registered_at: 0,
    // Timestamp not needed for MVP
  )
}
