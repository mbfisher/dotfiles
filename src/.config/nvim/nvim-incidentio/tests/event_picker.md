# Event Picker Tests

Tests for the event picker (`gE`) and its `<C-i>` filter toggle.

## Setup

Source the plugin and call `require("incidentio").setup()` before running tests.
Invalidate cached modules between test runs with:
```lua
package.loaded["incidentio.event_picker"] = nil
package.loaded["incidentio"] = nil
```

## Test Cases

### 1. Event with many subscribers

- **Navigate to:** `server/pkg/event/incident_made_private.go:18` — cursor on `IncidentMadePrivate`
- **Trigger:** `gE`
- **Expected:** Picker opens with 1+ `[P]` items and 7+ `[S]` items

### 2. Single publisher and subscriber

- **Navigate to:** `server/pkg/event/cron_sweep_old_nudge_run_transitions.go:9` — cursor on
  `CronSweepOldNudgeRunTransitions`
- **Trigger:** `gE`
- **Expected:** 1 `[P]` item, 1 `[S]` item

### 3. No subscribers

- **Navigate to:** `server/pkg/event/apikey_created.go:13` — cursor on `APIKeyCreated`
- **Trigger:** `gE`
- **Expected:** 1+ `[P]` items, 0 `[S]` items

### 4. subscribeLowPriority variant

- **Navigate to:** `server/pkg/event/cron_sweep_old_nudge_run_transitions.go:9` — cursor on
  `CronSweepOldNudgeRunTransitions`
- **Trigger:** `gE`
- **Expected:** The subscriber item text contains `subscribeLowPriority`

### 5. Cursor on event reference (not definition)

- **Navigate to:** `server/app/oncall/alert/subscriber_alert_resolved.go:41` — cursor on
  `AlertResolved` within `*event.AlertResolved`
- **Trigger:** `gE`
- **Expected:** Same results as triggering from `server/pkg/event/alert_resolved.go`

### 6. Bare identifier in struct definition

- **Navigate to:** `server/pkg/event/apikey_created.go:13` — cursor on the word `APIKeyCreated` in
  `type APIKeyCreated struct`
- **Trigger:** `gE`
- **Expected:** Picker opens for that event (falls back to `<cword>`)

### 7. Multiple event types in one file

- **Navigate to:** `server/app/followup/subscriber_publish_auto_export_request.go:31` — cursor on
  `FollowUpChanged`
- **Trigger:** `gE`
- **Expected:** Results for `FollowUpChanged`
- **Then navigate to:** line 65 — cursor on `IncidentUpdated`
- **Trigger:** `gE`
- **Expected:** Different results (for `IncidentUpdated`)

### 8. Browse all events (leader sE)

- **Trigger:** `<leader>sE`, type `SentryWebhookReceived`
- **Expected:** Exactly 5 items:
  - `[E]` `server/pkg/event/sentry_webhook_received.go:12`
  - `[P]` `server/api/api_webhooks_sentry.go:65`
  - `[S]` `server/app/oncall/alert/incoming/handle_sentry_metric.go:23` (inline subscribe)
  - `[S]` `server/app/oncall/alert/incoming/handle_sentry.go:27` (inline subscribe)
  - `[S]` `server/integrations/sentry/resource/service.go:37`
    (`eventadapter.Subscribe(…, s.ConsumeSentryWebhookReceived, …)` — traced back from
    the named handler at `consume_sentry_webhook_received.go`)
- **Must NOT include:** handler function definitions like `ConsumeSentryWebhookReceived`,
  `handleSentryWebhook`, `handleSentryMetricWebhook` — every subscriber must point to the
  `subscribe(...)` / `Subscribe(...)` call site, not the func body.

### 9. Cursor-scoped event picker with method receiver subscriber (gE)

- **Navigate to:** `server/pkg/event/sentry_webhook_received.go:12` — cursor on `SentryWebhookReceived`
- **Trigger:** `gE`
- **Expected:** Exactly 5 items: 1 `[E]`, 1 `[P]`, 3 `[S]`
  - The `[S]` items should point to subscribe() call sites, not handler definitions
  - Must include `server/integrations/sentry/resource/service.go:37` (eventadapter.Subscribe
    with method receiver `s.ConsumeSentryWebhookReceived`)

