# Thingfactory User Guide

A best-in-class task runner for CI/CD with type-safe pipeline definitions in [Gleam](https://gleam.run).

## Table of Contents

- [What is Thingfactory?](#what-is-thingfactory)
- [Guides](#guides)
- [Key Concepts](#key-concepts)
- [Architecture Overview](#architecture-overview)

## What is Thingfactory?

Thingfactory is a pipeline runner and orchestrator offering:

- **CLI** -- run pipelines locally, exactly as they run in production
- **Web GUI** -- visualize pipeline DAGs, view logs, download artifacts, track statistics
- **Pipeline Engine** -- type-safe definitions in Gleam with parallel execution, scheduling, secrets, and messaging

## Guides

| Guide | Description |
|---|---|
| [Getting Started](GETTING_STARTED.md) | Install, build, and run your first pipeline |
| [Running Pipelines](RUNNING_PIPELINES.md) | CLI usage, output modes, artifact extraction |
| [Web GUI Guide](WEB_GUI_GUIDE.md) | Dashboard, DAG visualization, Gantt timeline, statistics |
| [Hosting the Service](HOSTING_SERVICE.md) | Docker deployment, configuration, production setup |
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues and solutions |

## Key Concepts

### Pipelines

A pipeline is a named, versioned sequence of steps. Pipelines are defined in Gleam code and are:

- **Type-safe** -- the compiler checks step function signatures
- **Testable** -- swap in mock steps for unit testing
- **Observable** -- every execution produces traces with timing and status

### Steps

Steps are the unit of work. Each step receives a `Context` (artifact store, dependencies, secrets, messages) and the previous step's output, returning `Result(output, error)`.

Steps support:

- **Dependencies** -- run after specific other steps complete (enables parallelism)
- **Loops** -- `FixedCount`, `RetryOnFailure`, `UntilSuccess`
- **Context updates** -- publish messages or write artifacts for downstream steps

### Execution Modes

- **Sequential** -- steps run in order; failure stops the pipeline
- **Parallel (DAG)** -- steps with explicit dependencies run concurrently via topological sort

### Scheduling & Triggers

Pipelines can run on schedules (`Daily`, `Weekly`, `Monthly`, `Interval`, `Cron`) or be triggered by webhooks (GitHub, GitLab, custom).

### Secrets

Pipelines have a built-in secret store. Secrets are injected into the execution context and accessible by steps at runtime.

## Architecture Overview

```
src/thingfactory/
  pipeline.gleam           -- Pipeline builder API
  executor.gleam           -- Sequential execution engine
  parallel_executor.gleam  -- DAG-aware parallel executor
  types.gleam              -- Core types and error definitions
  cli.gleam                -- CLI with clip argument parser
  interactive_cli.gleam    -- Interactive REPL mode
  command_runner.gleam     -- Shell command execution via FFI
  kubernetes_runner.gleam  -- Kubernetes Job runner backend
  runner_host.gleam        -- Runner host coordination
  scheduler.gleam          -- Schedule matching logic
  webhook_trigger.gleam    -- External event triggers
  secret_manager.gleam     -- Secrets CRUD and validation
  message_store.gleam      -- Pub-sub messaging between steps
  artifact_store.gleam     -- Inter-step data sharing
  test_helpers.gleam       -- Mock/testing utilities
  examples.gleam           -- 26 example pipelines

web/                       -- Next.js 15 web GUI
  app/                     -- Pages (Dashboard, Pipelines, Runs, Statistics)
  components/              -- React Flow DAG, Gantt timeline, log viewer
  db/                      -- SQLite with Kysely, migrations, seed data
```
