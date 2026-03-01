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
import gleam_community/ansi
import simplifile
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
  ListPipelines(
    source_file: Result(String, Nil),
    module_selector: Result(String, Nil),
  )
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
  clip.command({
    use source_file <- clip.parameter
    use module_selector <- clip.parameter
    ListPipelines(source_file: source_file, module_selector: module_selector)
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help("Gleam file to discover pipeline functions from")
    |> opt.optional(),
  )
  |> clip.arg(
    arg.new("module")
    |> arg.help(
      "Module reference to discover pipelines from (e.g. thingfactory@examples)",
    )
    |> arg.optional(),
  )
  |> clip.help(help.simple(
    "thingfactory list",
    "List available pipelines (-f <file> or <module> reference)",
  ))
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
      let #(icon, style) = case status {
        types.StepOk -> #("✓", ansi.green)
        types.StepFailed(_) -> #("✗", ansi.red)
        types.StepSkipped -> #("-", ansi.yellow)
      }
      io.println(
        ansi.dim(
          "  [" <> int.to_string(index) <> "/" <> int.to_string(total) <> "]",
        )
        <> " "
        <> ansi.cyan(name)
        <> " "
        <> style(icon)
        <> " "
        <> ansi.dim(format_duration_ms(duration_ms)),
      )
    }
  }
}

