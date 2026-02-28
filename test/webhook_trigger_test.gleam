import gleam/dict
import gleam/dynamic
import gleam/option
import gleeunit/should
import thingfactory/webhook_trigger

pub fn github_push_event_creation_test() {
  let event =
    webhook_trigger.github_push_event("user/repo", "main", "abc123", 1000)
  event.topic |> should.equal("github.push")
  event.source |> should.equal(option.Some("github"))
  event.event_id |> should.equal(option.Some("abc123"))
  event.timestamp_ms |> should.equal(1000)
}

pub fn github_pr_event_creation_test() {
  let event = webhook_trigger.github_pr_event("user/repo", 42, "opened", 2000)
  event.topic |> should.equal("github.pull_request")
  event.source |> should.equal(option.Some("github"))
  event.timestamp_ms |> should.equal(2000)
}

pub fn gitlab_push_event_creation_test() {
  let event =
    webhook_trigger.gitlab_push_event(
      "group/project",
      "develop",
      "def456",
      3000,
    )
  event.topic |> should.equal("gitlab.push")
  event.source |> should.equal(option.Some("gitlab"))
  event.event_id |> should.equal(option.Some("def456"))
}

pub fn custom_event_creation_test() {
  let event =
    webhook_trigger.custom_event(
      "custom.topic",
      dynamic.string("payload"),
      4000,
    )
  event.topic |> should.equal("custom.topic")
  event.source |> should.equal(option.None)
}

pub fn topic_matcher_matches_test() {
  let event =
    webhook_trigger.custom_event("my.topic", dynamic.string("data"), 1000)
  let matcher = webhook_trigger.TopicMatcher("my.topic")
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn topic_matcher_no_match_test() {
  let event =
    webhook_trigger.custom_event("my.topic", dynamic.string("data"), 1000)
  let matcher = webhook_trigger.TopicMatcher("other.topic")
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(False)
}

pub fn source_matcher_matches_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher = webhook_trigger.SourceMatcher("github")
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn source_matcher_no_source_test() {
  let event =
    webhook_trigger.custom_event("topic", dynamic.string("data"), 1000)
  let matcher = webhook_trigger.SourceMatcher("github")
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(False)
}

pub fn any_matcher_first_matches_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher =
    webhook_trigger.AnyMatcher([
      webhook_trigger.TopicMatcher("github.push"),
      webhook_trigger.TopicMatcher("other.topic"),
    ])
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn any_matcher_second_matches_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher =
    webhook_trigger.AnyMatcher([
      webhook_trigger.TopicMatcher("other.topic"),
      webhook_trigger.SourceMatcher("github"),
    ])
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn any_matcher_no_match_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher =
    webhook_trigger.AnyMatcher([
      webhook_trigger.TopicMatcher("other.topic"),
      webhook_trigger.TopicMatcher("another.topic"),
    ])
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(False)
}

pub fn all_matcher_all_match_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher =
    webhook_trigger.AllMatcher([
      webhook_trigger.TopicMatcher("github.push"),
      webhook_trigger.SourceMatcher("github"),
    ])
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn all_matcher_one_fails_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher =
    webhook_trigger.AllMatcher([
      webhook_trigger.TopicMatcher("github.push"),
      webhook_trigger.SourceMatcher("gitlab"),
    ])
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(False)
}

pub fn custom_matcher_predicate_true_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher = webhook_trigger.CustomMatcher(fn(_e) { True })
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(True)
}

pub fn custom_matcher_predicate_false_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let matcher = webhook_trigger.CustomMatcher(fn(_e) { False })
  webhook_trigger.matcher_matches(matcher, event) |> should.equal(False)
}

pub fn trigger_matches_webhook_trigger_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let trigger = webhook_trigger.on_github_push()
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn trigger_matches_no_trigger_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  webhook_trigger.trigger_matches(webhook_trigger.NoTrigger, event)
  |> should.equal(False)
}

pub fn trigger_matches_manual_trigger_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  webhook_trigger.trigger_matches(webhook_trigger.ManualTrigger, event)
  |> should.equal(False)
}

pub fn on_github_push_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let trigger = webhook_trigger.on_github_push()
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn on_github_pr_test() {
  let event = webhook_trigger.github_pr_event("repo", 1, "opened", 1000)
  let trigger = webhook_trigger.on_github_pr()
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn on_github_event_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let trigger = webhook_trigger.on_github_event()
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn on_topic_test() {
  let event =
    webhook_trigger.custom_event("custom.deploy", dynamic.string("data"), 1000)
  let trigger = webhook_trigger.on_topic("custom.deploy")
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn on_source_test() {
  let event = webhook_trigger.gitlab_push_event("proj", "main", "abc", 1000)
  let trigger = webhook_trigger.on_source("gitlab")
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn on_custom_predicate_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let trigger = webhook_trigger.on_custom(fn(e) { e.topic == "github.push" })
  webhook_trigger.trigger_matches(trigger, event) |> should.equal(True)
}

pub fn deduplication_new_event_test() {
  let state = webhook_trigger.new_deduplication_state()
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let #(is_dup, _new_state) = webhook_trigger.check_duplicate(state, event)
  is_dup |> should.equal(False)
}

pub fn deduplication_duplicate_event_test() {
  let state = webhook_trigger.new_deduplication_state()
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let #(_is_dup1, state2) = webhook_trigger.check_duplicate(state, event)
  let #(is_dup2, _state3) = webhook_trigger.check_duplicate(state2, event)
  is_dup2 |> should.equal(True)
}

pub fn deduplication_no_event_id_test() {
  let state = webhook_trigger.new_deduplication_state()
  let event =
    webhook_trigger.custom_event("topic", dynamic.string("data"), 1000)
  let #(is_dup, _new_state) = webhook_trigger.check_duplicate(state, event)
  is_dup |> should.equal(False)
}

pub fn deduplication_stale_event_test() {
  let state = webhook_trigger.new_deduplication_state()
  let event1 = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let #(_is_dup1, state2) = webhook_trigger.check_duplicate(state, event1)
  // Event with same ID but much later timestamp (beyond max_age_ms)
  let event2 =
    webhook_trigger.github_push_event("repo", "main", "abc", 5_000_000)
  let #(is_dup2, _state3) = webhook_trigger.check_duplicate(state2, event2)
  is_dup2 |> should.equal(False)
}

pub fn cleanup_stale_events_test() {
  let state = webhook_trigger.new_deduplication_state()
  let event1 = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let #(_is_dup1, state2) = webhook_trigger.check_duplicate(state, event1)
  let cleaned_state = webhook_trigger.cleanup_stale_events(state2, 5_000_000)
  dict.size(cleaned_state.seen_ids) |> should.equal(0)
}

pub fn event_description_with_source_test() {
  let event = webhook_trigger.github_push_event("repo", "main", "abc", 1000)
  let desc = webhook_trigger.event_description(event)
  desc |> should.equal("github:github.push")
}

pub fn event_description_no_source_test() {
  let event =
    webhook_trigger.custom_event("custom.topic", dynamic.string("data"), 1000)
  let desc = webhook_trigger.event_description(event)
  desc |> should.equal("custom.topic")
}
