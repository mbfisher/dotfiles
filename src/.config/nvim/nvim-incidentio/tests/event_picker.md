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
  - `[S]` `server/integrations/sentry/resource/consume_sentry_webhook_received.go:41`
    (handler definition — browse-all shows handler defs for named handlers)
- **Must NOT include:** handler function definitions at handle_sentry.go:57 or
  handle_sentry_metric.go:49 — those files already have inline subscribe calls for
  the same event

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

### 11. Filter cycle

- **Open picker** for any event with `gE`
- **Invoke** `toggle_event_filter` action 3 times (or `<C-i>` in a real terminal)
- **Expected cycle:** All → Publishers only (count = pubs) → Subscribers only (count = subs) → All
  (count = pubs + subs)
