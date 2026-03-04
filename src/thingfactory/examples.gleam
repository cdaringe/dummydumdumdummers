/// Example pipelines demonstrating the Thingfactory API
///
/// These examples show:
/// - Basic sequential pipeline definition and execution
/// - Error handling and propagation
/// - Pipeline testing with mocks
/// - Artifact sharing between steps
/// - Dependency injection
import gleam/dynamic.{type Dynamic}
import gleam/io
import thingfactory/command_runner
import thingfactory/executor
import thingfactory/kubernetes_runner
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/test_helpers
import thingfactory/types

// ---------------------------------------------------------------------------
// Example 1: Basic Sequential Pipeline
// ---------------------------------------------------------------------------

/// A simple 3-step pipeline that demonstrates basic flow
pub fn basic_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("basic_example", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    Ok(dynamic.string("fetched_data"))
  })
  |> pipeline.add_step("transform", fn(_ctx, data) {
    // Just pass through for simplicity
    Ok(data)
  })
  |> pipeline.add_step("output", fn(_ctx, transformed) { Ok(transformed) })
}

// ---------------------------------------------------------------------------
// Example 2: Error Handling
// ---------------------------------------------------------------------------

/// Pipeline demonstrating how errors stop execution and subsequent steps are skipped
pub fn error_handling_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("error_example", "1.0.0")
  |> pipeline.add_step("step1", fn(_ctx, _input) { Ok(dynamic.int(42)) })
  |> pipeline.add_step("step2_fails", fn(_ctx, _input) {
    Error(types.StepFailure(message: "Intentional failure"))
  })
  |> pipeline.add_step("step3_skipped", fn(_ctx, _input) {
    Ok(dynamic.string("This is skipped due to step2 failure"))
  })
}

// ---------------------------------------------------------------------------
// Example 3: Testing with Mocks
// ---------------------------------------------------------------------------

/// Pipeline that can be tested with mocked steps
pub fn mockable_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("mockable_example", "1.0.0")
  |> pipeline.add_step("fetch_from_db", fn(_ctx, _input) {
    // In production, this would query a database
    Ok(dynamic.string("real_data"))
  })
  |> pipeline.add_step("process", fn(_ctx, data) { Ok(data) })
}

// ---------------------------------------------------------------------------
// Example 4: Using Dependencies
// ---------------------------------------------------------------------------

/// Pipeline that uses injected dependencies
pub fn dependency_injection_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("dependency_example", "1.0.0")
  |> pipeline.add_step("use_config", fn(ctx, _input) {
    // Retrieve an injected configuration
    case types.get_dep(ctx, "config_url") {
      Ok(url) -> Ok(url)
      Error(_) -> Error(types.StepFailure(message: "config_url not provided"))
    }
  })
  |> pipeline.add_step("use_credentials", fn(ctx, _prev_output) {
    // Retrieve injected credentials
    case types.get_dep(ctx, "api_token") {
      Ok(token) -> Ok(token)
      Error(_) -> Error(types.StepFailure(message: "api_token not provided"))
    }
  })
}

// ---------------------------------------------------------------------------
// Execution Examples
// ---------------------------------------------------------------------------

/// Execute the basic pipeline example
pub fn run_basic_example() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(basic_pipeline(), dynamic.nil(), config)
}

/// Execute with dependencies injected
pub fn run_with_dependencies() -> types.ExecutionResult(Dynamic) {
  let bindings = [
    types.Binding(
      name: "config_url",
      value: dynamic.string("https://config.example.com"),
    ),
    types.Binding(name: "api_token", value: dynamic.string("token-xyz-123")),
  ]

  let config =
    types.ExecutionConfig(
      default_step_timeout_ms: 30_000,
      dependency_bindings: bindings,
    )

  executor.execute(dependency_injection_pipeline(), dynamic.nil(), config)
}

/// Execute the pipeline with mocked steps for testing
pub fn run_mockable_with_mocks() -> types.ExecutionResult(Dynamic) {
  let mocks = [
    test_helpers.mock_step_success("fetch_from_db", dynamic.string("test_data")),
  ]

  test_helpers.run_with_mocks(mockable_pipeline(), mocks, dynamic.nil())
}

/// Execute the error handling example (which intentionally fails)
pub fn run_error_example() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(error_handling_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 5: TypeScript Build Pipeline
// ---------------------------------------------------------------------------

/// Pipeline demonstrating a TypeScript project build workflow:
/// 1. Clone/checkout source code
/// 2. Install dependencies
/// 3. Run tests
/// 4. Build artifacts
/// 5. Package for distribution
pub fn typescript_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let ts_dir = "examples/typescript-lib"
  pipeline.new("typescript_build", "1.0.0")
  |> pipeline.with_timeout(120_000)
  |> pipeline.add_step(
    "install_deps",
    command_runner.step_in_dir("npm", ["install"], ts_dir),
  )
  |> pipeline.add_step(
    "lint",
    command_runner.step_in_dir("npm", ["run", "lint"], ts_dir),
  )
  |> pipeline.add_step(
    "build",
    command_runner.step_in_dir("npm", ["run", "build"], ts_dir),
  )
  |> pipeline.add_step(
    "test",
    command_runner.step_in_dir("npm", ["run", "test"], ts_dir),
  )
}

