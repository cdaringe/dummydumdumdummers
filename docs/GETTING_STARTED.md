# Getting Started

Install Thingfactory and run your first pipeline.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Run an Example Pipeline](#run-an-example-pipeline)
- [List Available Pipelines](#list-available-pipelines)
- [Define Your Own Pipeline](#define-your-own-pipeline)
- [Testing Pipelines](#testing-pipelines)
- [Next Steps](#next-steps)

## Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/) >= 1.13.0
- [Node.js](https://nodejs.org/) >= 22 (for JavaScript target)
- [Docker](https://docs.docker.com/get-docker/) (optional, for containerized execution)

## Installation

Clone and build:

```bash
git clone <repo-url> thingfactory
cd thingfactory
gleam build
```

For the web GUI:

```bash
cd web
npm install
npm run dev
```

## Run an Example Pipeline

Run a built-in example by name or number:

```bash
gleam run -m thingfactory/cli -- run basic
```

Or with verbose output:

```bash
gleam run -m thingfactory/cli -- run typescript
```

Compact mode (progress bar style):

```bash
gleam run -m thingfactory/cli -- run parallel -c
```

Interactive mode (drill into results after execution):

```bash
gleam run -m thingfactory/cli -- run artifacts -i
```

## List Available Pipelines

```bash
gleam run -m thingfactory/cli -- list
```

Output:

```
Available Pipelines:

1  | basic                  - Basic sequential pipeline (3 steps)
2  | error                  - Error handling and propagation
3  | mock                   - Testing with mocks
4  | dependency             - Dependency injection pattern
5  | artifacts              - Artifact sharing between steps
6  | typescript             - TypeScript build pipeline
7  | rust                   - Rust library build pipeline
8  | fullstack              - Full-stack deployment pipeline
9  | gleam                  - Gleam project build pipeline
10 | go                     - Go library build pipeline
11 | custom                 - Custom runner factory pattern
12 | parallel               - Parallel build pipeline
13 | parallel_multi         - Parallel multi-target pipeline
14 | dogfood                - Build thingfactory itself (dogfood)
```

## Define Your Own Pipeline

Create a new Gleam module:

```gleam
import gleam/dynamic
import thingfactory/pipeline
import thingfactory/executor
import thingfactory/types

pub fn my_pipeline() -> pipeline.Pipeline(dynamic.Dynamic) {
  pipeline.new("my_pipeline", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    Ok(dynamic.string("data from API"))
  })
  |> pipeline.add_step("process", fn(_ctx, data) {
    // Transform the data
    Ok(data)
  })
  |> pipeline.add_step("publish", fn(_ctx, processed) {
    Ok(dynamic.string("published"))
  })
}

pub fn run() -> types.ExecutionResult(dynamic.Dynamic) {
  executor.execute(my_pipeline(), dynamic.nil(), types.default_config())
}
```

### Parallel Steps with Dependencies

```gleam
pub fn my_parallel_pipeline() -> pipeline.Pipeline(dynamic.Dynamic) {
  pipeline.new("parallel_demo", "1.0.0")
  |> pipeline.add_step_with_deps("clone", clone_fn, [])
  |> pipeline.add_step_with_deps("lint", lint_fn, ["clone"])
  |> pipeline.add_step_with_deps("test", test_fn, ["clone"])
  |> pipeline.add_step_with_deps("build", build_fn, ["lint", "test"])
}
```

Steps `lint` and `test` run in parallel since both only depend on `clone`.

### Steps with Loops

```gleam
// Retry up to 3 times on failure
|> pipeline.add_step_with_loop("flaky_step", step_fn, types.RetryOnFailure(max_attempts: 3))

// Repeat exactly 5 times
|> pipeline.add_step_with_loop("batch", batch_fn, types.FixedCount(count: 5))

// Keep trying until success (max 10 attempts)
|> pipeline.add_step_with_loop("poll", poll_fn, types.UntilSuccess(max_attempts: 10))
```

### Scheduled Pipelines

```gleam
pipeline.new("nightly_build", "1.0.0")
|> pipeline.with_schedule(types.Daily(2, 0))  // 2:00 AM UTC daily
|> pipeline.add_step("build", build_fn)
```

### Secrets

```gleam
pipeline.new("deploy", "1.0.0")
|> pipeline.add_secret("API_KEY", "sk_live_...")
|> pipeline.add_step("deploy", fn(ctx, _input) {
  // Access secret via ctx.secret_store
  Ok(dynamic.string("deployed"))
})
```

## Testing Pipelines

Use mock steps for unit testing:

```gleam
import thingfactory/test_helpers

pub fn my_pipeline_test() {
  let mocks = [
    test_helpers.mock_step_success("fetch", dynamic.string("mock_data")),
    test_helpers.mock_step_error("process", types.StepFailure(message: "test error")),
  ]

  let result = test_helpers.run_with_mocks(my_pipeline(), mocks, dynamic.nil())

  // Assert on result.result, result.trace, etc.
}
```

Run tests:

```bash
gleam test
```

## Next Steps

- [Running Pipelines](RUNNING_PIPELINES.md) -- CLI output modes, artifact extraction, Docker
- [Web GUI Guide](WEB_GUI_GUIDE.md) -- visualize and monitor pipelines
- [Hosting the Service](HOSTING_SERVICE.md) -- deploy the web service
- See `src/thingfactory/examples.gleam` for 26 working pipeline examples