### 10. No generated matcher methods in results

- **Trigger:** `<leader>sE`, type `MicrosoftTeamsAppInstalledTeam`
- **Expected:** No items from `server/pkg/event/matchers/` — generated matcher methods
  like `OrganisationID()`, `MicrosoftTeamsTeamID()` that return `func(*event.XXX, ...)`
  are NOT subscribers. Only real handler functions (with `ev *event.XXX` as a parameter)
  should appear.
- **Verify via find_all():** filter items where `event_name == "MicrosoftTeamsAppInstalledTeam"`
  and assert none have a file path containing `/matchers/`

### 11. Named handler traced back to subscribe call site

- **Navigate to:** `server/app/oncall/alert/enqueue_handle_event.go:168` — cursor on `AlertHandleEvent`
- **Trigger:** `gE`
- **Expected:** Exactly 1 `[S]` item pointing to the `subscribe(handleEventFromAsync, …)` call
  (currently around line 274 of `enqueue_handle_event.go`)
- **Must NOT** point to the `func handleEventFromAsync(…)` definition further down.
- **Must NOT include** continuation lines from the trace-back's multiline rg match
  (`SubscribeParams{`, `SubscriberID:`, etc.) — only the `subscribe(` line.

### 12. Prefixed event package (e.g. `oncallevent`)

- **Navigate to:** `server/app/oncall/escalator/executor/transition_notification.go:40` — cursor on
  `EscalationNotificationTransition` in `&oncallevent.EscalationNotificationTransition{`
- **Trigger:** `gE`
- **Expected:** Picker contains named-handler subscribers from other files like
  `subscriber_invite_paged_user.go`, `subscriber_expire_sms_callbacks.go`,
  `subscriber_workflows_trigger_escalation_acked.go`.
- **Regression guard:** Subscriber matching must not require the package import to be literally
  named `event` — prefixed packages like `oncallevent`, `pkgevent`, `aievent` must also work
  (the rg patterns must allow a `\w*` prefix before `event\.`).

### 13. Multi-line inline subscribe call

- **Navigate to:** `server/app/oncall/escalator/executor/transition_notification.go:40` — cursor on
  `EscalationNotificationTransition`
- **Trigger:** `gE`
- **Expected:** Picker includes `server/app/oncall/escalator/executor/notification_deliver.go:29`,
  where the source is laid out as:
  ```
  29:		subscribe(
  30:			func(ctx context.Context, db *gorm.DB, ev *oncallevent.EscalationNotificationTransition, ...) error {
  ```
  i.e. `subscribe(` and the `*oncallevent.X` arg are on different lines.
- **Regression guard:** `parse_inline_subscribers` must correlate the `subscribe(` row with the
  `*event.X` row from the same multi-line rg match block (same file, sequential line numbers).
  A naive line-by-line parser would drop this match because neither row alone contains both
  `subscribe(` and `event.X`. The reported line must be the `subscribe(` line (29), not the
  `func(...)` continuation line.

### 14. Named handler in same file as subscribe call (trace-back picks the right call)

- **Navigate to:** `server/app/oncall/escalator/executor/transition_notification.go:40` — cursor on
  `EscalationNotificationTransition`
- **Trigger:** `gE`
- **Expected:** Picker includes `server/app/ai/plugin/subscriber_upsert_desktop_marker.go:33` —
  the `subscribe(onEscalationNotificationTransition, …)` call.
- **Layout under test:** that file contains TWO back-to-back subscribe calls in the same
  `init()`:
  ```
  25:	subscribe(onUserChanged, …)
  …
  33:	subscribe(onEscalationNotificationTransition, …)
  ```
  Both end up in one rg multi-line match block when tracing back the handler. The parser
  must pair each `func_name` occurrence with the *closest preceding* `subscribe(` row in
  the block, not just the first one. Reporting line 25 would be wrong (that's the
  `onUserChanged` subscribe).

### 15. Filter cycle

- **Open picker** for any event with `gE`
- **Invoke** `toggle_event_filter` action 3 times (or `<C-i>` in a real terminal)
- **Expected cycle:** All → Publishers only (count = pubs) → Subscribers only (count = subs) → All
  (count = pubs + subs)