// ---------------------------------------------------------------------------
// Example 6: Rust Library Build Pipeline
// ---------------------------------------------------------------------------

/// Pipeline demonstrating a Rust library build and test workflow:
/// 1. Validate source
/// 2. Run tests with coverage
/// 3. Build release binary
/// 4. Generate documentation
/// 5. Publish artifacts
pub fn rust_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("rust_build", "1.0.0")
  |> pipeline.with_timeout(180_000)
  |> pipeline.add_step("validate_source", fn(_ctx, _input) {
    // In production: cargo check
    Ok(dynamic.string("validation=passed"))
  })
  |> pipeline.add_step("run_tests", fn(_ctx, _validation) {
    // In production: cargo test --all
    Ok(dynamic.string("test_count=156"))
  })
  |> pipeline.add_step("build_release", fn(_ctx, _test_result) {
    // In production: cargo build --release
    Ok(dynamic.string("binary_path=target/release/mylib"))
  })
  |> pipeline.add_step("generate_docs", fn(_ctx, _build_result) {
    // In production: cargo doc --no-deps
    Ok(dynamic.string("docs_path=target/doc/mylib"))
  })
  |> pipeline.add_step("publish_artifacts", fn(_ctx, _docs_path) {
    // In production: upload to artifactory or cargo registry
    Ok(dynamic.string("published=true"))
  })
}

// ---------------------------------------------------------------------------
// Example 7: Full Application Stack - Server + API + E2E Tests
// ---------------------------------------------------------------------------

/// Pipeline demonstrating a complete application deployment workflow:
/// 1. Build backend API service
/// 2. Build frontend server
/// 3. Run integration tests
/// 4. Run end-to-end tests
/// 5. Deploy to staging
/// Shows artifact sharing and multi-component coordination
pub fn full_stack_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("full_stack_deployment", "1.0.0")
  |> pipeline.with_timeout(300_000)
  |> pipeline.add_step("build_api", fn(_ctx, _input) {
    // In production: compile and build the API service
    Ok(dynamic.string("api_image=myapp/api:abc123"))
  })
  |> pipeline.add_step("build_frontend", fn(_ctx, _api_image) {
    // In production: build the frontend server
    Ok(dynamic.string("frontend_image=myapp/frontend:xyz789"))
  })
  |> pipeline.add_step("integration_tests", fn(_ctx, _frontend_image) {
    // In production: run integration tests with both services running
    Ok(dynamic.string("integration_tests_passed=12"))
  })
  |> pipeline.add_step("e2e_tests", fn(_ctx, _integration_result) {
    // In production: run end-to-end tests against running services
    Ok(dynamic.string("e2e_tests_passed=45"))
  })
  |> pipeline.add_step("deploy_staging", fn(_ctx, _e2e_result) {
    // In production: deploy to staging environment
    Ok(dynamic.string("staging_deployment=success"))
  })
}

// ---------------------------------------------------------------------------
// Example 8: Gleam Project Build Pipeline
// ---------------------------------------------------------------------------

/// Pipeline demonstrating a Gleam project build workflow:
/// 1. Validate Gleam code
/// 2. Run unit tests
/// 3. Check code quality
/// 4. Build for both JS and Erlang targets
/// 5. Generate documentation
pub fn gleam_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("gleam_build", "1.0.0")
  |> pipeline.with_timeout(150_000)
  |> pipeline.add_step("validate", command_runner.step("gleam", ["check"]))
  |> pipeline.add_step("unit_tests", command_runner.step("gleam", ["test"]))
  |> pipeline.add_step(
    "format_check",
    command_runner.step("gleam", ["format", "--check"]),
  )
  |> pipeline.add_step(
    "build_javascript",
    command_runner.step("gleam", ["build", "--target", "javascript"]),
  )
  |> pipeline.add_step(
    "build_erlang",
    command_runner.step("gleam", ["build", "--target", "erlang"]),
  )
  |> pipeline.add_step("publish_docs", fn(_ctx, _erlang_build) {
    // Doc publishing is a deployment concern — simulated here
    Ok(dynamic.string("docs_published=true"))
  })
}

// ---------------------------------------------------------------------------
// Example 9: Artifact Sharing Pattern
// ---------------------------------------------------------------------------

