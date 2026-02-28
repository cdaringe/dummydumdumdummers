import gleeunit/should
import thingfactory/timing

pub fn timing_measure_returns_tuple_test() {
  let #(duration_ms, result) = timing.measure(fn() { "done" })

  // Just verify structure - duration is captured and result is preserved
  result |> should.equal("done")
}

pub fn timing_returns_exact_result_test() {
  let expected = "test_value"
  let #(_duration_ms, result) = timing.measure(fn() { expected })

  result |> should.equal(expected)
}
