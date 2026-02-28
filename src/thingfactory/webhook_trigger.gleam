/// Webhook and external event trigger support for pipelines.
///
/// This module enables pipelines to be triggered by external events via webhooks.
/// Common use cases:
///   - GitHub webhook on push/PR (CI/CD)
///   - Custom API webhooks for event-driven pipelines
///   - Integration with external services (Slack, monitoring systems, etc.)
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// A webhook event from an external system.
pub type WebhookEvent {
  WebhookEvent(
    topic: String,
    payload: Dynamic,
    source: Option(String),
    event_id: Option(String),
    timestamp_ms: Int,
  )
}

/// Matcher for webhook events — determines if a webhook triggers a pipeline.
pub type WebhookMatcher {
  TopicMatcher(topic: String)
  SourceMatcher(source: String)
  AnyMatcher(matchers: List(WebhookMatcher))
  AllMatcher(matchers: List(WebhookMatcher))
  CustomMatcher(fn(WebhookEvent) -> Bool)
}

/// Trigger configuration for when a pipeline should execute.
pub type Trigger {
  NoTrigger
  WebhookTrigger(matcher: WebhookMatcher)
  ManualTrigger
}

/// Check if a webhook event matches a trigger configuration.
pub fn trigger_matches(trigger: Trigger, event: WebhookEvent) -> Bool {
  case trigger {
    NoTrigger -> False
    WebhookTrigger(matcher) -> matcher_matches(matcher, event)
    ManualTrigger -> False
  }
}

/// Check if a webhook event matches a specific matcher.
pub fn matcher_matches(matcher: WebhookMatcher, event: WebhookEvent) -> Bool {
  case matcher {
    TopicMatcher(topic) -> event.topic == topic
    SourceMatcher(source) -> {
      case event.source {
        Some(src) -> src == source
        None -> False
      }
    }
    AnyMatcher(matchers) -> {
      list.any(matchers, fn(m) { matcher_matches(m, event) })
    }
    AllMatcher(matchers) -> {
      list.all(matchers, fn(m) { matcher_matches(m, event) })
    }
    CustomMatcher(predicate) -> predicate(event)
  }
}

/// Create a GitHub push event webhook.
pub fn github_push_event(
  repo: String,
  branch: String,
  commit_sha: String,
  timestamp_ms: Int,
) -> WebhookEvent {
  WebhookEvent(
    topic: "github.push",
    payload: dynamic.string(repo <> ":" <> branch),
    source: Some("github"),
    event_id: Some(commit_sha),
    timestamp_ms: timestamp_ms,
  )
}

/// Create a GitHub pull request event webhook.
pub fn github_pr_event(
  repo: String,
  pr_number: Int,
  _action: String,
  timestamp_ms: Int,
) -> WebhookEvent {
  WebhookEvent(
    topic: "github.pull_request",
    payload: dynamic.string(repo <> "#" <> int.to_string(pr_number)),
    source: Some("github"),
    event_id: Some("pr_" <> int.to_string(pr_number)),
    timestamp_ms: timestamp_ms,
  )
}

/// Create a custom generic webhook event.
pub fn custom_event(
  topic: String,
  payload: Dynamic,
  timestamp_ms: Int,
) -> WebhookEvent {
  WebhookEvent(
    topic: topic,
    payload: payload,
    source: None,
    event_id: None,
    timestamp_ms: timestamp_ms,
  )
}

/// Create a GitLab push event webhook.
pub fn gitlab_push_event(
  project: String,
  branch: String,
  commit_sha: String,
  timestamp_ms: Int,
) -> WebhookEvent {
  WebhookEvent(
    topic: "gitlab.push",
    payload: dynamic.string(project <> ":" <> branch),
    source: Some("gitlab"),
    event_id: Some(commit_sha),
    timestamp_ms: timestamp_ms,
  )
}

/// Create a webhook trigger for GitHub push events.
pub fn on_github_push() -> Trigger {
  WebhookTrigger(TopicMatcher("github.push"))
}

/// Create a webhook trigger for GitHub PR events.
pub fn on_github_pr() -> Trigger {
  WebhookTrigger(TopicMatcher("github.pull_request"))
}

/// Create a webhook trigger for any GitHub event.
pub fn on_github_event() -> Trigger {
  WebhookTrigger(SourceMatcher("github"))
}

/// Create a webhook trigger for a specific topic.
pub fn on_topic(topic: String) -> Trigger {
  WebhookTrigger(TopicMatcher(topic))
}

/// Create a webhook trigger for a specific source.
pub fn on_source(source: String) -> Trigger {
  WebhookTrigger(SourceMatcher(source))
}

/// Create a webhook trigger with custom matching logic.
pub fn on_custom(predicate: fn(WebhookEvent) -> Bool) -> Trigger {
  WebhookTrigger(CustomMatcher(predicate))
}

/// Deduplication state for webhook events.
pub type DeduplicationState {
  DeduplicationState(seen_ids: Dict(String, Int), max_age_ms: Int)
}

/// Create a new deduplication state.
pub fn new_deduplication_state() -> DeduplicationState {
  DeduplicationState(seen_ids: dict.new(), max_age_ms: 3_600_000)
}

/// Check if a webhook event has already been processed (deduplication).
pub fn check_duplicate(
  state: DeduplicationState,
  event: WebhookEvent,
) -> #(Bool, DeduplicationState) {
  case event.event_id {
    None -> #(False, state)
    Some(event_id) -> {
      case dict.get(state.seen_ids, event_id) {
        Ok(old_timestamp) -> {
          let age_ms = event.timestamp_ms - old_timestamp
          let is_stale = age_ms > state.max_age_ms
          #(
            !is_stale,
            DeduplicationState(
              ..state,
              seen_ids: dict.insert(
                state.seen_ids,
                event_id,
                event.timestamp_ms,
              ),
            ),
          )
        }
        Error(Nil) -> {
          #(
            False,
            DeduplicationState(
              ..state,
              seen_ids: dict.insert(
                state.seen_ids,
                event_id,
                event.timestamp_ms,
              ),
            ),
          )
        }
      }
    }
  }
}

/// Clean up old event IDs from deduplication state.
pub fn cleanup_stale_events(
  state: DeduplicationState,
  current_timestamp_ms: Int,
) -> DeduplicationState {
  let filtered_ids =
    dict.filter(state.seen_ids, fn(_, old_timestamp) {
      current_timestamp_ms - old_timestamp <= state.max_age_ms
    })
  DeduplicationState(..state, seen_ids: filtered_ids)
}

/// Get a human-readable description of a webhook event.
pub fn event_description(event: WebhookEvent) -> String {
  let source_str = case event.source {
    Some(src) -> src <> ":"
    None -> ""
  }
  source_str <> event.topic
}
