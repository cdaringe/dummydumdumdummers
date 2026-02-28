/// Interactive CLI mode for drilling down into pipeline state
///
/// This module provides a REPL-like interface for exploring pipeline execution results.
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import thingfactory/types.{type ExecutionResult, type StepTrace}

/// Interactive mode state
pub type InteractiveState {
  InteractiveState(
    pipeline_name: String,
    result: ExecutionResult(Dynamic),
    steps: List(StepTrace),
  )
}

/// Parse and execute an interactive command
pub fn execute_command(
  state: InteractiveState,
  command: String,
) -> #(InteractiveState, String) {
  let trimmed = string.trim(command)

  case string.split(trimmed, " ") {
    [] -> #(state, "")
    ["help"] -> #(state, format_help())
    ["list"] -> #(state, format_step_list(state.steps))
    ["artifacts"] -> #(state, format_artifacts(state.result))
    ["step", index_str] -> {
      case int.parse(index_str) {
        Ok(index) -> {
          let matching =
            list.index_map(state.steps, fn(trace, idx) {
              case idx == index {
                True -> Ok(#(idx, trace))
                False -> Error(Nil)
              }
            })
            |> list.filter_map(fn(result) { result })

          case matching {
            [#(idx, trace), ..] -> #(state, format_step_detail(idx, trace))
            [] -> #(state, "Error: Step index out of range")
          }
        }
        Error(_) -> {
          let matching =
            list.index_map(state.steps, fn(trace, idx) {
              case trace.step_name == index_str {
                True -> Ok(#(idx, trace))
                False -> Error(Nil)
              }
            })
            |> list.filter_map(fn(result) { result })

          case matching {
            [#(idx, trace), ..] -> #(state, format_step_detail(idx, trace))
            [] -> #(state, "Error: Step '" <> index_str <> "' not found")
          }
        }
      }
    }
    ["step", name, ..rest] -> {
      let full_name = string.join([name, ..rest], " ")
      let matching =
        list.index_map(state.steps, fn(trace, idx) {
          case trace.step_name == full_name {
            True -> Ok(#(idx, trace))
            False -> Error(Nil)
          }
        })
        |> list.filter_map(fn(result) { result })

      case matching {
        [#(idx, trace), ..] -> #(state, format_step_detail(idx, trace))
        [] -> #(state, "Error: Step '" <> full_name <> "' not found")
      }
    }
    ["stats"] -> #(state, format_stats(state.result, state.steps))
    _ -> #(state, "Unknown command. Type 'help' for available commands.")
  }
}

fn format_help() -> String {
  string.join(
    [
      "Interactive Mode Commands:",
      "  help              - Show this help message",
      "  list              - List all steps with their status",
      "  step <N>          - Show details for step number N (0-indexed)",
      "  step <name>       - Show details for step with name <name>",
      "  stats             - Show pipeline statistics",
      "  artifacts         - List produced artifacts and their values",
      "  exit              - Exit interactive mode",
    ],
    "\n",
  )
}

fn format_step_error(error: types.StepError) -> String {
  case error {
    types.StepFailure(message) -> message
    types.StepTimeout(step, limit_ms) ->
      step <> " exceeded timeout of " <> int.to_string(limit_ms) <> "ms"
    types.ArtifactNotFound(key) -> "Artifact not found: " <> key
  }
}

fn format_step_list(steps: List(StepTrace)) -> String {
  let header = "Available Steps:"
  let step_lines =
    list.index_map(steps, fn(trace, idx) {
      let status_icon = case trace.status {
        types.StepOk -> "✓"
        types.StepFailed(_) -> "✗"
        types.StepSkipped -> "-"
      }
      "  ["
      <> int.to_string(idx)
      <> "] "
      <> status_icon
      <> " "
      <> trace.step_name
      <> " ("
      <> format_duration_ms(trace.duration_ms)
      <> ")"
    })

  [header, ..step_lines]
  |> string.join("\n")
}

fn format_step_detail(index: Int, trace: StepTrace) -> String {
  let status_str = case trace.status {
    types.StepOk -> "OK"
    types.StepFailed(error) -> "FAILED: " <> format_step_error(error)
    types.StepSkipped -> "SKIPPED"
  }

  string.join(
    [
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
      "Step [" <> int.to_string(index) <> "]: " <> trace.step_name,
      "Status:   " <> status_str,
      "Duration: " <> format_duration_ms(trace.duration_ms),
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ],
    "\n",
  )
}

fn format_stats(
  result: ExecutionResult(Dynamic),
  steps: List(StepTrace),
) -> String {
  let status = case result.result {
    Ok(_) -> "SUCCESS"
    Error(_) -> "FAILED"
  }

  let total_duration =
    list.fold(steps, 0, fn(acc, trace) { acc + trace.duration_ms })
  let successful =
    list.count(steps, fn(trace) {
      case trace.status {
        types.StepOk -> True
        _ -> False
      }
    })
  let failed =
    list.count(steps, fn(trace) {
      case trace.status {
        types.StepFailed(_) -> True
        _ -> False
      }
    })
  let skipped =
    list.count(steps, fn(trace) {
      case trace.status {
        types.StepSkipped -> True
        _ -> False
      }
    })

  string.join(
    [
      "Pipeline Statistics:",
      "  Status:     " <> status,
      "  Total Steps: " <> int.to_string(list.length(steps)),
      "  Successful: " <> int.to_string(successful),
      "  Failed:     " <> int.to_string(failed),
      "  Skipped:    " <> int.to_string(skipped),
      "  Total Time: " <> format_duration_ms(total_duration),
    ],
    "\n",
  )
}

fn format_duration_ms(ms: Int) -> String {
  case ms {
    n if n < 1000 -> int.to_string(n) <> "ms"
    n -> {
      let seconds = int.to_float(n) /. 1000.0
      let to_string_float = fn(f: Float) -> String {
        // Format float to 1 decimal place
        let str = float.to_string(f)
        str
      }
      to_string_float(seconds) <> "s"
    }
  }
}

fn format_artifacts(result: ExecutionResult(Dynamic)) -> String {
  let keys = dict.keys(result.artifacts)
  let count = list.length(keys)

  case count {
    0 ->
      string.join(
        [
          "No artifacts produced by this pipeline.",
          "",
          "To produce artifacts, use add_step_with_ctx and write to the artifact store:",
          "  artifact_store.write(ctx.artifact_store, \"key\", value)",
          "",
          "To extract artifacts to disk, re-run with --output-dir:",
          "  thingfactory run <pipeline> --output-dir ./artifacts",
        ],
        "\n",
      )
    _ -> {
      let header = "Artifacts (" <> int.to_string(count) <> " produced):"
      let artifact_lines =
        list.map(keys, fn(key) {
          case dict.get(result.artifacts, key) {
            Ok(value) -> "  " <> key <> " = " <> string.inspect(value)
            Error(Nil) -> "  " <> key <> " = <error>"
          }
        })
      let footer = [
        "",
        "To extract artifacts to disk, re-run with --output-dir:",
        "  thingfactory run <pipeline> --output-dir ./artifacts",
      ]

      [header, ..list.append(artifact_lines, footer)]
      |> string.join("\n")
    }
  }
}

/// Show interactive mode prompt and instructions
pub fn show_welcome(state: InteractiveState) -> Nil {
  io.println("")
  io.println("🔍 Interactive Mode")
  io.println("Type 'help' for available commands, 'exit' to quit")
  io.println("")
  Nil
}

/// Show the interactive mode prompt
pub fn show_prompt() -> Nil {
  io.print("> ")
  Nil
}
