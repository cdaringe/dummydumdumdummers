/// Command-line interface for running pipelines
///
/// This module provides a CLI for executing pipelines, enabling
/// Thingfactory to run in Docker containers and CI/CD systems.
/// Uses the clip library for proper argument parsing with auto-generated help.
import argv
import clip
import clip/arg
import clip/flag
import clip/help
import clip/opt
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import thingfactory/examples
import thingfactory/executor
import thingfactory/interactive_cli
import thingfactory/parallel_executor
import thingfactory/types.{type ExecutionResult, type StepEvent}

/// CLI command variants
pub type CliCommand {
  Run(
    pipeline: String,
    compact: Bool,
    interactive: Bool,
    output_dir: Result(String, Nil),
  )
  ListPipelines
}

/// Output verbosity level for CLI
pub type OutputMode {
  Compact
  Verbose
  Interactive
}

/// Build the "run" subcommand parser
fn run_command() -> clip.Command(CliCommand) {
  clip.command({
    use pipeline <- clip.parameter
    use compact <- clip.parameter
    use interactive <- clip.parameter
    use output_dir <- clip.parameter
    Run(
      pipeline: pipeline,
      compact: compact,
      interactive: interactive,
      output_dir: output_dir,
    )
  })
  |> clip.arg(
    arg.new("pipeline")
    |> arg.help("Pipeline name or number (e.g. typescript, 1, parallel)"),
  )
  |> clip.flag(
    flag.new("compact")
    |> flag.short("c")
    |> flag.help("Compact output (step N/M progress)"),
  )
  |> clip.flag(
    flag.new("interactive")
    |> flag.short("i")
    |> flag.help("Interactive mode with drilldown support"),
  )
  |> clip.opt(
    opt.new("output-dir")
    |> opt.short("o")
    |> opt.help("Extract artifacts to this directory after execution")
    |> opt.optional(),
  )
  |> clip.help(help.simple("thingfactory run", "Run a pipeline by name"))
}

/// Build the "list" subcommand parser
fn list_command() -> clip.Command(CliCommand) {
  clip.return(ListPipelines)
}