/// Verbose progress: prints step start and detailed completion info
fn verbose_progress(event: StepEvent) -> Nil {
  case event {
    types.StepStarting(name, index, total) ->
      io.println(
        ansi.bold(ansi.cyan(">> "))
        <> ansi.dim(
          "[" <> int.to_string(index) <> "/" <> int.to_string(total) <> "]",
        )
        <> " "
        <> ansi.cyan(name),
      )
    types.StepFinished(_, _, _, status, duration_ms, output) -> {
      let status_str = case status {
        types.StepOk -> ansi.green("✓ OK")
        types.StepFailed(_) -> ansi.red("✗ FAILED")
        types.StepSkipped -> ansi.yellow("- SKIPPED")
      }
      io.println(
        "   "
        <> status_str
        <> " "
        <> ansi.dim("(" <> format_duration_ms(duration_ms) <> ")"),
      )
      case string.trim(output) {
        "" -> Nil
        trimmed -> io.println(ansi.dim(trimmed))
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
      io.println(ansi.dim("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
      io.println(ansi.bold("Pipeline: ") <> ansi.cyan(name))
      io.println(ansi.dim("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
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
        Ok(_) -> ansi.green("✓")
        Error(_) -> ansi.red("✗")
      }
      Ok(
        ansi.dim("── ")
        <> status
        <> " "
        <> ansi.bold(name)
        <> " "
        <> ansi.dim(
          "("
          <> int.to_string(step_count)
          <> " steps, "
          <> format_duration_ms(total_duration)
          <> ")",
        ),
      )
    }
    Verbose -> {
      let status = case result.result {
        Ok(_) -> ansi.bold(ansi.green("SUCCESS"))
        Error(_) -> ansi.bold(ansi.red("FAILED"))
      }
      Ok(
        ansi.dim("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        <> "\n"
        <> ansi.bold("Result: ")
        <> status
        <> ansi.dim(
          " | "
          <> int.to_string(step_count)
          <> " steps | "
          <> format_duration_ms(total_duration),
        ),
      )
    }
    Interactive -> {
      let status = case result.result {
        Ok(_) -> ansi.bold(ansi.green("SUCCESS"))
        Error(_) -> ansi.bold(ansi.red("FAILED"))
      }
      io.println(
        ansi.dim("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        <> "\n"
        <> ansi.bold("Result: ")
        <> status
        <> ansi.dim(
          " | "
          <> int.to_string(step_count)
          <> " steps | "
          <> format_duration_ms(total_duration),
        ),
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
      io.println(ansi.dim("No artifacts to extract."))
      Ok(0)
    }
    _ -> {
      io.println(
        ansi.bold("Extracting ")
        <> ansi.cyan(int.to_string(count))
        <> ansi.bold(" artifact(s) to ")
        <> ansi.cyan(output_dir <> "/"),
      )
      list.each(keys, fn(key) {
        case dict.get(result.artifacts, key) {
          Ok(value) -> {
            let content = string.inspect(value)
            case write_file(output_dir, key, content) {
              Ok(path) -> io.println("  " <> ansi.green("✓") <> " " <> path)
              Error(err) ->
                io.println(
                  "  " <> ansi.red("✗") <> " " <> key <> ": " <> ansi.red(err),
                )
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

fn list_pipelines(
  source_file: Result(String, Nil),
  module_selector: Result(String, Nil),
) -> Result(String, String) {
  case source_file, module_selector {
    Ok(file_path), _ ->
      case discover_pipelines_in_file(file_path) {
        Error(err) -> Error(err)
        Ok(entries) -> format_pipeline_entries(file_path, entries)
      }
    _, Ok(module_name) -> {
      let file_path = module_to_file_path(module_name)
      case discover_pipelines_in_file(file_path) {
        Error(err) -> Error(err)
        Ok(entries) -> format_pipeline_entries(module_name, entries)
      }
    }
    Error(Nil), Error(Nil) ->
      Ok(string.join(
        [
          ansi.dim("No embedded pipelines are shipped with the CLI."),
          "",
          ansi.bold("Run by runtime reference:"),
          "  " <> ansi.cyan("thingfactory run <module:function>"),
          "",
          ansi.bold("Or run by source file:"),
          "  "
            <> ansi.cyan("thingfactory run -f <file.gleam> <pipeline_function>"),
          "",
          ansi.bold("Discover pipelines in a module:"),
          "  " <> ansi.cyan("thingfactory list <module>"),
          "",
          ansi.bold("Discover pipelines in a file:"),
          "  " <> ansi.cyan("thingfactory list -f <file.gleam>"),
          "",
          ansi.bold("Inspect results interactively:"),
          "  "
            <> ansi.cyan(
            "thingfactory inspect -f <file.gleam> <pipeline_function>",
          ),
          "",
          ansi.bold("Print a detailed result report:"),
          "  "
            <> ansi.cyan(
            "thingfactory results -f <file.gleam> <pipeline_function>",
          ),
          "",
          ansi.bold("Run and extract artifacts:"),
          "  "
            <> ansi.cyan(
            "thingfactory artifacts -f <file.gleam> <pipeline_function> -o <dir>",
          ),
          "",
          ansi.bold("Example:"),
          "  "
            <> ansi.cyan(
            "thingfactory run -f src/thingfactory/examples.gleam basic_pipeline",
          ),
        ],
        "\n",
      ))
  }
}

fn format_pipeline_entries(
  source: String,
  entries: List(PipelineEntry),
) -> Result(String, String) {
  case entries {
    [] -> Ok(ansi.dim("No pipeline-returning functions found in " <> source))
    _ -> {
      let header = ansi.bold("Pipelines in ") <> ansi.cyan(source) <> ":\n"
      let lines =
        entries
        |> list.map(fn(entry) {
          "  "
          <> ansi.cyan(entry.func_name)
          <> "  "
          <> entry.pipeline_name
          <> " "
          <> ansi.dim("v" <> entry.version)
          <> "  "
          <> ansi.dim("(" <> int.to_string(entry.step_count) <> " steps)")
        })
      Ok(header <> string.join(lines, "\n"))
    }
  }
}

/// Info about a discovered pipeline entrypoint
pub type PipelineEntry {
  PipelineEntry(
    func_name: String,
    pipeline_name: String,
    version: String,
    step_count: Int,
  )
}

/// Discover pipeline-returning functions in a Gleam source file.
/// Reads the file, extracts zero-arity public function names, tries
/// loading each via the existing FFI, and returns metadata for those
/// that return a Pipeline.
fn discover_pipelines_in_file(
  file_path: String,
) -> Result(List(PipelineEntry), String) {
  case simplifile.read(file_path) {
    Error(_) -> Error("Could not read file: " <> file_path)
    Ok(source) -> {
      let func_names = extract_pipeline_fn_names(source)
      let entries =
        func_names
        |> list.filter_map(fn(name) {
          case load_pipeline_from_file(file_path, name) {
            Ok(p) -> {
              let id = pipeline.id(p)
              let types.PipelineId(pname, pversion) = id
              let step_count = list.length(pipeline.steps(p))
              Ok(PipelineEntry(
                func_name: name,
                pipeline_name: pname,
                version: pversion,
                step_count: step_count,
              ))
            }
            Error(_) -> Error(Nil)
          }
        })
      Ok(entries)
    }
  }
}

/// Convert a module reference to a source file path.
/// e.g. "thingfactory@examples" -> "src/thingfactory/examples.gleam"
fn module_to_file_path(module_name: String) -> String {
  "src/" <> string.replace(module_name, "@", "/") <> ".gleam"
}

/// Extract zero-arity public function names that return a Pipeline type.
/// Matches lines like `pub fn name() -> pipeline.Pipeline(Dynamic) {`
/// or `pub fn name() -> Pipeline(Dynamic) {`.
fn extract_pipeline_fn_names(source: String) -> List(String) {
  source
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    let trimmed = string.trim(line)
    case string.starts_with(trimmed, "pub fn ") {
      False -> Error(Nil)
      True -> {
        // Drop "pub fn " prefix
        let rest = string.drop_start(trimmed, 7)
        // Find the opening paren
        case string.split_once(rest, "(") {
          Error(Nil) -> Error(Nil)
          Ok(#(name, after_paren)) -> {
            // Check it's zero-arity: next non-whitespace char should be ")"
            case string.starts_with(string.trim_start(after_paren), ")") {
              False -> Error(Nil)
              True -> {
                // Check the return type contains "Pipeline"
                case string.contains(after_paren, "Pipeline") {
                  True -> Ok(string.trim(name))
                  False -> Error(Nil)
                }
              }
            }
          }
        }
      }
    }
  })
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
    types.StepOk -> ansi.green("OK")
    types.StepSkipped -> ansi.yellow("SKIPPED")
    types.StepFailed(err) -> ansi.red("FAILED: " <> format_step_error(err))
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
    Ok(_) -> ansi.bold(ansi.green("SUCCESS"))
    Error(_) -> ansi.bold(ansi.red("FAILED"))
  }
  let lines =
    result.trace
    |> list.index_map(fn(trace, index) {
      ansi.dim("  [" <> int.to_string(index + 1) <> "]")
      <> " "
      <> ansi.cyan(trace.step_name)
      <> ansi.dim(" | ")
      <> format_step_status(trace.status)
      <> ansi.dim(" | " <> format_duration_ms(trace.duration_ms))
    })

  string.join(
    [
      ansi.bold("Pipeline Results"),
      ansi.dim("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"),
      ansi.bold("Pipeline: ") <> ansi.cyan(pipeline_name),
      ansi.bold("Status:   ") <> status,
      ansi.bold("Steps:    ") <> int.to_string(list.length(result.trace)),
      ansi.bold("Total:    ") <> format_duration_ms(total_duration),
      "",
      ansi.bold("Step Breakdown:"),
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
        Error(err) -> io.println(ansi.red("Error: " <> err))
        Ok(DockerIsolation(image)) -> {
          case execute_run_in_docker(cli_args, image) {
            Ok(output) -> {
              case string.trim(output) {
                "" -> Nil
                _ -> io.println(output)
              }
            }
            Error(err) -> io.println(ansi.red("Error: " <> err))
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
                Error(err) -> io.println(ansi.red("Error: " <> err))
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
            Error(err) -> io.println(ansi.red("Error: " <> err))
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
        Error(err) -> io.println(ansi.red("Error: " <> err))
      }
    }
    Ok(Results(pipeline_selector, source_file)) -> {
      let label = pipeline_label(source_file, pipeline_selector)
      case execute_pipeline_selector(source_file, pipeline_selector, Compact) {
        Ok(exec_result) -> io.println(format_results_report(label, exec_result))
        Error(err) -> io.println(ansi.red("Error: " <> err))
      }
    }
    Ok(Artifacts(pipeline_selector, source_file, output_dir)) -> {
      case execute_pipeline_selector(source_file, pipeline_selector, Compact) {
        Ok(exec_result) -> {
          let _ = extract_artifacts(exec_result, output_dir)
          Nil
        }
        Error(err) -> io.println(ansi.red("Error: " <> err))
      }
    }
    Ok(ListPipelines(source_file, module_selector)) -> {
      case list_pipelines(source_file, module_selector) {
        Ok(output) -> io.println(output)
        Error(err) -> io.println(ansi.red("Error: " <> err))
      }
    }
    Error(err) -> io.println(ansi.red(err))
  }
}

pub fn resolve_isolation_mode(
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
      io.println(ansi.red("Error reading input"))
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