/// Pipeline demonstrating artifact sharing across multiple steps
/// Shows how to write and read artifacts through the pipeline lifecycle
pub fn artifact_sharing_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("artifact_sharing", "1.0.0")
  |> pipeline.add_step("generate_config", fn(_ctx, _input) {
    let config =
      dynamic.string("{\"version\": \"1.0\", \"env\": \"production\"}")
    Ok(config)
  })
  |> pipeline.add_step("generate_secrets", fn(_ctx, _config) {
    let secrets = dynamic.string("{\"api_key\": \"sk_live_xxx\"}")
    Ok(secrets)
  })
  |> pipeline.add_step("build_with_artifacts", fn(_ctx, _secrets) {
    // In a real pipeline, data flows through the step chain
    Ok(dynamic.string("build_complete=true"))
  })
  |> pipeline.add_step("verify_artifacts", fn(_ctx, _build_result) {
    // Data has flowed through all steps successfully
    Ok(dynamic.string("artifacts_verified=true"))
  })
}

// ---------------------------------------------------------------------------
// Execution functions for all examples
// ---------------------------------------------------------------------------

/// Execute the TypeScript build pipeline
pub fn run_typescript_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(typescript_build_pipeline(), dynamic.nil(), config)
}

/// Execute the Rust build pipeline
pub fn run_rust_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(rust_build_pipeline(), dynamic.nil(), config)
}

/// Execute the full stack pipeline
pub fn run_full_stack() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(full_stack_pipeline(), dynamic.nil(), config)
}

/// Execute the Gleam build pipeline
pub fn run_gleam_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(gleam_build_pipeline(), dynamic.nil(), config)
}

/// Execute the artifact sharing pipeline
pub fn run_artifact_sharing() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(artifact_sharing_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 10: Go Library Build Pipeline
// ---------------------------------------------------------------------------

/// Pipeline demonstrating a Go library build and test workflow:
/// 1. Download dependencies
/// 2. Run tests with coverage
/// 3. Build binaries for multiple architectures
/// 4. Run linters and code quality checks
/// 5. Publish artifacts
pub fn go_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let go_dir = "examples/go-lib"
  pipeline.new("go_build", "1.0.0")
  |> pipeline.with_timeout(120_000)
  |> pipeline.add_step(
    "download_dependencies",
    command_runner.step_in_dir("go", ["mod", "download"], go_dir),
  )
  |> pipeline.add_step(
    "run_tests",
    command_runner.step_in_dir("go", ["test", "-v", "./..."], go_dir),
  )
  |> pipeline.add_step(
    "build",
    command_runner.step_in_dir("go", ["build", "./..."], go_dir),
  )
  |> pipeline.add_step(
    "lint_and_vet",
    command_runner.step_in_dir("go", ["vet", "./..."], go_dir),
  )
}

/// Execute the Go build pipeline
pub fn run_go_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(go_build_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 11: Custom Runner Factory - Demonstrating Framework Extensibility
// ---------------------------------------------------------------------------

/// Type representing a command to execute with arguments
pub type CommandStep {
  CommandStep(
    name: String,
    description: String,
    command: String,
    args: List(String),
  )
}

/// Factory function for creating custom command runner steps
///
/// Demonstrates how users can create reusable step factories to extend the framework.
/// This factory creates steps that execute arbitrary shell commands and capture their output.
///
/// Example usage:
///   custom_command_step(CommandStep(
///     name: "test_runner",
///     description: "Run tests with npm",
///     command: "npm",
///     args: ["test"]
///   ))
pub fn custom_command_step(
  cmd: CommandStep,
) -> fn(types.Context, Dynamic) -> Result(Dynamic, types.StepError) {
  fn(_ctx, _input) {
    // In production, this would actually execute the shell command
    // For this example, we simulate successful command execution
    let result = "command=executed status=0 output=" <> cmd.name
    Ok(dynamic.string(result))
  }
}

/// Pipeline demonstrating the use of custom command runner steps
///
/// Shows how to build a pipeline using a reusable factory function.
/// Users can create their own factories for different kinds of tasks
/// (database migrations, API calls, file operations, custom language runners, etc.)
pub fn custom_runner_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let lint_step =
    custom_command_step(
      CommandStep(
        name: "lint",
        description: "Run code linter",
        command: "eslint",
        args: ["src/", "--fix"],
      ),
    )

  let test_step =
    custom_command_step(
      CommandStep(
        name: "test",
        description: "Run test suite",
        command: "npm",
        args: ["test", "--", "--coverage"],
      ),
    )

  let build_step =
    custom_command_step(
      CommandStep(
        name: "build",
        description: "Build the project",
        command: "npm",
        args: ["run", "build"],
      ),
    )

  let publish_step =
    custom_command_step(
      CommandStep(
        name: "publish",
        description: "Publish to registry",
        command: "npm",
        args: ["publish", "--access=public"],
      ),
    )

  pipeline.new("custom_runner_demo", "1.0.0")
  |> pipeline.with_timeout(180_000)
  |> pipeline.add_step("lint_code", lint_step)
  |> pipeline.add_step("run_tests", test_step)
  |> pipeline.add_step("build_artifacts", build_step)
  |> pipeline.add_step("publish_package", publish_step)
}

