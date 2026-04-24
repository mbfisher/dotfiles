# API Picker Tests

Tests for the API picker (`<leader>sA`), goto counterpart (`gA`), and `<C-i>` filter toggle.

## Setup

Source the plugin and call `require("incidentio").setup()` before running tests.
Invalidate cached modules between test runs with:
```lua
package.loaded["incidentio.api_picker"] = nil
package.loaded["incidentio"] = nil
```

## Test Cases

### 1. Browse all APIs

- **From:** Any file
- **Trigger:** `<leader>sA`
- **Expected:** Picker opens with `[D]` (design) and `[I]` (impl) prefixed items

### 2. Design → implementation jump

- **Navigate to:** `server/api/design/incidents_public_service_v2.go:24` — cursor on
  `Method("List"`
- **Trigger:** `gA`
- **Expected:** Jumps to `server/app/legacy/incident/api/api_incidents_v2.go:129`

### 3. Implementation → design jump

- **Navigate to:** `server/app/legacy/incident/api/api_incidents_v2.go:129` — cursor on
  `func ... List(`
- **Trigger:** `gA`
- **Expected:** Jumps back to design file at the `Method("List"` declaration

### 4. Versioned service (V2)

- **Navigate to:** `server/api/design/workflows_service_public_v2.go:8`
- **Trigger:** `<leader>sA`, filter to this service
- **Expected:** Methods listed with correct service name

### 5. Versioned service (V3)

- **Navigate to:** `server/api/design/catalog_service_public_v3.go:8`
- **Trigger:** `<leader>sA`, filter to this service
- **Expected:** Methods listed with correct service name

### 6. Design file with many methods

- **Navigate to:** `server/api/design/schedules_service.go`
- **Trigger:** `<leader>sA`, filter to "Schedules"
- **Expected:** 100+ methods listed in picker

### 7. Filter cycle

- **Trigger:** `<leader>sA` to open picker
- **Invoke** `toggle_api_filter` action 3 times (or `<C-i>` in a real terminal)
- **Expected cycle:** All → Design only → Impl only → All

### 8. PagerDuty webhook: design → implementation

- **Navigate to:** `server/api/design/integration_webhooks_service.go:236` — cursor on
  `Method("PagerDuty"`
- **Trigger:** `gA`
- **Expected:** Jumps to `server/api/api_webhooks_pagerduty.go:39`

### 9. PagerDuty webhook: implementation → design

- **Navigate to:** `server/api/api_webhooks_pagerduty.go:39` — cursor on `func ... PagerDuty(`
- **Trigger:** `gA`
- **Expected:** Jumps to `server/api/design/integration_webhooks_service.go:236`
