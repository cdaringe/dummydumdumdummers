# Running Pipelines

How to run pipelines with the CLI, including output modes, artifact extraction, and Docker.

## Table of Contents

- [CLI Overview](#cli-overview)
- [Running a Pipeline](#running-a-pipeline)
- [Output Modes](#output-modes)
- [Interactive Mode](#interactive-mode)
- [Artifact Extraction](#artifact-extraction)
- [Running with Docker](#running-with-docker)
- [Pipeline Resolution](#pipeline-resolution)
- [Exit Codes](#exit-codes)

## CLI Overview

The CLI uses the [clip](https://hexdocs.pm/clip/) library for argument parsing with auto-generated help.

```
thingfactory <command>

Commands:
  run        Run a pipeline (compact or verbose progress)
  inspect    Run then enter interactive result inspector
  results    Run and print detailed step results
  artifacts  Run and extract artifacts to disk
  list       Show command usage patterns
```

## Running a Pipeline

```bash
gleam run -m thingfactory/cli -- run <pipeline-name>
```

Pipelines can be referenced by name or number:

```bash
gleam run -m thingfactory/cli -- run basic       # by name
gleam run -m thingfactory/cli -- run 1           # by number
gleam run -m thingfactory/cli -- run typescript  # real build pipeline
gleam run -m thingfactory/cli -- run parallel    # parallel DAG pipeline
```

## Output Modes

### Verbose (default)

Shows step start/finish with status and timing:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pipeline: basic_pipeline
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>> [1/3] fetch
   OK (2ms)

>> [2/3] transform
   OK (1ms)

>> [3/3] output
   OK (0ms)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Result: SUCCESS | 3 steps | 3ms
```

### Compact (`-c` / `--compact`)

Shows step N/M progress with minimal output:

```bash
gleam run -m thingfactory/cli -- run basic -c
```

```
  [1/3] fetch ✓ 2ms
  [2/3] transform ✓ 1ms
  [3/3] output ✓ 0ms
── ✓ basic (3 steps, 3ms)
```

### Interactive (`inspect`)

Runs the pipeline then drops into a REPL for exploring results:

```bash
gleam run -m thingfactory/cli -- inspect artifacts
```

Available interactive commands:

| Command | Description |
|---|---|
| `help` | Show available commands |
| `list` | List all steps with status |
| `step <N>` | Show detail for step by index (0-based) |
| `step <name>` | Show detail for step by name |
| `stats` | Show pipeline execution statistics |
| `artifacts` | List produced artifacts and values |
| `exit` | Exit interactive mode |

## Artifact Extraction

Extract artifacts to disk after execution using `artifacts -o/--output-dir`:

```bash
gleam run -m thingfactory/cli -- artifacts artifacts -o ./output
```

Each artifact key becomes a file in the output directory:

```
Extracting 2 artifact(s) to ./output/
  ✓ ./output/config
  ✓ ./output/build_result
```

## Running with Docker

Build the Docker image:

```bash
docker build -t thingfactory .
```

Run a pipeline in a container:

```bash
docker run --rm thingfactory run basic
docker run --rm thingfactory run typescript -c
docker run --rm thingfactory list
```

The Dockerfile uses a multi-stage build with `node:22-alpine`, compiling Gleam to JavaScript.

## Pipeline Resolution

The CLI resolves pipeline names case-insensitively. Each pipeline has a number and one or more name aliases:

| # | Names | Description |
|---|---|---|
| 1 | `basic` | Basic sequential pipeline |
| 2 | `error` | Error handling demo |
| 3 | `mock` | Mock testing patterns |
| 4 | `dependency` | Dependency injection |
| 5 | `artifacts` | Artifact sharing |
| 6 | `typescript` | TypeScript build |
| 7 | `rust` | Rust library build |
| 8 | `fullstack` | Full-stack deployment |
| 9 | `gleam` | Gleam project build |
| 10 | `go` | Go library build |
| 11 | `custom` | Custom runner factory |
| 12 | `parallel` | Parallel DAG build |
| 13 | `parallel_multi` | Multi-target parallel |
| 14 | `dogfood` | Build thingfactory itself |

## Exit Codes

- **0** -- pipeline completed successfully
- **non-zero** -- pipeline failed or CLI error