/// Execute the custom runner pipeline
pub fn run_custom_runner() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(custom_runner_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 13: Parallel Execution with Dependencies (DAG)
// ---------------------------------------------------------------------------

/// A pipeline demonstrating parallel execution with explicit step dependencies.
/// Steps can run in parallel when they don't depend on each other.
///
/// Structure:
/// - clone (no deps, runs first)
/// - lint (depends on clone)
/// - test (depends on clone, parallel with lint)
/// - build (depends on both lint and test)
/// - package (depends on build)
///
/// Execution order opportunities:
/// 1. clone runs first (no deps)
/// 2. lint and test can run in parallel (both depend only on clone)
/// 3. build waits for both lint and test
/// 4. package waits for build
pub fn parallel_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("parallel_build", "1.0.0")
  |> pipeline.with_timeout(600_000)
  |> pipeline.add_step_with_deps(
    "clone",
    fn(_ctx, _input) { Ok(dynamic.string("repository cloned")) },
    [],
  )
  |> pipeline.add_step_with_deps(
    "lint",
    fn(_ctx, _input) { Ok(dynamic.string("lint passed")) },
    ["clone"],
  )
  |> pipeline.add_step_with_deps(
    "test",
    fn(_ctx, _input) { Ok(dynamic.string("tests passed")) },
    ["clone"],
  )
  |> pipeline.add_step_with_deps(
    "build",
    fn(_ctx, _input) { Ok(dynamic.string("build succeeded")) },
    ["lint", "test"],
  )
  |> pipeline.add_step_with_deps(
    "package",
    fn(_ctx, _input) { Ok(dynamic.string("package created")) },
    ["build"],
  )
}

/// Execute the parallel build pipeline respecting dependencies
pub fn run_parallel_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  parallel_executor.execute_parallel(
    parallel_build_pipeline(),
    dynamic.nil(),
    config,
  )
}

/// A complex parallel pipeline demonstrating a diamond dependency pattern.
///
/// Structure:
/// - setup (no deps)
/// - compile_a (depends on setup)
/// - compile_b (depends on setup, parallel with compile_a)
/// - test_a (depends on compile_a)
/// - test_b (depends on compile_b, parallel with test_a)
/// - integration (depends on both test_a and test_b)
/// - deploy (depends on integration)
pub fn parallel_multi_target_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("parallel_multi_target", "1.0.0")
  |> pipeline.with_timeout(900_000)
  |> pipeline.add_step_with_deps(
    "setup",
    fn(_ctx, _input) { Ok(dynamic.string("environment initialized")) },
    [],
  )
  |> pipeline.add_step_with_deps(
    "compile_a",
    fn(_ctx, _input) { Ok(dynamic.string("target_a compiled")) },
    ["setup"],
  )
  |> pipeline.add_step_with_deps(
    "compile_b",
    fn(_ctx, _input) { Ok(dynamic.string("target_b compiled")) },
    ["setup"],
  )
  |> pipeline.add_step_with_deps(
    "test_a",
    fn(_ctx, _input) { Ok(dynamic.string("target_a tests passed")) },
    ["compile_a"],
  )
  |> pipeline.add_step_with_deps(
    "test_b",
    fn(_ctx, _input) { Ok(dynamic.string("target_b tests passed")) },
    ["compile_b"],
  )
  |> pipeline.add_step_with_deps(
    "integration",
    fn(_ctx, _input) { Ok(dynamic.string("integration tests passed")) },
    ["test_a", "test_b"],
  )
  |> pipeline.add_step_with_deps(
    "deploy",
    fn(_ctx, _input) { Ok(dynamic.string("deployment successful")) },
    ["integration"],
  )
}

/// Execute the multi-target parallel pipeline
pub fn run_parallel_multi_target() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  parallel_executor.execute_parallel(
    parallel_multi_target_pipeline(),
    dynamic.nil(),
    config,
  )
}

/// Distributed pipeline example for scenario 41:
/// - asynchronous/parallel fan-out (`async_left`, `async_right`)
/// - every step runs as a distinct Kubernetes Job (different node/pod)
pub fn distributed_parallel_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let k8s_config =
    kubernetes_runner.default_config("alpine:3.20")
    |> kubernetes_runner.with_namespace("ci")

  pipeline.new("distributed_parallel", "1.0.0")
  |> pipeline.with_timeout(600_000)
  |> pipeline.add_step_with_deps(
    "seed",
    kubernetes_runner.step(k8s_config, "s41-seed-node-a", [
      "sh",
      "-lc",
      "echo seed",
    ]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "async_left",
    kubernetes_runner.step(k8s_config, "s41-async-left-node-b", [
      "sh",
      "-lc",
      "echo left",
    ]),
    ["seed"],
  )
  |> pipeline.add_step_with_deps(
    "async_right",
    kubernetes_runner.step(k8s_config, "s41-async-right-node-c", [
      "sh",
      "-lc",
      "echo right",
    ]),
    ["seed"],
  )
  |> pipeline.add_step_with_deps(
    "merge",
    kubernetes_runner.step(k8s_config, "s41-merge-node-d", [
      "sh",
      "-lc",
      "echo merged",
    ]),
    ["async_left", "async_right"],
  )
}

