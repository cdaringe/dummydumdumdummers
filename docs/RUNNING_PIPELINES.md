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
gleam run -m thingfactory/cli -- run <module:function>
```

Pipelines can also be loaded directly from a `.gleam` source file:

```bash
gleam run -m thingfactory/cli -- run thingfactory@examples:basic_pipeline --isolator local
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam basic_pipeline --isolator local
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam typescript_build_pipeline --isolator local
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam parallel_build_pipeline --isolator local
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
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam basic_pipeline --isolator local -c
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
gleam run -m thingfactory/cli -- inspect -f src/thingfactory/examples.gleam artifact_sharing_pipeline
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
gleam run -m thingfactory/cli -- artifacts -f src/thingfactory/examples.gleam artifact_sharing_pipeline -o ./output
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
docker run --rm thingfactory run thingfactory@examples:basic_pipeline --isolator local
docker run --rm thingfactory run thingfactory@examples:typescript_build_pipeline --isolator local -c
docker run --rm thingfactory list
```

The Dockerfile uses a multi-stage build with `node:22-alpine`, compiling Gleam to JavaScript.

## Pipeline Resolution

The CLI resolves pipelines at runtime:

- `run <module:function>` loads a compiled function (for example, `thingfactory@examples:basic_pipeline`).
- `run -f <file.gleam> <function>` loads from a source file by function name.
- `list` prints valid usage patterns and examples.

## Exit Codes

- **0** -- pipeline completed successfully
- **non-zero** -- pipeline failed or CLI error
