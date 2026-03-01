/// Command-line interface for running pipelines
///
/// This module provides a CLI for executing pipelines with a runtime
/// pipeline reference (`module:function`) so the CLI artifact does not
/// embed any example pipelines.
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
import thingfactory/command_runner
import thingfactory/executor
import thingfactory/interactive_cli
import thingfactory/parallel_executor
import thingfactory/pipeline
import thingfactory/types.{type ExecutionResult, type StepEvent}

/// CLI command variants
pub type CliCommand {
  Run(
    pipeline_selector: String,
    source_file: Result(String, Nil),
    compact: Bool,
    interactive: Bool,
    output_dir: Result(String, Nil),
    isolator: Result(String, Nil),
    docker_image: Result(String, Nil),
  )
  Inspect(pipeline_selector: String, source_file: Result(String, Nil))
  Results(pipeline_selector: String, source_file: Result(String, Nil))
  Artifacts(
    pipeline_selector: String,
    source_file: Result(String, Nil),
    output_dir: String,
  )
  ListPipelines
}

/// Output verbosity level for CLI
pub type OutputMode {
  Compact
  Verbose
  Interactive
}

pub type IsolationMode {
  LocalIsolation
  DockerIsolation(image: String)
}

/// Build the "run" subcommand parser
fn run_command() -> clip.Command(CliCommand) {
  clip.command({
    use source_file <- clip.parameter
    use compact <- clip.parameter
    use interactive <- clip.parameter
    use output_dir <- clip.parameter
    use isolator <- clip.parameter
    use docker_image <- clip.parameter
    use pipeline_selector <- clip.parameter
    Run(
      pipeline_selector: pipeline_selector,
      source_file: source_file,
      compact: compact,
      interactive: interactive,
      output_dir: output_dir,
      isolator: isolator,
      docker_image: docker_image,
    )
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help(
      "Gleam file to load pipeline from at runtime (no pre-compilation needed)",
    )
    |> opt.optional(),
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
  |> clip.opt(
    opt.new("isolator")
    |> opt.help("Pipeline isolation backend: docker (default) or local")
    |> opt.optional(),
  )
  |> clip.opt(
    opt.new("docker-image")
    |> opt.help("Docker image to use when --isolator docker is selected")
    |> opt.optional(),
  )
  |> clip.arg(
    arg.new("pipeline")
    |> arg.help(
      "Pipeline selector: module:function, or function name when -f/--file is used",
    ),
  )
  |> clip.help(help.simple(
    "thingfactory run",
    "Run a pipeline by module:function",
  ))
}

/// Build the "list" subcommand parser
fn list_command() -> clip.Command(CliCommand) {
  clip.return(ListPipelines)
}

/// Build the "inspect" subcommand parser
fn inspect_command() -> clip.Command(CliCommand) {
  clip.command({
    use source_file <- clip.parameter
    use pipeline_selector <- clip.parameter
    Inspect(pipeline_selector: pipeline_selector, source_file: source_file)
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help("Gleam file to load pipeline from at runtime")
    |> opt.optional(),
  )
  |> clip.arg(
    arg.new("pipeline")
    |> arg.help(
      "Pipeline selector: module:function, or function name when -f/--file is used",
    ),
  )
  |> clip.help(help.simple(
    "thingfactory inspect",
    "Run a pipeline, then enter an interactive result inspector",
  ))
}

/// Build the "results" subcommand parser
fn results_command() -> clip.Command(CliCommand) {
  clip.command({
    use source_file <- clip.parameter
    use pipeline_selector <- clip.parameter
    Results(pipeline_selector: pipeline_selector, source_file: source_file)
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help("Gleam file to load pipeline from at runtime")
    |> opt.optional(),
  )
  |> clip.arg(
    arg.new("pipeline")
    |> arg.help(
      "Pipeline selector: module:function, or function name when -f/--file is used",
    ),
  )
  |> clip.help(help.simple(
    "thingfactory results",
    "Run a pipeline and print a detailed result report",
  ))
}

/// Build the "artifacts" subcommand parser
fn artifacts_command() -> clip.Command(CliCommand) {
  clip.command({
    use source_file <- clip.parameter
    use output_dir <- clip.parameter
    use pipeline_selector <- clip.parameter
    Artifacts(
      pipeline_selector: pipeline_selector,
      source_file: source_file,
      output_dir: output_dir,
    )
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help("Gleam file to load pipeline from at runtime")
    |> opt.optional(),
  )
  |> clip.opt(
    opt.new("output-dir")
    |> opt.short("o")
    |> opt.help("Directory to write extracted artifacts to"),
  )
  |> clip.arg(
    arg.new("pipeline")
    |> arg.help(
      "Pipeline selector: module:function, or function name when -f/--file is used",
    ),
  )
  |> clip.help(help.simple(
    "thingfactory artifacts",
    "Run a pipeline and extract artifacts to disk",
  ))
}

/// Build the top-level CLI parser with subcommands
fn cli() -> clip.Command(CliCommand) {
  clip.subcommands([
    #("run", run_command()),
    #("list", list_command()),
    #("inspect", inspect_command()),
    #("results", results_command()),
    #("artifacts", artifacts_command()),
  ])
  |> clip.help(help.simple(
    "thingfactory",
    "A best-in-class task runner for CI/CD pipelines",
  ))
}

/// Parse CLI args into a command.
pub fn parse_args(args: List(String)) -> Result(CliCommand, String) {
  cli() |> clip.run(args)
}

/// Resolve output mode from parsed flags
fn resolve_mode(compact: Bool, interactive: Bool) -> OutputMode {
  case compact, interactive {
    True, _ -> Compact
    _, True -> Interactive
    _, _ -> Verbose
  }
}

/// Execute a pipeline by runtime reference, returning its ExecutionResult
pub fn execute_pipeline(
  pipeline_ref: String,
  mode: OutputMode,
) -> Result(ExecutionResult(Dynamic), String) {
  case parse_pipeline_ref(pipeline_ref) {
    Ok(#(module_name, function_name)) -> {
      case load_pipeline(module_name, function_name) {
        Ok(loaded_pipeline) -> {
          print_header(pipeline_ref, mode)
          Ok(execute_loaded_pipeline(loaded_pipeline, mode))
        }
        Error(err) -> Error(err)
      }
    }
    Error(err) -> Error(err)
  }
}

/// Execute a pipeline loaded from a Gleam source file at runtime.
pub fn execute_pipeline_from_file(
  file_path: String,
  function_name: String,
  mode: OutputMode,
) -> Result(ExecutionResult(Dynamic), String) {
  case string.trim(function_name) {
    "" -> Error("Pipeline function name cannot be empty when using --file")
    trimmed_name -> {
      case load_pipeline_from_file(file_path, trimmed_name) {
        Ok(loaded_pipeline) -> {
          let pipeline_display = file_path <> ":" <> trimmed_name
          print_header(pipeline_display, mode)
          Ok(execute_loaded_pipeline(loaded_pipeline, mode))
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Run a pipeline by runtime reference with specified output mode
pub fn run_pipeline(
  pipeline_ref: String,
  mode: OutputMode,
) -> Result(String, String) {
  case execute_pipeline(pipeline_ref, mode) {
    Ok(result) -> format_summary(pipeline_ref, result, mode)
    Error(err) -> Error(err)
  }
}

fn parse_pipeline_ref(pipeline_ref: String) -> Result(#(String, String), String) {
  let trimmed = string.trim(pipeline_ref)

  case string.split(trimmed, ":") {
    [module_name, function_name] if module_name != "" && function_name != "" ->
      Ok(#(module_name, function_name))
    _ ->
      Error(
        "Invalid pipeline reference: "
        <> pipeline_ref
        <> ". Expected format module:function (e.g. thingfactory@examples:basic_pipeline).",
      )
  }
}

fn execute_loaded_pipeline(
  loaded_pipeline: pipeline.Pipeline(Dynamic),
  mode: OutputMode,
) -> ExecutionResult(Dynamic) {
  case pipeline_has_dependencies(loaded_pipeline) {
    True ->
      parallel_executor.execute_parallel_with_progress(
        loaded_pipeline,
        dynamic.nil(),
        types.default_config(),
        progress_fn(mode),
      )
    False ->
      executor.execute_with_progress(
        loaded_pipeline,
        dynamic.nil(),
        types.default_config(),
        progress_fn(mode),
      )
  }
}

fn pipeline_has_dependencies(p: pipeline.Pipeline(Dynamic)) -> Bool {
  list.any(pipeline.steps(p), fn(step) {
    let pipeline.Step(_, _, _, depends_on, _) = step
    case depends_on {
      [] -> False
      _ -> True
    }
  })
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
    types.StepFinished(name, index, total, status, duration_ms, _output) -> {
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
    types.StepFinished(_, _, _, status, duration_ms, output) -> {
      let status_str = case status {
        types.StepOk -> "✓ OK"
        types.StepFailed(_) -> "✗ FAILED"
        types.StepSkipped -> "- SKIPPED"
      }
      io.println(
        "   " <> status_str <> " (" <> format_duration_ms(duration_ms) <> ")",
      )
      case string.trim(output) {
        "" -> Nil
        trimmed -> io.println(trimmed)
      }
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
  Ok(string.join(
    [
      "No embedded pipelines are shipped with the CLI.",
      "",
      "Run by runtime reference:",
      "  thingfactory run <module:function>",
      "",
      "Or run by source file:",
      "  thingfactory run -f <file.gleam> <pipeline_function>",
      "",
      "Inspect results interactively:",
      "  thingfactory inspect -f <file.gleam> <pipeline_function>",
      "",
      "Print a detailed result report:",
      "  thingfactory results -f <file.gleam> <pipeline_function>",
      "",
      "Run and extract artifacts:",
      "  thingfactory artifacts -f <file.gleam> <pipeline_function> -o <dir>",
      "",
      "Example:",
      "  thingfactory run -f src/thingfactory/examples.gleam basic_pipeline",
    ],
    "\n",
  ))
}

fn pipeline_label(
  source_file: Result(String, Nil),
  pipeline_selector: String,
) -> String {
  case source_file {
    Ok(file_path) -> file_path <> ":" <> pipeline_selector
    Error(Nil) -> pipeline_selector
  }
}

fn execute_pipeline_selector(
  source_file: Result(String, Nil),
  pipeline_selector: String,
  mode: OutputMode,
) -> Result(ExecutionResult(Dynamic), String) {
  case source_file {
    Ok(file_path) ->
      execute_pipeline_from_file(file_path, pipeline_selector, mode)
    Error(Nil) -> execute_pipeline(pipeline_selector, mode)
  }
}

fn format_step_status(status: types.StepStatus) -> String {
  case status {
    types.StepOk -> "OK"
    types.StepSkipped -> "SKIPPED"
    types.StepFailed(err) -> "FAILED: " <> format_step_error(err)
  }
}

fn format_step_error(error: types.StepError) -> String {
  case error {
    types.StepFailure(message) -> message
    types.StepTimeout(step, limit_ms) ->
      step <> " exceeded timeout of " <> int.to_string(limit_ms) <> "ms"
    types.ArtifactNotFound(key) -> "Artifact not found: " <> key
  }
}

fn format_results_report(
  pipeline_name: String,
  result: ExecutionResult(Dynamic),
) -> String {
  let total_duration =
    list.fold(result.trace, 0, fn(acc, trace) { acc + trace.duration_ms })
  let status = case result.result {
    Ok(_) -> "SUCCESS"
    Error(_) -> "FAILED"
  }
  let lines =
    result.trace
    |> list.index_map(fn(trace, index) {
      "  ["
      <> int.to_string(index + 1)
      <> "] "
      <> trace.step_name
      <> " | "
      <> format_step_status(trace.status)
      <> " | "
      <> format_duration_ms(trace.duration_ms)
    })

  string.join(
    [
      "Pipeline Results",
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
      "Pipeline: " <> pipeline_name,
      "Status: " <> status,
      "Steps: " <> int.to_string(list.length(result.trace)),
      "Total: " <> format_duration_ms(total_duration),
      "",
      "Step Breakdown:",
      ..lines
    ],
    "\n",
  )
}

/// Main entry point for CLI
pub fn main() {
  let cli_args = argv.load().arguments
  let result = parse_args(cli_args)

  case result {
    Ok(Run(
      pipeline_selector,
      source_file,
      compact,
      interactive,
      output_dir,
      isolator,
      docker_image,
    )) -> {
      let mode = resolve_mode(compact, interactive)
      case resolve_isolation_mode(isolator, docker_image, interactive) {
        Error(err) -> io.println("Error: " <> err)
        Ok(DockerIsolation(image)) -> {
          case execute_run_in_docker(cli_args, image) {
            Ok(output) -> {
              case string.trim(output) {
                "" -> Nil
                _ -> io.println(output)
              }
            }
            Error(err) -> io.println("Error: " <> err)
          }
        }
        Ok(LocalIsolation) -> {
          let label = pipeline_label(source_file, pipeline_selector)
          let execution_result =
            execute_pipeline_selector(source_file, pipeline_selector, mode)

          case execution_result {
            Ok(exec_result) -> {
              case format_summary(label, exec_result, mode) {
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
      }
    }
    Ok(Inspect(pipeline_selector, source_file)) -> {
      let label = pipeline_label(source_file, pipeline_selector)
      case
        execute_pipeline_selector(source_file, pipeline_selector, Interactive)
      {
        Ok(exec_result) -> {
          let _ = format_summary(label, exec_result, Interactive)
          Nil
        }
        Error(err) -> io.println("Error: " <> err)
      }
    }
    Ok(Results(pipeline_selector, source_file)) -> {
      let label = pipeline_label(source_file, pipeline_selector)
      case execute_pipeline_selector(source_file, pipeline_selector, Compact) {
        Ok(exec_result) -> io.println(format_results_report(label, exec_result))
        Error(err) -> io.println("Error: " <> err)
      }
    }
    Ok(Artifacts(pipeline_selector, source_file, output_dir)) -> {
      case execute_pipeline_selector(source_file, pipeline_selector, Compact) {
        Ok(exec_result) -> {
          let _ = extract_artifacts(exec_result, output_dir)
          Nil
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

fn resolve_isolation_mode(
  isolator: Result(String, Nil),
  docker_image: Result(String, Nil),
  interactive: Bool,
) -> Result(IsolationMode, String) {
  // Interactive mode requires direct stdin/stdout so default to local.
  case interactive {
    True -> Ok(LocalIsolation)
    False -> {
      let selected = case isolator {
        Ok(value) -> string.lowercase(string.trim(value))
        Error(Nil) -> "docker"
      }
      let image = case docker_image {
        Ok(value) -> string.trim(value)
        Error(Nil) -> "ghcr.io/gleam-lang/gleam:v1.13.0-erlang"
      }
      case selected {
        "docker" -> Ok(DockerIsolation(image: image))
        "local" -> Ok(LocalIsolation)
        _ ->
          Error(
            "Invalid isolator: "
            <> selected
            <> ". Expected 'docker' or 'local'.",
          )
      }
    }
  }
}

fn execute_run_in_docker(
  args: List(String),
  image: String,
) -> Result(String, String) {
  case get_cwd() {
    Error(err) -> Error("Failed to determine current directory: " <> err)
    Ok(cwd) -> {
      let rewritten_args = rewrite_run_args_for_local_isolation(args)
      let inner =
        "gleam build --target erlang --warnings-as-errors && gleam run -m thingfactory/cli -- "
        <> shell_join(rewritten_args)
      let docker_args = [
        "run",
        "--rm",
        "-v",
        cwd <> ":/workspace",
        "-w",
        "/workspace",
        image,
        "sh",
        "-lc",
        inner,
      ]
      case command_runner.run("docker", docker_args) {
        Error(err) -> Error("Failed to execute docker isolation: " <> err)
        Ok(output) -> {
          let combined = string.trim(output.stdout <> output.stderr)
          case output.exit_code {
            0 -> Ok(combined)
            _ ->
              Error(
                "Docker-isolated run failed (exit "
                <> int.to_string(output.exit_code)
                <> "): "
                <> combined,
              )
          }
        }
      }
    }
  }
}

fn rewrite_run_args_for_local_isolation(args: List(String)) -> List(String) {
  case args {
    ["run", ..rest] -> {
      let without_isolator = strip_opt_with_value(rest, "--isolator")
      let without_image =
        strip_opt_with_value(without_isolator, "--docker-image")
      let run_args = list.append(without_image, ["--isolator", "local"])
      ["run", ..run_args]
    }
    _ -> args
  }
}

fn strip_opt_with_value(args: List(String), opt_name: String) -> List(String) {
  case args {
    [] -> []
    [first] -> [first]
    [first, _second, ..rest] if first == opt_name ->
      strip_opt_with_value(rest, opt_name)
    [first, ..rest] -> [first, ..strip_opt_with_value(rest, opt_name)]
  }
}

fn shell_join(args: List(String)) -> String {
  args
  |> list.map(shell_quote)
  |> string.join(" ")
}

fn shell_quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
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

@external(erlang, "thingfactory_erlang_cli", "load_pipeline")
@external(javascript, "./cli_ffi.mjs", "load_pipeline")
fn load_pipeline(
  module_name: String,
  function_name: String,
) -> Result(pipeline.Pipeline(Dynamic), String)

@external(erlang, "thingfactory_erlang_cli", "load_pipeline_from_file")
@external(javascript, "./cli_ffi.mjs", "load_pipeline_from_file")
fn load_pipeline_from_file(
  file_path: String,
  function_name: String,
) -> Result(pipeline.Pipeline(Dynamic), String)

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

@external(erlang, "thingfactory_erlang_cli", "get_cwd")
@external(javascript, "./cli_ffi.mjs", "get_cwd")
fn get_cwd() -> Result(String, String)