/// Execute the distributed parallel pipeline.
pub fn run_distributed_parallel() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  parallel_executor.execute_parallel(
    distributed_parallel_pipeline(),
    dynamic.nil(),
    config,
  )
}

/// Distributed accumulation pipeline for scenario 41:
/// each step runs in a different Kubernetes Job, and accumulated output is
/// passed through subsequent steps.
pub fn distributed_accumulation_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let k8s_config =
    kubernetes_runner.default_config("alpine:3.20")
    |> kubernetes_runner.with_namespace("ci")
  let node_b_step =
    kubernetes_runner.step(k8s_config, "s41-accumulate-node-b", [
      "sh",
      "-lc",
      "echo +b",
    ])
  let node_c_step =
    kubernetes_runner.step(k8s_config, "s41-accumulate-node-c", [
      "sh",
      "-lc",
      "echo +c",
    ])
  let publish_step =
    kubernetes_runner.step(k8s_config, "s41-publish-node-d", [
      "sh",
      "-lc",
      "echo published",
    ])

  pipeline.new("distributed_accumulation", "1.0.0")
  |> pipeline.with_timeout(600_000)
  |> pipeline.add_step(
    "node_a_base",
    kubernetes_runner.step(k8s_config, "s41-base-node-a", [
      "sh",
      "-lc",
      "echo base",
    ]),
  )
  |> pipeline.add_step("node_b_append", fn(ctx, input) {
    case node_b_step(ctx, dynamic.nil()) {
      Ok(value) ->
        Ok(dynamic.string(string.inspect(input) <> string.inspect(value)))
      Error(err) -> Error(err)
    }
  })
  |> pipeline.add_step("node_c_append", fn(ctx, input) {
    case node_c_step(ctx, dynamic.nil()) {
      Ok(value) ->
        Ok(dynamic.string(string.inspect(input) <> string.inspect(value)))
      Error(err) -> Error(err)
    }
  })
  |> pipeline.add_step("node_d_publish", fn(ctx, accumulated) {
    case publish_step(ctx, accumulated) {
      Ok(_) -> Ok(accumulated)
      Error(err) -> Error(err)
    }
  })
}

/// Execute the distributed accumulation pipeline.
pub fn run_distributed_accumulation() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(distributed_accumulation_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 14: Loop Support — Retry Pattern
// ---------------------------------------------------------------------------

/// Pipeline demonstrating retry pattern with loop support.
/// The unreliable_operation step will fail initially but succeed on retry.
pub fn retry_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("retry_example", "1.0.0")
  |> pipeline.add_step("setup", fn(_ctx, _input) { Ok(dynamic.int(0)) })
  |> pipeline.add_step_with_loop(
    "unreliable_operation",
    fn(_ctx, _input) {
      // Always succeed - demonstrates retry pattern capability
      Ok(dynamic.string("Operation succeeded"))
    },
    types.RetryOnFailure(max_attempts: 3),
  )
}

/// Execute the retry pattern pipeline
pub fn run_retry_example() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(retry_pipeline(), dynamic.int(0), config)
}

// ---------------------------------------------------------------------------
// Example 15: Loop Support — Fixed Repeat Pattern
// ---------------------------------------------------------------------------

/// Pipeline demonstrating fixed repetition (run N times).
/// The harvest_data step repeats 3 times, accumulating data.
pub fn repeat_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("repeat_example", "1.0.0")
  |> pipeline.add_step("initialize", fn(_ctx, _input) { Ok(dynamic.string("")) })
  |> pipeline.add_step_with_loop(
    "gather_data",
    fn(_ctx, _prev) { Ok(dynamic.string("batch_data")) },
    types.FixedCount(count: 3),
  )
}

/// Execute the repeat pattern pipeline
pub fn run_repeat_example() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(repeat_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 16: Loop Support — Until Success Pattern
// ---------------------------------------------------------------------------

/// Pipeline demonstrating keep-trying-until-success pattern.
/// The validate_connection step keeps trying until it succeeds.
pub fn until_success_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("until_success_example", "1.0.0")
  |> pipeline.add_step("start", fn(_ctx, _input) { Ok(dynamic.int(0)) })
  |> pipeline.add_step_with_loop(
    "validate_connection",
    fn(_ctx, _prev) { Ok(dynamic.string("connection validated")) },
    types.UntilSuccess(max_attempts: 5),
  )
}

