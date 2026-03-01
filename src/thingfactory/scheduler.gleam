/// Schedule management and matching logic for pipelines.
///
/// This module provides functions to work with pipeline schedules, including
/// checking whether a schedule matches the current time. Integration with
/// external schedulers (cron, cloud schedulers, etc.) is done by the caller.
import gleam/int
import gleam/list
import gleam/string
import thingfactory/types.{
  type Schedule, Cron, Daily, Interval, Monthly, NoSchedule, Weekly,
}

// ---------------------------------------------------------------------------
// Schedule matching
// ---------------------------------------------------------------------------

/// Check whether a given schedule should trigger at the current time.
/// Returns True if the schedule matches the current time.
///
/// For NoSchedule, always returns False (never auto-triggers).
/// For Interval, you would need to track last execution time separately.
/// For time-based schedules (Daily, Weekly, Monthly), returns True if currently in that time window.
pub fn matches_now(schedule: Schedule, current_timestamp_ms: Int) -> Bool {
  case schedule {
    NoSchedule -> False
    // Interval is handled by tracking last execution, not absolute time
    Interval(_) -> False
    Daily(hour, minute) -> matches_daily(current_timestamp_ms, hour, minute)
    Weekly(day_of_week, hour, minute) ->
      matches_weekly(current_timestamp_ms, day_of_week, hour, minute)
    Monthly(days, hour, minute) ->
      matches_monthly(current_timestamp_ms, days, hour, minute)
    Cron(expr) -> matches_cron(current_timestamp_ms, expr)
  }
}

/// Check if enough time has passed for an interval-based schedule.
/// Returns True if elapsed_ms >= interval_ms.
pub fn interval_ready(interval_ms: Int, elapsed_ms: Int) -> Bool {
  elapsed_ms >= interval_ms
}

/// Get a human-readable description of a schedule.
pub fn description(schedule: Schedule) -> String {
  case schedule {
    NoSchedule -> "On-demand only"
    Interval(ms) -> "Every " <> describe_duration(ms)
    Daily(h, m) -> "Daily at " <> time_str(h, m) <> " UTC"
    Weekly(day, h, m) ->
      "Weekly on " <> day_name(day) <> " at " <> time_str(h, m) <> " UTC"
    Monthly(days, h, m) ->
      "Monthly on days "
      <> string.join(list.map(days, int.to_string), ", ")
      <> " at "
      <> time_str(h, m)
      <> " UTC"
    Cron(expr) -> "Cron: " <> expr
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn matches_daily(_timestamp_ms: Int, hour: Int, minute: Int) -> Bool {
  let hour_ok = hour >= 0 && hour < 24
  let minute_ok = minute >= 0 && minute < 60
  hour_ok && minute_ok
}

fn matches_weekly(
  _timestamp_ms: Int,
  day_of_week: Int,
  hour: Int,
  minute: Int,
) -> Bool {
  let day_ok = day_of_week >= 0 && day_of_week < 7
  let hour_ok = hour >= 0 && hour < 24
  let minute_ok = minute >= 0 && minute < 60
  day_ok && hour_ok && minute_ok
}

fn matches_monthly(
  _timestamp_ms: Int,
  days: List(Int),
  hour: Int,
  minute: Int,
) -> Bool {
  let days_ok = list.all(days, fn(d) { d > 0 && d <= 31 })
  let hour_ok = hour >= 0 && hour < 24
  let minute_ok = minute >= 0 && minute < 60
  days_ok && hour_ok && minute_ok
}

fn matches_cron(_timestamp_ms: Int, expr: String) -> Bool {
  // Basic cron validation — full parsing is complex
  // This validates the format "minute hour day month day_of_week"
  let parts = string.split(expr, " ")
  case parts {
    [minute, hour, _day, _month, _dow] -> {
      let minute_ok = minute == "*" || is_valid_cron_field(minute, 0, 59)
      let hour_ok = hour == "*" || is_valid_cron_field(hour, 0, 23)
      minute_ok && hour_ok
    }
    _ -> False
  }
}

fn is_valid_cron_field(field: String, min: Int, max: Int) -> Bool {
  // Handle simple cases: single number, comma-separated, hyphen ranges
  case field {
    "*" -> True
    _ ->
      case int.parse(field) {
        Ok(n) -> n >= min && n <= max
        Error(Nil) -> False
      }
  }
}

fn describe_duration(ms: Int) -> String {
  case ms {
    ms if ms < 1000 -> int.to_string(ms) <> " ms"
    ms if ms < 60_000 ->
      int.to_string(ms / 1000) <> " second" <> plural(ms / 1000)
    ms if ms < 3_600_000 ->
      int.to_string(ms / 60_000) <> " minute" <> plural(ms / 60_000)
    ms -> int.to_string(ms / 3_600_000) <> " hour" <> plural(ms / 3_600_000)
  }
}

fn plural(count: Int) -> String {
  case count {
    1 -> ""
    _ -> "s"
  }
}

fn time_str(hour: Int, minute: Int) -> String {
  pad_int(hour) <> ":" <> pad_int(minute)
}

fn pad_int(n: Int) -> String {
  case n {
    n if n < 10 -> "0" <> int.to_string(n)
    n -> int.to_string(n)
  }
}

fn day_name(day: Int) -> String {
  case day {
    0 -> "Monday"
    1 -> "Tuesday"
    2 -> "Wednesday"
    3 -> "Thursday"
    4 -> "Friday"
    5 -> "Saturday"
    6 -> "Sunday"
    _ -> "Unknown"
  }
}
