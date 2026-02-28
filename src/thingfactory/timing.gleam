/// Timing utilities for measuring step execution duration.
///
/// Provides timing capabilities by measuring wall-clock time between
/// measurements. Uses Date.now() on JavaScript and erlang:system_time()
/// on Erlang runtime.
@external(erlang, "timing_erlang", "get_current_time_ms")
@external(javascript, "./timing_ffi.mjs", "getCurrentTimeMs")
pub fn get_current_time_ms() -> Int

/// Measure the duration of executing a function in milliseconds.
pub fn measure(f: fn() -> a) -> #(Int, a) {
  let start = get_current_time_ms()
  let result = f()
  let end = get_current_time_ms()
  let duration = end - start
  #(duration, result)
}