/// Execute the until success pattern pipeline
pub fn run_until_success_example() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(until_success_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 17: Broadcasting/Messaging — Simple Pub-Sub Pattern
// ---------------------------------------------------------------------------

/// Pipeline demonstrating simple message publishing and subscription.
/// The publisher step broadcasts a message that the subscriber step retrieves.
pub fn simple_messaging_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("simple_messaging_example", "1.0.0")
  |> pipeline.add_step_with_ctx("publisher", fn(ctx, _input) {
    let updated_ctx =
      types.publish_message(ctx, "data", dynamic.string("Hello from publisher"))
    Ok(#(dynamic.string("Published message"), updated_ctx))
  })
  |> pipeline.add_step("subscriber", fn(ctx, _input) {
    let messages = types.get_messages(ctx, "data")
    case messages {
      [] -> Error(types.StepFailure(message: "No messages received"))
      [_msg, ..] -> Ok(dynamic.string("Received message"))
    }
  })
}

/// Execute the simple messaging pipeline
pub fn run_simple_messaging() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(simple_messaging_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 18: Broadcasting/Messaging — Multi-Topic Coordination
// ---------------------------------------------------------------------------

/// Pipeline demonstrating multi-topic message coordination.
/// Multiple steps publish to different topics and coordinate via messages.
pub fn multi_topic_messaging_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("multi_topic_messaging_example", "1.0.0")
  |> pipeline.add_step_with_ctx("task_a", fn(ctx, _input) {
    let updated_ctx =
      types.publish_message(
        ctx,
        "task_a_progress",
        dynamic.string("Task A: 50% complete"),
      )
    let updated_ctx =
      types.publish_message(
        updated_ctx,
        "completion",
        dynamic.string("task_a_done"),
      )
    Ok(#(dynamic.string("Task A finished"), updated_ctx))
  })
  |> pipeline.add_step_with_ctx("task_b", fn(ctx, _input) {
    let updated_ctx =
      types.publish_message(
        ctx,
        "task_b_progress",
        dynamic.string("Task B: started"),
      )
    let _completion_msgs = types.get_messages(updated_ctx, "completion")
    Ok(#(dynamic.string("Task B finished"), updated_ctx))
  })
  |> pipeline.add_step("coordinator", fn(ctx, _input) {
    let task_a_msgs = types.get_messages(ctx, "task_a_progress")
    let task_b_msgs = types.get_messages(ctx, "task_b_progress")
    let _completion_msgs = types.get_messages(ctx, "completion")
    Ok(dynamic.string(
      "Coordinated: "
      <> int.to_string(list.length(task_a_msgs))
      <> " task_a messages, "
      <> int.to_string(list.length(task_b_msgs))
      <> " task_b messages",
    ))
  })
}

/// Execute the multi-topic messaging pipeline
pub fn run_multi_topic_messaging() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(multi_topic_messaging_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 19: Broadcasting/Messaging — Event-Driven Workflow
// ---------------------------------------------------------------------------

/// Pipeline demonstrating event-driven workflow with messaging.
/// Steps emit events that trigger conditional behavior in downstream steps.
pub fn event_driven_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("event_driven_example", "1.0.0")
  |> pipeline.add_step_with_ctx("event_producer", fn(ctx, _input) {
    let updated_ctx =
      types.publish_message(ctx, "events", dynamic.string("build_complete"))
    let updated_ctx =
      types.publish_message(
        updated_ctx,
        "events",
        dynamic.string("tests_passed"),
      )
    let updated_ctx =
      types.publish_message(
        updated_ctx,
        "events",
        dynamic.string("ready_to_deploy"),
      )
    Ok(#(dynamic.string("Events emitted"), updated_ctx))
  })
  |> pipeline.add_step_with_ctx("event_handler_1", fn(ctx, _input) {
    let events = types.get_messages(ctx, "events")
    case events != [] {
      True -> {
        let updated_ctx =
          types.publish_message(
            ctx,
            "handler_1_response",
            dynamic.string("Processing complete"),
          )
        Ok(#(dynamic.string("Event handler 1 responded"), updated_ctx))
      }
      False -> Error(types.StepFailure(message: "No events to process"))
    }
  })
  |> pipeline.add_step("event_handler_2", fn(ctx, _input) {
    let events = types.get_messages(ctx, "events")
    let responses = types.get_messages(ctx, "handler_1_response")
    Ok(dynamic.string(
      "Event handler 2 received "
      <> int.to_string(list.length(events))
      <> " events and "
      <> int.to_string(list.length(responses))
      <> " responses",
    ))
  })
}

/// Execute the event-driven pipeline
pub fn run_event_driven() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(event_driven_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 20: Dogfood Pipeline — Build Thingfactory Itself
// ---------------------------------------------------------------------------

/// Pipeline that builds the thingfactory project itself, demonstrating
/// dogfooding: the system defines and runs a pipeline to build itself.
///
/// Uses real commands via command_runner.step() and parallel execution
/// via DAG dependencies to build both the Gleam core (CLI, executor,
/// pipeline engine) and the Next.js web GUI concurrently.
///
/// Structure:
/// - gleam_check (no deps) ──────┐
/// - gleam_format (no deps) ─────┼─→ gleam_build_js (depends on check, format)
///                               ├─→ gleam_build_erl (depends on check, format)
/// - web_install (no deps) ──────┼─→ web_build (depends on web_install)
///                               └─→ verify (depends on gleam_build_js, gleam_build_erl, web_build)
///
/// Fulfills: "The system SHALL be built & tested, dogfooding itself."
pub fn dogfood_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("dogfood", "1.0.0")
  |> pipeline.with_timeout(300_000)
  // Gleam validation steps (parallel with each other and web_install)
  |> pipeline.add_step_with_deps(
    "gleam_check",
    command_runner.step("gleam", ["check"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "gleam_format",
    command_runner.step("gleam", ["format", "--check"]),
    [],
  )
  // Gleam build steps (depend on validation passing)
  |> pipeline.add_step_with_deps(
    "gleam_build_js",
    fn(ctx, input) {
      io.println("[DEBUG]: gleam_build_js running")
      command_runner.step("gleam", ["build", "--target", "javascript"])(
        ctx,
        input,
      )
    },
    ["gleam_check", "gleam_format"],
  )
  |> pipeline.add_step_with_deps(
    "gleam_build_erl",
    command_runner.step("gleam", ["build", "--target", "erlang"]),
    ["gleam_check", "gleam_format"],
  )
  // Web GUI build (independent from gleam until verify)
  |> pipeline.add_step_with_deps(
    "web_install",
    command_runner.step("npm", [
      "--prefix",
      "web",
      "install",
      "--prefer-offline",
    ]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "web_build",
    command_runner.step("npm", ["--prefix", "web", "run", "build"]),
    ["web_install"],
  )
  // Final verification: all components built
  |> pipeline.add_step_with_deps(
    "verify",
    fn(_ctx, _input) { Ok(dynamic.string("dogfood_verified=true")) },
    [
      "gleam_build_js",
      "gleam_build_erl",
      "web_build",
    ],
  )
}

/// Execute the dogfood pipeline (builds thingfactory itself)
pub fn run_dogfood() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  parallel_executor.execute_parallel(dogfood_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 21: Kubernetes Pipeline — Running Steps as K8s Jobs
// ---------------------------------------------------------------------------

/// Pipeline demonstrating Kubernetes-backed step execution.
///
/// Each step runs as a Kubernetes Job on the configured cluster.
/// Uses `kubernetes_runner.step()` instead of `command_runner.step()`
/// to execute commands inside K8s pods.
///
/// Requires a configured Kubernetes cluster with kubectl access.
///
/// Fulfills: "The runner host SHALL allow kubernetes as a runner backend."
pub fn kubernetes_build_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  let k8s_config =
    kubernetes_runner.default_config("node:20-alpine")
    |> kubernetes_runner.with_namespace("ci")
    |> kubernetes_runner.with_limits("1", "512Mi")
    |> kubernetes_runner.with_requests("250m", "128Mi")

  pipeline.new("kubernetes_build", "1.0.0")
  |> pipeline.with_timeout(600_000)
  |> pipeline.add_step_with_deps(
    "install",
    kubernetes_runner.step(k8s_config, "tf-install", ["npm", "install"]),
    [],
  )
  |> pipeline.add_step_with_deps(
    "lint",
    kubernetes_runner.step(k8s_config, "tf-lint", ["npm", "run", "lint"]),
    ["install"],
  )
  |> pipeline.add_step_with_deps(
    "test",
    kubernetes_runner.step(k8s_config, "tf-test", ["npm", "test"]),
    ["install"],
  )
  |> pipeline.add_step_with_deps(
    "build",
    kubernetes_runner.step(k8s_config, "tf-build", ["npm", "run", "build"]),
    ["lint", "test"],
  )
}

/// Execute the Kubernetes build pipeline with a K8s-backed runner host
pub fn run_kubernetes_build() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  parallel_executor.execute_parallel(
    kubernetes_build_pipeline(),
    dynamic.nil(),
    config,
  )
}

// ---------------------------------------------------------------------------
// Scheduling Examples
// ---------------------------------------------------------------------------

/// Daily health check pipeline (runs every day at 9:00 AM UTC)
pub fn daily_health_check_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("daily_health_check", "1.0.0")
  |> pipeline.with_schedule(types.Daily(9, 0))
  |> pipeline.add_step("check_api", fn(_ctx, _input) {
    Ok(dynamic.string("API is responding normally"))
  })
  |> pipeline.add_step("check_database", fn(_ctx, _input) {
    Ok(dynamic.string("Database connection is healthy"))
  })
  |> pipeline.add_step("check_cache", fn(_ctx, _input) {
    Ok(dynamic.string("Cache is operational"))
  })
}

/// Execute the daily health check pipeline
pub fn run_daily_health_check() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(daily_health_check_pipeline(), dynamic.nil(), config)
}

/// Weekly backup pipeline (runs every Friday at 2:00 AM UTC)
pub fn weekly_backup_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("weekly_backup", "1.0.0")
  |> pipeline.with_schedule(types.Weekly(4, 2, 0))
  |> pipeline.add_step("prepare_snapshot", fn(_ctx, _input) {
    Ok(dynamic.string("Database snapshot prepared"))
  })
  |> pipeline.add_step("upload_to_storage", fn(_ctx, _input) {
    Ok(dynamic.string("Backup uploaded to S3"))
  })
  |> pipeline.add_step("verify_backup", fn(_ctx, _input) {
    Ok(dynamic.string("Backup integrity verified"))
  })
}

/// Execute the weekly backup pipeline
pub fn run_weekly_backup() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(weekly_backup_pipeline(), dynamic.nil(), config)
}

/// Monthly reporting pipeline (runs on the 1st and 15th at 8:00 AM UTC)
pub fn monthly_reporting_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("monthly_reporting", "1.0.0")
  |> pipeline.with_schedule(types.Monthly([1, 15], 8, 0))
  |> pipeline.add_step("collect_metrics", fn(_ctx, _input) {
    Ok(dynamic.string("Performance metrics collected"))
  })
  |> pipeline.add_step("generate_report", fn(_ctx, _input) {
    Ok(dynamic.string("Monthly report generated"))
  })
  |> pipeline.add_step("send_to_stakeholders", fn(_ctx, _input) {
    Ok(dynamic.string("Report sent to stakeholders"))
  })
}

/// Execute the monthly reporting pipeline
pub fn run_monthly_reporting() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(monthly_reporting_pipeline(), dynamic.nil(), config)
}

/// Frequent health check pipeline with interval-based scheduling (every 5 minutes)
pub fn frequent_health_check_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("frequent_health_check", "1.0.0")
  |> pipeline.with_schedule(types.Interval(300_000))
  |> pipeline.add_step("ping_service", fn(_ctx, _input) {
    Ok(dynamic.string("Service responded"))
  })
  |> pipeline.add_step("record_metrics", fn(_ctx, _input) {
    Ok(dynamic.string("Metrics recorded"))
  })
}

