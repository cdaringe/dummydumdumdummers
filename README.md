# Thingfactory

A best-in-class task runner for CI/CD with type-safe pipeline definitions in [Gleam](https://gleam.run).

**CLI** | **Web GUI** | **Pipeline Runner & Orchestrator**

## What It Does

- Define pipelines in Gleam with compile-time type safety
- Run pipelines locally via CLI, exactly as they run in production
- Visualize pipeline DAGs, view logs, download artifacts, and track statistics in the web GUI
- Execute steps sequentially or in parallel (DAG-aware)
- Schedule pipelines, trigger via webhooks, manage secrets
- Test pipelines with mock steps

## Quick Start

### Install

```bash
git clone <repo-url> thingfactory
cd thingfactory
gleam build
```

### Run a Pipeline

```bash
gleam run -m thingfactory/cli -- list              # see available pipelines
gleam run -m thingfactory/cli -- run basic          # run one
gleam run -m thingfactory/cli -- run parallel -c    # compact output
gleam run -m thingfactory/cli -- run artifacts -i   # interactive mode
```

### Define a Pipeline

```gleam
import gleam/dynamic
import thingfactory/pipeline
import thingfactory/executor
import thingfactory/types

pub fn my_pipeline() {
  pipeline.new("my_pipeline", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    Ok(dynamic.string("data"))
  })
  |> pipeline.add_step("transform", fn(_ctx, data) {
    Ok(data)
  })
}

// Run it
let result = executor.execute(my_pipeline(), dynamic.nil(), types.default_config())
```

### Parallel Steps

```gleam
pipeline.new("parallel_demo", "1.0.0")
|> pipeline.add_step_with_deps("clone", clone_fn, [])
|> pipeline.add_step_with_deps("lint", lint_fn, ["clone"])
|> pipeline.add_step_with_deps("test", test_fn, ["clone"])     // parallel with lint
|> pipeline.add_step_with_deps("build", build_fn, ["lint", "test"])
```

### Test with Mocks

```gleam
let mocks = [
  test_helpers.mock_step_success("fetch", dynamic.string("test_data")),
]
let result = test_helpers.run_with_mocks(my_pipeline(), mocks, dynamic.nil())
```

### Run with Docker

```bash
docker build -t thingfactory .
docker run --rm thingfactory run basic
```

## Features

- **Sequential & parallel execution** -- DAG-aware topological sort for parallel steps
- **Loops** -- `FixedCount`, `RetryOnFailure`, `UntilSuccess`
- **Scheduling** -- `Daily`, `Weekly`, `Monthly`, `Interval`, `Cron`
- **Webhook triggers** -- GitHub, GitLab, custom events
- **Secrets management** -- built-in secret store with access control
- **Inter-step messaging** -- pub-sub message bus between steps
- **Artifact sharing** -- read/write artifacts through the execution context
- **CLI** -- compact, verbose, and interactive output modes with artifact extraction
- **Web GUI** -- Next.js 15 + React Flow with DAG visualization, Gantt timeline, statistics dashboard
- **Kubernetes runner** -- execute pipeline steps as K8s Jobs
- **Docker isolation** -- pipeline steps run in containers by default
- **Dogfooding** -- thingfactory builds itself with its own pipeline engine

## Documentation

| Guide | Description |
|---|---|
| [User Guide](docs/USER_GUIDE.md) | Overview and architecture |
| [Getting Started](docs/GETTING_STARTED.md) | Install and run your first pipeline |
| [Running Pipelines](docs/RUNNING_PIPELINES.md) | CLI output modes, artifact extraction, Docker |
| [Web GUI Guide](docs/WEB_GUI_GUIDE.md) | Dashboard, DAG visualization, Gantt timeline, stats |
| [Hosting the Service](docs/HOSTING_SERVICE.md) | Docker deployment, configuration, production |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and solutions |

## Examples

26 example pipelines in `src/thingfactory/examples.gleam`:

- Basic sequential, error handling, mock testing, dependency injection
- Real build pipelines: TypeScript, Rust, Go, Gleam, full-stack
- Parallel DAG and multi-target parallel builds
- Loops: retry, fixed count, until success
- Messaging: pub-sub, multi-topic coordination, event-driven
- Scheduling: daily, weekly, monthly, interval, cron
- Kubernetes runner, custom runner factory, dogfooding

```bash
gleam run -m thingfactory/cli -- list   # see all 14 runnable pipelines
gleam test                               # run all tests including examples
```

## Development

```bash
gleam build                  # compile
gleam test                   # run tests
gleam format                 # format code
cd web && npm run dev        # start web GUI
cd web && npx playwright test  # run E2E tests
```

## License

Apache License 2.0