/// Build the top-level CLI parser with subcommands
fn cli() -> clip.Command(CliCommand) {
  clip.subcommands([#("run", run_command()), #("list", list_command())])
  |> clip.help(help.simple(
    "thingfactory",
    "A best-in-class task runner for CI/CD pipelines",
  ))
}

/// Resolve output mode from parsed flags
fn resolve_mode(compact: Bool, interactive: Bool) -> OutputMode {
  case compact, interactive {
    True, _ -> Compact
    _, True -> Interactive
    _, _ -> Verbose
  }
}

/// Execute a pipeline by name, returning its ExecutionResult
pub fn execute_pipeline(
  pipeline_name: String,
  mode: OutputMode,
) -> Result(ExecutionResult(Dynamic), String) {
  case string.lowercase(pipeline_name) {
    "1" | "basic" -> Ok(exec_basic(mode))
    "2" | "error" -> Ok(exec_error_handling(mode))
    "3" | "mock" -> Ok(exec_mockable(mode))
    "4" | "dependency" -> Ok(exec_dependency_injection(mode))
    "5" | "artifacts" -> Ok(exec_artifact_sharing(mode))
    "6" | "typescript" -> Ok(exec_typescript_build(mode))
    "7" | "rust" -> Ok(exec_rust_build(mode))
    "8" | "fullstack" -> Ok(exec_fullstack(mode))
    "9" | "gleam" -> Ok(exec_gleam_build(mode))
    "10" | "go" -> Ok(exec_go_build(mode))
    "11" | "custom" -> Ok(exec_custom_runner(mode))
    "12" | "parallel" -> Ok(exec_parallel_build(mode))
    "13" | "parallel_multi" -> Ok(exec_parallel_multi_target(mode))
    "14" | "dogfood" -> Ok(exec_dogfood(mode))
    _ ->
      Error(
        "Unknown pipeline: "
        <> pipeline_name
        <> ". Use 'thingfactory list' to see available pipelines.",
      )
  }
}

/// Run a pipeline by name with specified output mode (legacy API)
pub fn run_pipeline(
  pipeline_name: String,
  mode: OutputMode,
) -> Result(String, String) {
  case execute_pipeline(pipeline_name, mode) {
    Ok(result) -> format_summary(pipeline_name, result, mode)
    Error(err) -> Error(err)
  }
}

// ---------------------------------------------------------------------------
// Progress callbacks for real-time output
// ---------------------------------------------------------------------------

/// Select the progress callback function based on output mode
fn progress_fn(mode: OutputMode) -> fn(StepEvent) -> Nil {
  case mode {
    Compact -> compact_progress
    Verbose | Interactive -> verbose_progress
  }
}

/// Compact progress: prints step N/M with status on completion
fn compact_progress(event: StepEvent) -> Nil {
  case event {
    types.StepStarting(_, _, _) -> Nil
    types.StepFinished(name, index, total, status, duration_ms) -> {
      let icon = case status {
        types.StepOk -> "✓"
        types.StepFailed(_) -> "✗"
        types.StepSkipped -> "-"
      }
      io.println(
        "  ["
        <> int.to_string(index)
        <> "/"
        <> int.to_string(total)
        <> "] "
        <> name
        <> " "
        <> icon
        <> " "
        <> format_duration_ms(duration_ms),
      )
    }
  }
}

/// Verbose progress: prints step start and detailed completion info
fn verbose_progress(event: StepEvent) -> Nil {
  case event {
    types.StepStarting(name, index, total) ->
      io.println(
        ">> ["
        <> int.to_string(index)
        <> "/"
        <> int.to_string(total)
        <> "] "
        <> name,
      )
    types.StepFinished(_, _, _, status, duration_ms) -> {
      let status_str = case status {
        types.StepOk -> "✓ OK"
        types.StepFailed(_) -> "✗ FAILED"
        types.StepSkipped -> "- SKIPPED"
      }
      io.println(
        "   " <> status_str <> " (" <> format_duration_ms(duration_ms) <> ")",
      )
      io.println("")
    }
  }
}

/// Print pipeline header before execution (verbose/interactive only)
fn print_header(name: String, mode: OutputMode) -> Nil {
  case mode {
    Compact -> Nil
    Verbose | Interactive -> {
      io.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      io.println("Pipeline: " <> name)
      io.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      io.println("")
      Nil
    }
  }
}

/// Format the summary line after execution completes
fn format_summary(
  name: String,
  result: ExecutionResult(Dynamic),
  mode: OutputMode,
) -> Result(String, String) {
  let total_duration =
    list.fold(result.trace, 0, fn(acc, trace) { acc + trace.duration_ms })
  let step_count = list.length(result.trace)

  case mode {
    Compact -> {
      let status = case result.result {
        Ok(_) -> "✓"
        Error(_) -> "✗"
      }
      Ok(
        "── "
        <> status
        <> " "
        <> name
        <> " ("
        <> int.to_string(step_count)
        <> " steps, "
        <> format_duration_ms(total_duration)
        <> ")",
      )
    }
    Verbose -> {
      let status = case result.result {
        Ok(_) -> "SUCCESS"
        Error(_) -> "FAILED"
      }
      Ok(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        <> "Result: "
        <> status
        <> " | "
        <> int.to_string(step_count)
        <> " steps | "
        <> format_duration_ms(total_duration),
      )
    }
    Interactive -> {
      let status = case result.result {
        Ok(_) -> "SUCCESS"
        Error(_) -> "FAILED"
      }
      io.println(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        <> "Result: "
        <> status
        <> " | "
        <> int.to_string(step_count)
        <> " steps | "
        <> format_duration_ms(total_duration),
      )
      let state =
        interactive_cli.InteractiveState(
          pipeline_name: name,
          result: result,
          steps: result.trace,
        )
      interactive_cli.show_welcome(state)
      run_interactive_loop(state)
      Ok("")
    }
  }
}

// ---------------------------------------------------------------------------
// Pipeline executors (sequential)
// ---------------------------------------------------------------------------

fn exec_basic(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("basic_pipeline", mode)
  executor.execute_with_progress(
    examples.basic_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_error_handling(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("error_handling_pipeline", mode)
  executor.execute_with_progress(
    examples.error_handling_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_mockable(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("mockable_pipeline", mode)
  executor.execute_with_progress(
    examples.mockable_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_dependency_injection(mode: OutputMode) -> ExecutionResult(Dynamic) {
  let bindings = [
    types.Binding(
      name: "config_url",
      value: dynamic.string("https://config.example.com"),
    ),
    types.Binding(name: "api_key", value: dynamic.string("secret_key_123")),
  ]
  let config =
    types.ExecutionConfig(
      default_step_timeout_ms: 30_000,
      dependency_bindings: bindings,
    )
  print_header("dependency_injection_pipeline", mode)
  executor.execute_with_progress(
    examples.dependency_injection_pipeline(),
    dynamic.nil(),
    config,
    progress_fn(mode),
  )
}

fn exec_artifact_sharing(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("artifact_sharing_pipeline", mode)
  executor.execute_with_progress(
    examples.artifact_sharing_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_typescript_build(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("typescript_build_pipeline", mode)
  executor.execute_with_progress(
    examples.typescript_build_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_rust_build(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("rust_build_pipeline", mode)
  executor.execute_with_progress(
    examples.rust_build_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_fullstack(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("full_stack_pipeline", mode)
  executor.execute_with_progress(
    examples.full_stack_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_gleam_build(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("gleam_build_pipeline", mode)
  executor.execute_with_progress(
    examples.gleam_build_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_go_build(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("go_build_pipeline", mode)
  executor.execute_with_progress(
    examples.go_build_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_custom_runner(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("custom_runner_pipeline", mode)
  executor.execute_with_progress(
    examples.custom_runner_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

// ---------------------------------------------------------------------------
// Pipeline executors (parallel)
// ---------------------------------------------------------------------------

fn exec_parallel_build(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("parallel_build_pipeline", mode)
  parallel_executor.execute_parallel_with_progress(
    examples.parallel_build_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_parallel_multi_target(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("parallel_multi_target_pipeline", mode)
  parallel_executor.execute_parallel_with_progress(
    examples.parallel_multi_target_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

fn exec_dogfood(mode: OutputMode) -> ExecutionResult(Dynamic) {
  print_header("dogfood_pipeline", mode)
  parallel_executor.execute_parallel_with_progress(
    examples.dogfood_pipeline(),
    dynamic.nil(),
    types.default_config(),
    progress_fn(mode),
  )
}

// ---------------------------------------------------------------------------
// Artifact extraction
// ---------------------------------------------------------------------------

/// Extract artifacts from an execution result to a directory on disk.
/// Each artifact key becomes a file in the output directory.
fn extract_artifacts(
  result: ExecutionResult(Dynamic),
  output_dir: String,
) -> Result(Int, String) {
  let keys = dict.keys(result.artifacts)
  let count = list.length(keys)

  case count {
    0 -> {
      io.println("No artifacts to extract.")
      Ok(0)
    }
    _ -> {
      io.println(
        "Extracting "
        <> int.to_string(count)
        <> " artifact(s) to "
        <> output_dir
        <> "/",
      )
      list.each(keys, fn(key) {
        case dict.get(result.artifacts, key) {
          Ok(value) -> {
            let content = string.inspect(value)
            case write_file(output_dir, key, content) {
              Ok(path) -> io.println("  ✓ " <> path)
              Error(err) -> io.println("  ✗ " <> key <> ": " <> err)
            }
          }
          Error(Nil) -> Nil
        }
      })
      Ok(count)
    }
  }
}

// ---------------------------------------------------------------------------
// Output formatting helpers
// ---------------------------------------------------------------------------

fn format_duration_ms(ms: Int) -> String {
  case ms {
    n if n < 1000 -> int.to_string(n) <> "ms"
    n -> {
      let seconds = int.to_float(n) /. 1000.0
      float.to_string(seconds) <> "s"
    }
  }
}

fn list_pipelines() -> Result(String, String) {
  let pipelines = [
    "1  | basic                  - Basic sequential pipeline (3 steps)",
    "2  | error                  - Error handling and propagation",
    "3  | mock                   - Testing with mocks",
    "4  | dependency             - Dependency injection pattern",
    "5  | artifacts              - Artifact sharing between steps",
    "6  | typescript             - TypeScript build pipeline",
    "7  | rust                   - Rust library build pipeline",
    "8  | fullstack              - Full-stack deployment pipeline",
    "9  | gleam                  - Gleam project build pipeline",
    "10 | go                     - Go library build pipeline",
    "11 | custom                 - Custom runner factory pattern",
    "12 | parallel               - Parallel build pipeline",
    "13 | parallel_multi         - Parallel multi-target pipeline",
    "14 | dogfood                - Build thingfactory itself (dogfood)",
  ]

  let output = ["Available Pipelines:", "", ..pipelines]

  Ok(string.join(output, "\n"))
}

/// Main entry point for CLI
pub fn main() {
  let result = cli() |> clip.run(argv.load().arguments)

  case result {
    Ok(Run(pipeline, compact, interactive, output_dir)) -> {
      let mode = resolve_mode(compact, interactive)
      case execute_pipeline(pipeline, mode) {
        Ok(exec_result) -> {
          case format_summary(pipeline, exec_result, mode) {
            Ok(output) -> {
              case output {
                "" -> Nil
                _ -> io.println(output)
              }
            }
            Error(err) -> io.println("Error: " <> err)
          }
          // Extract artifacts if --output-dir was provided
          case output_dir {
            Ok(dir) -> {
              let _ = extract_artifacts(exec_result, dir)
              Nil
            }
            Error(Nil) -> Nil
          }
        }
        Error(err) -> io.println("Error: " <> err)
      }
    }
    Ok(ListPipelines) -> {
      case list_pipelines() {
        Ok(output) -> io.println(output)
        Error(err) -> io.println("Error: " <> err)
      }
    }
    Error(err) -> io.println(err)
  }
}

fn run_interactive_loop(state: interactive_cli.InteractiveState) -> Nil {
  interactive_cli.show_prompt()
  case read_line() {
    Ok(input) -> {
      let trimmed = string.trim(input)
      case trimmed {
        "exit" | "quit" | "q" -> Nil
        _ -> {
          let #(_new_state, output) =
            interactive_cli.execute_command(state, trimmed)
          case output {
            "" -> Nil
            _ -> io.println(output)
          }
          run_interactive_loop(state)
        }
      }
    }
    Error(_) -> {
      io.println("Error reading input")
      Nil
    }
  }
}

@external(erlang, "thingfactory_erlang_cli", "read_line_sync")
@external(javascript, "./cli_ffi.mjs", "read_line_sync")
fn read_line() -> Result(String, Nil)

@external(erlang, "thingfactory_erlang_cli", "write_file")
@external(javascript, "./cli_ffi.mjs", "write_file")
fn write_file(
  dir: String,
  filename: String,
  content: String,
) -> Result(String, String)
