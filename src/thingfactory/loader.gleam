/// Pipeline Loader — retrieves and instantiates pipelines from the registry.
///
/// Implements FR-8 (Pipeline Load & Execution).
/// Thin wrapper around registry per [q2] decision.
import thingfactory/registry.{type CompiledArtifact, type Registry}
import thingfactory/types.{type PipelineError, type PipelineId, LoadError}

/// Load a pipeline from the registry by id.
/// Returns Error(LoadError) if the pipeline is not found.
pub fn load(
  registry: Registry(pipeline),
  id: PipelineId,
) -> Result(CompiledArtifact(pipeline), PipelineError) {
  case registry.resolve(registry, id) {
    Ok(artifact) -> Ok(artifact)
    Error(_) ->
      Error(LoadError("pipeline not found: " <> pipeline_id_to_string(id)))
  }
}

/// Load and extract the pipeline value from a compiled artifact.
pub fn load_pipeline(
  registry: Registry(pipeline),
  id: PipelineId,
) -> Result(pipeline, PipelineError) {
  case load(registry, id) {
    Ok(artifact) -> Ok(artifact.pipeline)
    Error(e) -> Error(e)
  }
}

fn pipeline_id_to_string(id: PipelineId) -> String {
  id.name <> "@" <> id.version
}
