# Troubleshooting

Common issues and solutions when using Thingfactory.

## Table of Contents

- [Build Issues](#build-issues)
- [CLI Issues](#cli-issues)
- [Web GUI Issues](#web-gui-issues)
- [Pipeline Execution Issues](#pipeline-execution-issues)
- [Docker Issues](#docker-issues)
- [Database Issues](#database-issues)
- [Getting Help](#getting-help)

## Build Issues

### `gleam build --warnings-as-errors` fails with version error

**Problem**: Gleam version mismatch.

**Solution**: Thingfactory requires Gleam >= 1.13.0. Check your version:

```bash
gleam --version
```

Update Gleam: https://gleam.run/getting-started/installing/

### `npm install` fails in web/

**Problem**: Node.js version too old.

**Solution**: Requires Node.js >= 22. Check with `node --version`.

### Missing `better-sqlite3` native module

**Problem**: `better-sqlite3` requires compilation on your platform.

**Solution**:

```bash
cd web
npm rebuild better-sqlite3
```

On macOS, you may need Xcode command line tools: `xcode-select --install`.

## CLI Issues

### "Unknown pipeline" error

**Problem**: Pipeline name not recognized.

**Solution**: Use `gleam run -m thingfactory/cli -- list` to see available pipelines. Pipeline names are case-insensitive. You can also use numbers (e.g., `1` for `basic`).

### No output in compact mode

**Problem**: Compact mode (`-c`) only shows output on step completion.

**Solution**: This is expected. Compact mode shows `[N/M] step_name status duration` per step, with a summary at the end. Use verbose mode (default) for more detail.

### Interactive mode hangs

**Problem**: Interactive mode (`-i`) waiting for input.

**Solution**: Type `help` to see commands, `exit` to quit. Interactive mode is a REPL that runs after pipeline execution completes.

## Web GUI Issues

### GUI shows no pipelines

**Problem**: Database is empty or not seeded.

**Solution**: Seed the database:

```bash
cd web
npx tsx db/seed.ts
```

### Blank page or build errors

**Problem**: Dependencies not installed or build stale.

**Solution**:

```bash
cd web
rm -rf .next node_modules
npm install
npm run dev
```

### Log streaming not working

**Problem**: SSE (Server-Sent Events) connection failing.

**Solution**: Ensure no proxy is buffering responses. If behind nginx, add:

```nginx
proxy_buffering off;
proxy_cache off;
```

## Pipeline Execution Issues

### Step timeout

**Problem**: Step exceeds its configured timeout.

**Solution**: Increase the timeout:

```gleam
pipeline.new("my_pipeline", "1.0.0")
|> pipeline.with_timeout(300_000)  // 5 minutes default per step
|> pipeline.add_step_with_timeout("slow_step", step_fn, 600_000)  // 10 min for this step
```

### Dependency not found error

**Problem**: Step tries to read a dependency that wasn't injected.

**Solution**: Provide the dependency in the execution config:

```gleam
let config = types.ExecutionConfig(
  default_step_timeout_ms: 30_000,
  dependency_bindings: [
    types.Binding(name: "my_dep", value: dynamic.string("value")),
  ],
)
executor.execute(pipeline, dynamic.nil(), config)
```

### Parallel steps run sequentially

**Problem**: Steps expected to run in parallel are running one at a time.

**Solution**: Ensure you're using `parallel_executor.execute_parallel()` (not `executor.execute()`) and that steps have explicit dependencies via `add_step_with_deps`:

```gleam
// These two steps will run in parallel (both depend only on "setup")
|> pipeline.add_step_with_deps("lint", lint_fn, ["setup"])
|> pipeline.add_step_with_deps("test", test_fn, ["setup"])
```

### Messages not received by subscriber step

**Problem**: Step can't read messages published by earlier steps.

**Solution**: The publishing step must use `add_step_with_ctx` and return the updated context:

```gleam
|> pipeline.add_step_with_ctx("publisher", fn(ctx, _input) {
  let updated_ctx = types.publish_message(ctx, "topic", dynamic.string("msg"))
  Ok(#(dynamic.string("done"), updated_ctx))
})
```

## Docker Issues

### Container can't run pipeline steps in Docker

**Problem**: Pipeline isolation requires Docker-in-Docker.

**Solution**: Mount the Docker socket:

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock thingfactory-web
```

### Image build fails with Gleam download error

**Problem**: Network issue downloading Gleam in Docker.

**Solution**: The Dockerfile installs Gleam via npm (`npm install -g gleam@1.13.0`). Check your network connectivity and npm registry access.

## Database Issues

### Database locked errors

**Problem**: Multiple processes writing to SQLite simultaneously.

**Solution**: SQLite handles concurrent reads but serializes writes. Ensure only one server process accesses the database file. WAL mode is enabled by default for better concurrency.

### Migration failures

**Problem**: Schema out of date.

**Solution**: Migrations run automatically. If they fail, check `web/db/migrations/` for the latest migration files and ensure the database file is writable.

## Getting Help

- Check the [User Guide](USER_GUIDE.md) for an overview of all features
- See `src/thingfactory/examples.gleam` for 26 working pipeline examples
- Run `gleam run -m thingfactory/cli -- run <pipeline> -i` to interactively explore execution results
- File issues at the project repository