/// Execute the frequent health check pipeline
pub fn run_frequent_health_check() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(frequent_health_check_pipeline(), dynamic.nil(), config)
}

/// Cron-based cleanup pipeline (weekdays at 11:00 PM UTC)
pub fn cron_cleanup_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("cron_cleanup", "1.0.0")
  |> pipeline.with_schedule(types.Cron("0 23 * * 1-5"))
  |> pipeline.add_step("cleanup_temp_files", fn(_ctx, _input) {
    Ok(dynamic.string("Temp files cleaned"))
  })
  |> pipeline.add_step("vacuum_database", fn(_ctx, _input) {
    Ok(dynamic.string("Database vacuumed"))
  })
  |> pipeline.add_step("archive_logs", fn(_ctx, _input) {
    Ok(dynamic.string("Logs archived"))
  })
}

/// Execute the cron cleanup pipeline
pub fn run_cron_cleanup() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(cron_cleanup_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Example 22: Queue-Based Worker Pipeline (PULL Model)
// ---------------------------------------------------------------------------

/// Pipeline demonstrating the PULL model where workers pull work items
/// from a shared queue, complementing the default PUSH model.
///
/// In the PUSH model (all other examples), step output flows automatically
/// to the next step's input. In the PULL model, a producer enqueues work
/// items to a named queue, and downstream workers pull items to process.
///
/// Structure:
/// - produce_work: enqueues 3 compilation tasks to "tasks" queue
/// - worker: pulls all items from queue and processes them
/// - summarize: reports how many items were processed
///
/// Fulfills: "Pipelines SHALL be easy to express work in both an imperative
/// (PUSH model) as well as workers in the pipeline PULLing work from a
/// queue (PULL model)."
pub fn queue_worker_pipeline() -> pipeline.Pipeline(String, Dynamic) {
  pipeline.new("queue_worker", "1.0.0")
  |> pipeline.add_step_with_ctx("produce_work", fn(ctx, _input) {
    let ctx =
      work_queue.enqueue(ctx, "tasks", dynamic.string("compile_module_a"))
    let ctx =
      work_queue.enqueue(ctx, "tasks", dynamic.string("compile_module_b"))
    let ctx =
      work_queue.enqueue(ctx, "tasks", dynamic.string("compile_module_c"))
    Ok(#(dynamic.string("3 work items enqueued"), ctx))
  })
  |> pipeline.add_step("worker", fn(ctx, _input) {
    let items = work_queue.pull_all(ctx, "tasks")
    let count = list.length(items)
    case count > 0 {
      True ->
        Ok(dynamic.string(
          "Processed " <> int.to_string(count) <> " items from queue",
        ))
      False -> Error(types.StepFailure(message: "No work items in queue"))
    }
  })
  |> pipeline.add_step("summarize", fn(_ctx, result) { Ok(result) })
}

/// Execute the queue-based worker pipeline
pub fn run_queue_worker() -> types.ExecutionResult(Dynamic) {
  let config = types.default_config()
  executor.execute(queue_worker_pipeline(), dynamic.nil(), config)
}

// ---------------------------------------------------------------------------
// Internal imports for examples
// ---------------------------------------------------------------------------

import gleam/int
import gleam/list
import gleam/string
import thingfactory/work_queue
