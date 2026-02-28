/// Tests for pipeline scheduling functionality
import gleam/string
import gleeunit/should
import thingfactory/scheduler
import thingfactory/types

pub fn schedule_description_no_schedule_test() {
  let desc = scheduler.description(types.NoSchedule)
  desc |> should.equal("On-demand only")
}

pub fn schedule_description_interval_test() {
  let desc = scheduler.description(types.Interval(60_000))
  string.contains(desc, "minute") |> should.equal(True)
}

pub fn schedule_description_daily_test() {
  let desc = scheduler.description(types.Daily(9, 30))
  desc |> should.equal("Daily at 09:30 UTC")
}

pub fn schedule_description_weekly_test() {
  let desc = scheduler.description(types.Weekly(0, 14, 0))
  desc |> should.equal("Weekly on Monday at 14:00 UTC")
}

pub fn schedule_description_monthly_test() {
  let desc = scheduler.description(types.Monthly([1, 15], 8, 0))
  string.contains(desc, "1") |> should.equal(True)
  string.contains(desc, "15") |> should.equal(True)
}

pub fn schedule_description_cron_test() {
  let desc = scheduler.description(types.Cron("0 9 * * 1-5"))
  string.contains(desc, "Cron") |> should.equal(True)
}

pub fn interval_ready_test() {
  let ready1 = scheduler.interval_ready(60_000, 60_000)
  ready1 |> should.equal(True)

  let ready2 = scheduler.interval_ready(60_000, 120_000)
  ready2 |> should.equal(True)

  let ready3 = scheduler.interval_ready(60_000, 30_000)
  ready3 |> should.equal(False)
}

pub fn matches_now_no_schedule_test() {
  let matches = scheduler.matches_now(types.NoSchedule, 0)
  matches |> should.equal(False)
}

pub fn matches_now_interval_test() {
  // Interval-based schedules don't use absolute time matching
  let matches = scheduler.matches_now(types.Interval(60_000), 0)
  matches |> should.equal(False)
}

pub fn matches_now_daily_test() {
  // Valid time should match
  let matches = scheduler.matches_now(types.Daily(9, 30), 0)
  matches |> should.equal(True)

  // Invalid hour should not match
  let matches_invalid = scheduler.matches_now(types.Daily(25, 30), 0)
  matches_invalid |> should.equal(False)
}

pub fn matches_now_weekly_test() {
  // Valid time should match
  let matches = scheduler.matches_now(types.Weekly(0, 9, 0), 0)
  matches |> should.equal(True)

  // Invalid day should not match
  let matches_invalid = scheduler.matches_now(types.Weekly(7, 9, 0), 0)
  matches_invalid |> should.equal(False)
}

pub fn matches_now_monthly_test() {
  // Valid time should match
  let matches = scheduler.matches_now(types.Monthly([1, 15], 8, 0), 0)
  matches |> should.equal(True)

  // Invalid day should not match
  let matches_invalid = scheduler.matches_now(types.Monthly([32], 8, 0), 0)
  matches_invalid |> should.equal(False)
}

pub fn matches_now_cron_test() {
  // Valid cron should match
  let matches = scheduler.matches_now(types.Cron("0 9 * * 1-5"), 0)
  matches |> should.equal(True)

  // Invalid cron should not match
  let matches_invalid = scheduler.matches_now(types.Cron("invalid"), 0)
  matches_invalid |> should.equal(False)
}
