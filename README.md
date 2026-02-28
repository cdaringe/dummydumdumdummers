# Thingfactory - A Gleam-Native Pipeline Definition System

A best-in-class task runner for CI/CD with type-safe, testable pipeline definitions in Gleam.

## Objectives

- **Type-Safe Pipelines**: Define pipelines in Gleam with compile-time type checking
- **Testable**: Easily test pipelines with mocked steps
- **Observable**: Comprehensive execution traces for monitoring and debugging
- **Extensible**: Bring your own computation logic
- **First-Class Feature Support**: Artifacts, dependencies, versioning, and more

## Quick Start

### Basic Pipeline

```gleam
import thingfactory/pipeline
import thingfactory/executor
import thingfactory/types
import gleam/dynamic

let p = pipeline.new("my_pipeline", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    Ok(dynamic.string("data"))
  })
  |> pipeline.add_step("transform", fn(_ctx, data) {
    Ok(data)
  })

let config = types.default_config()
let result = executor.execute(p, dynamic.nil(), config)

case result.result {
  Ok(output) -> Nil  // Success
  Error(err) -> Nil  // Handle error
}
```

### Pipeline with Dependencies

Inject external dependencies into pipeline steps:

```gleam
let bindings = [
  types.Binding(name: "database_url", value: dynamic.string("postgres://...")),
  types.Binding(name: "api_key", value: dynamic.string("secret")),
]

let config = types.ExecutionConfig(
  default_step_timeout_ms: 30_000,
  dependency_bindings: bindings,
)

// In your step function:
fn(ctx, input) {
  case types.get_dep(ctx, "database_url") {
    Ok(url) -> process(url)
    Error(_) -> Error(types.StepFailure(message: "Missing database_url"))
  }
}
```

### Testing with Mocks

Unit test your pipelines without running actual steps:

```gleam
import thingfactory/test_helpers

let p = pipeline.new("test_pipeline", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    // This won't actually run in tests
    Ok(dynamic.string("real_data"))
  })

let mocks = [
  test_helpers.mock_step_success("fetch", dynamic.string("test_data")),
]

let result = test_helpers.run_with_mocks(p, mocks, dynamic.nil())
```

## Core Concepts

### Pipelines

A pipeline is a sequence of named steps that execute sequentially. Pipelines are:
- **Versioned** by name and semantic version
- **Type-safe** with Gleam's type system
- **Testable** with mock step support
- **Observable** with execution traces

### Steps

Steps are the fundamental unit of work. Each step:
- Receives a `Context` containing the artifact store and injected dependencies
- Receives the previous step's output (or initial input for the first step)
- Returns `Result(output, error)`

Steps execute sequentially - if a step fails, subsequent steps are skipped.

### Context

The `Context` provides steps with:
- **Artifact Store**: Dict for sharing data between steps
- **Dependencies**: Pre-injected external services or configuration

### Error Handling

Errors are explicit and typed:
- `StepFailure`: Step-level errors with messages
- `StepTimeout`: Step exceeded timeout
- `ArtifactNotFound`: Referenced artifact doesn't exist
- `StepError`: Step error propagated to pipeline level
- `PipelineError`: Higher-level pipeline errors

### Execution Traces

Every execution produces comprehensive traces including:
- Step name, status (Ok/Failed/Skipped), and duration
- Full error information for failed steps
- Skipped steps when pipeline fails

## API Overview

### Pipeline Builder

```gleam
// Create a new pipeline
pipeline.new(name: String, version: String) -> Pipeline(Nil)

// Add a step
pipeline.add_step(
  pipeline: Pipeline(a),
  name: String,
  run: fn(Context, Dynamic) -> Result(Dynamic, StepError),
) -> Pipeline(Dynamic)

// Set default timeout
pipeline.with_timeout(pipeline: Pipeline(a), timeout_ms: Int) -> Pipeline(a)

// Get pipeline metadata
pipeline.id(p: Pipeline(a)) -> PipelineId
pipeline.steps(p: Pipeline(a)) -> List(Step)
pipeline.default_timeout(p: Pipeline(a)) -> Int
```

### Executor

```gleam
// Execute a pipeline with configuration
executor.execute(
  pipeline: Pipeline(Dynamic),
  initial_input: Dynamic,
  config: ExecutionConfig,
) -> ExecutionResult(Dynamic)

// Execute with pre-built context (testing)
executor.execute_with_context(
  pipeline: Pipeline(Dynamic),
  initial_input: Dynamic,
  context: Context,
) -> ExecutionResult(Dynamic)
```

### Test Helpers

```gleam
// Create mocks
test_helpers.mock_step_success(name: String, output: Dynamic) -> Mock
test_helpers.mock_step_error(name: String, error: StepError) -> Mock
test_helpers.mock_step_fn(
  name: String,
  step_fn: fn(Context, Dynamic) -> Result(Dynamic, StepError),
) -> Mock

// Execute with mocks
test_helpers.run_with_mocks(
  pipeline: Pipeline(Dynamic),
  mocks: List(Mock),
  initial_input: Dynamic,
) -> ExecutionResult(Dynamic)
```

### Registry & Loader

```gleam
// Manage pipeline versions
registry.new() -> Registry
registry.register(reg: Registry, id: PipelineId, artifact: Artifact) -> Result(Registry, RegistryError)
registry.resolve(reg: Registry, id: PipelineId) -> Result(PipelineArtifact, RegistryError)
registry.has_pipeline(reg: Registry, id: PipelineId) -> Bool

// Load pipelines
loader.load(reg: Registry, id: PipelineId) -> Result(Dynamic, PipelineError)
loader.load_pipeline(reg: Registry, id: PipelineId) -> Result(Dynamic, PipelineError)
```

## Examples

See `src/thingfactory/examples.gleam` for complete working examples:

1. **Basic Sequential Pipeline** - Simple 3-step pipeline
2. **Error Handling** - Demonstrates error propagation
3. **Testing with Mocks** - Unit testing patterns
4. **Dependency Injection** - Using injected configuration
5. **Artifact Sharing** - Inter-step communication

Run the example tests:

```bash
gleam test  # Runs all tests including examples
```

## Architecture

### Type Safety

Gleam's type system ensures:
- Step input/output types are validated at compile time
- Error cases are explicit and cannot be ignored
- Configuration is type-safe

### Linear Execution

The MVP enforces:
- Sequential step execution (no branching)
- No loops within pipelines
- Deterministic behavior

### Isolation

Each execution has:
- Fresh artifact store
- Isolated dependencies
- No state leakage between runs

## Requirements Met

✅ FR-1: Pipeline Definition in Gleam
✅ FR-2: Sequential step execution
✅ FR-3: Error propagation
✅ FR-4: Artifact store with read/write
✅ FR-5: Timeout enforcement infrastructure
✅ FR-6: Registry with version conflict detection
✅ FR-7: Testing with mocks
✅ FR-8: Loader integration
✅ FR-9: Dependency injection
✅ QR-2: All error cases explicit/typed
✅ QR-3: Execution isolation
✅ QR-4: Linear execution only

## Future Enhancements

- Real timing implementation for duration_ms
- YAML pipeline support (parallel to Gleam)
- Conditional logic and branching
- Loop support
- External event triggering
- Scheduling support
- Web GUI (Next.js + React Flow)
- Persistent state management

## Development

### Building

```bash
gleam build      # Compile the project
gleam test       # Run all tests
gleam format     # Format code
```

### Project Structure

```
src/thingfactory/
  ├── pipeline.gleam           # Pipeline builder API
  ├── executor.gleam           # Step execution engine
  ├── types.gleam              # Core types and errors
  ├── test_helpers.gleam       # Mock/testing utilities
  ├── artifact_store.gleam     # Inter-step communication
  ├── dependency_injector.gleam # Dependency management
  ├── registry.gleam           # Pipeline versioning
  ├── loader.gleam             # Pipeline loading
  └── examples.gleam           # Example patterns

test/
  ├── *_test.gleam             # Comprehensive test suite
  └── examples_test.gleam      # Example verification
```

## License

Apache License 2.0
