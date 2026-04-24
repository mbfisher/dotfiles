# Picker Abstraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple nvim-incidentio from snacks.nvim and which-key.nvim so it can be distributed as a standalone plugin supporting multiple picker backends.

**Architecture:** Separate finding logic (api.lua, events.lua) from picker presentation (pickers/snacks.lua, pickers/telescope.lua). A dispatcher (picker.lua) resolves the backend from config and errors helpfully if no picker is installed. Events exposes granular rg command builders and parsers so the snacks adapter can run searches in parallel, while telescope calls the sync find_all(). The plugin does not register keymaps — users wire up keys via lazy.nvim `keys`, `vim.keymap.set`, or whatever their plugin manager provides. The README documents the four public API functions and provides copy-paste keymap examples.

**Tech Stack:** Neovim Lua, ripgrep, snacks.nvim (primary), telescope.nvim (secondary)

---

## File Structure

All paths relative to `lua/incidentio/`.

| File | Action | Responsibility |
|------|--------|----------------|
| `config.lua` | Create | Store resolved plugin options (just `picker` setting) |
| `api.lua` | Create (from `api_picker.lua`) | API search logic, badge/filter constants, goto_counterpart |
| `events.lua` | Create (from `event_picker.lua`) | Event search logic, granular rg builders/parsers, badge/filter constants |
| `picker.lua` | Create | Resolve backend, dispatch to adapter, convenience functions, error if no picker |
| `pickers/snacks.lua` | Create | Snacks adapter: format, filter cycling, async parallel find_all |
| `pickers/telescope.lua` | Create | Telescope adapter: entry display, filter cycling, sync find_all |
| `init.lua` | Rewrite | Minimal: just setup(opts) delegating to config |
| `api_picker.lua` | Delete | Replaced by api.lua + pickers/ |
| `event_picker.lua` | Delete | Replaced by events.lua + pickers/ |

---

### Task 1: Create config.lua

**Files:**
- Create: `lua/incidentio/config.lua`

- [ ] **Step 1: Create config.lua**

```lua
-- Plugin configuration: stores resolved options for other modules to read.
--
-- Options:
--   picker — "snacks" | "telescope" | "auto" (default: "auto")

local M = {}

M.defaults = {
  picker = "auto",
}

-- Active options, updated by setup()
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/config.lua
git commit -m "Add config.lua for plugin options"
```

---

### Task 2: Extract api.lua from api_picker.lua

Extract the search/finding logic from `api_picker.lua` into `api.lua`. This file has no picker dependency — it returns plain Lua tables. Badge definitions and filter mode constants move here so both picker adapters can reference them.

`goto_counterpart()` stays here since it's direct navigation (vim.cmd), not a picker operation.

**Files:**
- Create: `lua/incidentio/api.lua`

- [ ] **Step 1: Create api.lua**

```lua
-- API navigation: search logic for Goa design files and their Go implementations.
--
-- Public API:
--   api.find_all()         — returns all design + impl items as a flat list
--   api.goto_counterpart() — jump between design and impl for method under cursor
--   api.badges             — icon/hl definitions for picker adapters
--   api.filter_modes       — filter mode names for <C-i> cycling
--   api.filter_labels      — human-readable labels for each filter mode
--
-- How it works:
--   1. Parse design files for Service/Method declarations (including ServicePublicV1/V2/V3).
--   2. Derive each service's gen package directory name (e.g. "Alert Events" + v2 -> alert_events_v2).
--   3. Find implementation files by searching server/app/, server/api/, and server/integrations/
--      (excluding gen/) for files that import a known gen package, then matching receiver method
--      definitions in those files back to the design Method names.
--   4. For goto_counterpart, use the nearest Method declaration at or above the cursor to
--      determine which method the user is in.

local M = {}

-- Badge definitions for picker adapters to render per-item icons
M.badges = {
  design = { icon = " \u{F1FC} ", hl = "DiagnosticInfo" },    -- nf-fa-paint_brush
  impl   = { icon = " \u{F121} ", hl = "DiagnosticHint" },    -- nf-fa-code
}

-- Filter modes for <C-i> cycling in pickers
M.filter_modes = { "all", "design", "impl" }
M.filter_labels = { all = "All", design = "Design only", impl = "Impl only" }

--- Parse design files to extract Service/Method definitions.
--- Matches Service(), ServicePublicV1/V2/V3() declarations and their Method() children.
--- Returns a list of {service, method, version, file, line} entries,
--- where version is nil for Service() or "v1"/"v2"/"v3" for versioned variants.
local function parse_design_files()
  local design_dir = "server/api/design"
  if vim.fn.isdirectory(design_dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(design_dir .. "/*_service*.go", false, true)
  local entries = {}

  for _, filepath in ipairs(files) do
    local current_service = nil
    local current_version = nil

    local lnum = 0
    for line in io.lines(filepath) do
      lnum = lnum + 1

      local variant, svc_name = line:match('^var%s+_%s*=%s*(Service[^(]*)%("([^"]+)"')
      if svc_name then
        current_service = svc_name
        local ver = variant:match("V(%d+)$")
        current_version = ver and ("v" .. ver) or nil
      end

      if current_service then
        local method_name = line:match('^%s+Method%("([^"]+)"')
        if method_name then
          table.insert(entries, {
            service = current_service,
            method = method_name,
            version = current_version,
            file = filepath,
            line = lnum,
          })
        end
      end
    end
  end

  return entries
end

--- Convert a service name to its gen package directory name.
--- Handles CamelCase, spaces, hyphens, and " - " separators.
--- Appends version suffix for ServicePublicV1/V2/V3.
local function service_to_gen_dir(name, version)
  local s = name
  s = s:gsub(" %- ", " ")
  s = s:gsub("(%l)(%u)", "%1_%2"):gsub("(%u+)(%u%l)", "%1_%2")
  s = s:lower():gsub("[ -]", "_")
  if version then
    s = s .. "_" .. version
  end
  return s
end

--- Build a mapping from gen package directory name to service name.
local function build_gen_to_service_map(design_entries)
  local seen = {}
  local map = {}

  for _, entry in ipairs(design_entries) do
    local skey = entry.service .. "|" .. (entry.version or "")
    if not seen[skey] then
      seen[skey] = true
      map[service_to_gen_dir(entry.service, entry.version)] = entry.service
    end
  end

  return map
end

--- Find implementation files by scanning for gen package imports and method definitions.
--- Returns a lookup table: "Service.Method" -> {file, line}
local function find_implementations(gen_to_service)
  local function rg(pattern)
    return table.concat({
      "rg", "-n", "--no-heading",
      '--glob "*.go"',
      '--glob "!server/api/gen/**"',
      '"' .. pattern .. '"',
      "server/app/", "server/api/", "server/integrations/",
    }, " ")
  end

  local import_output = vim.fn.system(rg("api/gen/"))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local file_to_service = {}
  for line in import_output:gmatch("[^\n]+") do
    local file, import_path = line:match("^([^:]+):%d+:%s*.*\"[^\"]*api/gen/([^\"]+)\"")
    if file and import_path then
      local gen_dir = import_path:match("([^/]+)$") or import_path
      local service_name = gen_to_service[gen_dir]
      if service_name and not file:match("_test%.go$") then
        file_to_service[file] = service_name
      end
    end
  end

  local method_output = vim.fn.system(rg("^func \\("))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local impl_lookup = {}
  for line in method_output:gmatch("[^\n]+") do
    local file, lnum, method_name = line:match("^([^:]+):(%d+):func%s+%([^)]+%)%s+(%w+)%s*%(")
    if file and method_name and file_to_service[file] then
      local service_name = file_to_service[file]
      local key = service_name .. "." .. method_name
      if not impl_lookup[key] then
        impl_lookup[key] = { file = file, line = tonumber(lnum) }
      end
    end
  end

  return impl_lookup
end

--- Build both lookup directions: design->impl and impl->design.
local function build_lookups()
  local design_entries = parse_design_files()
  if #design_entries == 0 then
    return {}, {}, {}
  end

  local gen_to_service = build_gen_to_service_map(design_entries)
  local impl_lookup = find_implementations(gen_to_service)

  local impl_file_methods = {}
  for _, entry in ipairs(design_entries) do
    local key = entry.service .. "." .. entry.method
    local impl = impl_lookup[key]
    if impl then
      if not impl_file_methods[impl.file] then
        impl_file_methods[impl.file] = {}
      end
      table.insert(impl_file_methods[impl.file], {
        impl_line = impl.line,
        method = entry.method,
        service = entry.service,
        design_file = entry.file,
        design_line = entry.line,
      })
    end
  end

  return design_entries, impl_lookup, impl_file_methods
end

--- Return all API items (design + implementation) as a flat list.
--- Each item has: text, method_label, kind ("design"|"impl"), file, pos ({line, col}).
function M.find_all()
  local design_entries = parse_design_files()
  if #design_entries == 0 then
    return {}
  end

  local gen_to_service = build_gen_to_service_map(design_entries)
  local impl_lookup = find_implementations(gen_to_service)

  local items = {}
  for _, entry in ipairs(design_entries) do
    local method_label = entry.service .. "." .. entry.method

    table.insert(items, {
      text = method_label,
      method_label = method_label,
      kind = "design",
      file = entry.file,
      pos = { entry.line, 0 },
    })

    local impl = impl_lookup[method_label]
    if impl then
      table.insert(items, {
        text = method_label,
        method_label = method_label,
        kind = "impl",
        file = impl.file,
        pos = { impl.line, 0 },
      })
    end
  end

  return items
end

--- Resolve a path to absolute, normalizing relative paths against cwd.
local function resolve_path(path)
  return vim.fn.fnamemodify(path, ":p")
end

--- Jump between design and implementation for the API method under the cursor.
--- If in a design file, jump to the implementation; if in an impl file, jump to the design.
function M.goto_counterpart()
  local current_file = resolve_path(vim.fn.expand("%"))
  local current_line = vim.fn.line(".")

  local design_entries, impl_lookup, impl_file_methods = build_lookups()
  if #design_entries == 0 then
    vim.notify("No API design entries found", vim.log.levels.WARN)
    return
  end

  if current_file:match("/server/api/design/") then
    local best_entry = nil
    for _, entry in ipairs(design_entries) do
      if resolve_path(entry.file) == current_file and entry.line <= current_line then
        if not best_entry or entry.line > best_entry.line then
          best_entry = entry
        end
      end
    end

    if best_entry then
      local key = best_entry.service .. "." .. best_entry.method
      local impl = impl_lookup[key]
      if impl then
        vim.cmd("edit " .. vim.fn.fnameescape(impl.file))
        vim.api.nvim_win_set_cursor(0, { impl.line, 0 })
        return
      else
        vim.notify("No implementation found for " .. key, vim.log.levels.WARN)
        return
      end
    end

    vim.notify("No API method found at cursor position (line " .. current_line .. ")", vim.log.levels.WARN)
    return
  end

  local methods = nil
  for file, file_methods in pairs(impl_file_methods) do
    if resolve_path(file) == current_file then
      methods = file_methods
      break
    end
  end

  if methods then
    local best = nil
    for _, m in ipairs(methods) do
      if m.impl_line <= current_line then
        if not best or m.impl_line > best.impl_line then
          best = m
        end
      end
    end

    if best then
      vim.cmd("edit " .. vim.fn.fnameescape(best.design_file))
      vim.api.nvim_win_set_cursor(0, { best.design_line, 0 })
      return
    end
  end

  vim.notify("Not in an API design or implementation file", vim.log.levels.WARN)
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/api.lua
git commit -m "Extract api.lua from api_picker.lua (finding logic only)"
```

---

### Task 3: Extract events.lua from event_picker.lua

Extract event search logic into `events.lua`. The key design decision: expose both a high-level sync API (`find`, `find_all`) and low-level building blocks (`cmd_*`, `parse_*`) so the snacks adapter can orchestrate parallel rg searches.

The `find(event_name)` function includes the subscribe trace-back step (extra rg per handler) which is only practical for single-event queries. `find_all()` skips the trace-back — it shows handler definitions directly.

**Files:**
- Create: `lua/incidentio/events.lua`

- [ ] **Step 1: Create events.lua**

```lua
-- Event search: find domain events with their publishers and subscribers.
--
-- Public API:
--   events.find(event_name)         — all refs for one event (sync, includes subscribe trace-back)
--   events.find_all()               — all events (sync, serial, no trace-back)
--   events.event_name_under_cursor() — extract event name at cursor position
--   events.badges / filter_modes / filter_labels — constants for picker adapters
--
-- Building blocks for parallel execution (used by snacks adapter):
--   events.cmd_definitions()          — rg command string for all definitions
--   events.cmd_publishers()           — rg command string for all publishers
--   events.cmd_inline_subscribers()   — rg command string for all inline subscribers
--   events.cmd_named_handlers()       — rg command string for all named handler defs
--   events.parse_definitions(output)  — parse rg output into def items
--   events.parse_publishers(output)   — parse rg output into pub items
--   events.parse_inline_subscribers(output) — parse into sub items + seen sets for dedup
--   events.parse_named_handlers(output, seen, seen_file_events) — parse into sub items (deduped)
--
-- Search strategy:
--   Definitions: rg for `type XXX struct` in **/event/*.go package files.
--   Publishers: rg for `event.{Name}{` struct literals (arg to eventadapter.Publish).
--   Subscribers (two-phase):
--     a. Inline: multiline match for subscribe() with *event.{Name} in function args
--     b. Named: handler functions accepting *event.{Name}, then trace back to subscribe() call
--   Handles subscribe() variants with suffixes (e.g. subscribeLowPriority).

local M = {}

-- Badge definitions for picker adapters to render per-item icons
M.badges = {
  def = { icon = " \u{F140B} ", hl = "DiagnosticInfo" },    -- nf-md-lightning_bolt
  pub = { icon = " \u{F10DD} ", hl = "DiagnosticWarn" },    -- nf-md-email_send_outline
  sub = { icon = " \u{F02FB} ", hl = "DiagnosticHint" },    -- nf-md-inbox_arrow_down
}

-- Filter modes for <C-i> cycling in pickers
M.filter_modes = { "all", "def", "pub", "sub" }
M.filter_labels = { all = "All", def = "Definitions only", pub = "Publishers only", sub = "Subscribers only" }

--- Common rg flags: Go files, excluding tests and generated event matchers.
local rg_glob = "-g '*.go' -g '!*_test.go' -g '!**/event/matchers/**'"

--- Restrict to event package files (where domain event structs are defined).
local rg_event_def_glob = "-g '**/event/*.go' -g '!*_test.go'"

--- Search dirs within the repo — all non-generated server code.
local search_dirs = { "server/app/", "server/pkg/", "server/integrations/", "server/cmd/", "server/api/", "server/slack/" }
local dir_str = table.concat(search_dirs, " ")

--- Build an rg command string with standard globs (does not execute it).
local function rg_cmd(args)
  return "rg -Hn --no-heading " .. rg_glob .. " " .. args
end

--- Build an rg command string restricted to event package files.
local function rg_event_def_cmd(args)
  return "rg -Hn --no-heading " .. rg_event_def_glob .. " " .. args
end

--- Run rg synchronously and return raw output (empty string on failure).
local function rg_raw(args)
  local output = vim.fn.system(rg_cmd(args))
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return output
end

--- Run rg restricted to event package files.
local function rg_event_defs(args)
  local output = vim.fn.system(rg_event_def_cmd(args))
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return output
end

--- Parse rg output lines into {file, line, text} tables.
local function parse_rg(output)
  local results = {}
  for line in output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file then
      table.insert(results, { file = file, line = tonumber(lnum), text = vim.trim(text) })
    end
  end
  return results
end

--- Extract event name from a code line containing event.XXX references.
local function extract_event_name(text)
  return text:match("event%.(%w+)")
end

--- Build a picker item with consistent fields for display and search.
local function make_item(kind, event_name, code, file, line)
  return {
    text = event_name,
    event_name = event_name,
    code = code,
    kind = kind,
    file = file,
    pos = { line, 0 },
  }
end

--- Get the event type name under the cursor.
--- Handles both `event.AlertResolved` references and bare `AlertResolved` in
--- struct definitions. Returns nil if no word found.
function M.event_name_under_cursor()
  local cword = vim.fn.expand("<cWORD>")
  local name = cword:match("event%.(%w+)")
  if name then
    return name
  end
  return vim.fn.expand("<cword>")
end

-- ── rg command builders (for parallel execution by snacks adapter) ──────────

--- rg command for all event definitions.
function M.cmd_definitions()
  return rg_event_def_cmd("'^type \\w+ struct' server/")
end

--- rg command for all event publishers.
function M.cmd_publishers()
  return rg_cmd("'event\\.\\w+\\{' " .. dir_str)
end

--- rg command for all inline subscribers (multiline match for subscribe + event type).
function M.cmd_inline_subscribers()
  return rg_cmd(
    "--multiline --multiline-dotall "
      .. "'[Ss]ubscribe\\w*\\([\\s\\S]{0,300}\\*event\\.\\w+[,)]' "
      .. dir_str
  )
end

--- rg command for all named handler function definitions accepting an event type.
function M.cmd_named_handlers()
  return rg_cmd("'^func\\b.*\\s\\*event\\.\\w+[,)]' " .. dir_str)
end

-- ── Parsers (take rg output string, return items) ──────────────────────────

--- Parse definition rg output into items.
function M.parse_definitions(output)
  local items = {}
  for _, hit in ipairs(parse_rg(output)) do
    local name = hit.text:match("^type (%w+) struct")
    if name then
      table.insert(items, make_item("def", name, nil, hit.file, hit.line))
    end
  end
  return items
end

--- Parse publisher rg output into items.
function M.parse_publishers(output)
  local items = {}
  for _, hit in ipairs(parse_rg(output)) do
    local name = extract_event_name(hit.text)
    if name then
      table.insert(items, make_item("pub", name, hit.text, hit.file, hit.line))
    end
  end
  return items
end

--- Parse inline subscriber rg output into items.
--- Returns (items, seen_lines, seen_file_events) — the seen sets are needed
--- by parse_named_handlers for deduplication.
function M.parse_inline_subscribers(output)
  local items = {}
  local seen_lines = {}
  local seen_file_events = {}
  for line in output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file and text:match("[Ss]ubscribe") then
      local key = file .. ":" .. lnum
      if not seen_lines[key] then
        seen_lines[key] = true
        local name = extract_event_name(text)
        if name then
          seen_file_events[file .. ":" .. name] = true
          table.insert(items, make_item("sub", name, vim.trim(text), file, tonumber(lnum)))
        end
      end
    end
  end
  return items, seen_lines, seen_file_events
end

--- Parse named handler rg output into items, deduplicating against inline subscribers.
--- seen_lines and seen_file_events should come from parse_inline_subscribers.
function M.parse_named_handlers(output, seen_lines, seen_file_events)
  local items = {}
  for line in output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file then
      local name = extract_event_name(text)
      if name and not seen_file_events[file .. ":" .. name] then
        local key = file .. ":" .. lnum
        if not seen_lines[key] then
          seen_lines[key] = true
          table.insert(items, make_item("sub", name, vim.trim(text), file, tonumber(lnum)))
        end
      end
    end
  end
  return items
end

-- ── High-level sync API ────────────────────────────────────────────────────

--- Find definition, publishers, and subscribers of the given event name.
--- Includes subscribe trace-back for named handlers (extra rg per handler).
--- Returns a flat list of items tagged with kind="def"/"pub"/"sub".
function M.find(event_name)
  local items = {}

  -- Definitions
  local defs = parse_rg(rg_event_defs("'^type " .. event_name .. " struct' server/"))
  for _, hit in ipairs(defs) do
    table.insert(items, make_item("def", event_name, nil, hit.file, hit.line))
  end

  -- Publishers
  local pubs = parse_rg(rg_raw("'event\\." .. event_name .. "\\{' " .. dir_str))
  for _, hit in ipairs(pubs) do
    table.insert(items, make_item("pub", event_name, hit.text, hit.file, hit.line))
  end

  -- Subscribers phase 1: inline anonymous functions passed to subscribe()
  local inline_output = rg_raw(
    "--multiline --multiline-dotall "
      .. "'[Ss]ubscribe\\w*\\([\\s\\S]{0,300}\\*event\\."
      .. event_name
      .. "[,)]' "
      .. dir_str
  )
  local seen = {}
  for line in inline_output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file and text:match("[Ss]ubscribe") then
      local key = file .. ":" .. lnum
      if not seen[key] then
        seen[key] = true
        table.insert(items, make_item("sub", event_name, vim.trim(text), file, tonumber(lnum)))
      end
    end
  end

  -- Subscribers phase 2: named handler functions, traced back to subscribe() call
  local def_output = rg_raw("'^func\\b.*\\s\\*event\\." .. event_name .. "[,)]' " .. dir_str)
  for line in def_output:gmatch("[^\n]+") do
    local file, _, func_name = line:match("^([^:]+):(%d+):func%s+(%w+)%(")
    if not func_name then
      file, _, func_name = line:match("^([^:]+):(%d+):func%s+%([^)]+%)%s+(%w+)%(")
    end
    if func_name then
      local pkg_dir = file:match("^(.*/)")
      local sub_output = rg_raw(
        "--multiline --multiline-dotall '[Ss]ubscribe\\w*\\([\\s\\S]{0,500}\\.?" .. func_name .. "[,)]' " .. pkg_dir
      )
      for sub_line in sub_output:gmatch("[^\n]+") do
        local sf, sl, st = sub_line:match("^([^:]+):(%d+):(.*)")
        if sf and st:match("[Ss]ubscribe%w*%(") and st:match(func_name) then
          local key = sf .. ":" .. sl
          if not seen[key] then
            seen[key] = true
            table.insert(items, make_item("sub", event_name, vim.trim(st), sf, tonumber(sl)))
          end
        end
      end
    end
  end

  return items
end

--- Find all event definitions, publishers, and subscribers (sync, serial).
--- Runs all 4 rg searches sequentially. For parallel execution, use the cmd_* and
--- parse_* building blocks directly (see pickers/snacks.lua).
function M.find_all()
  local items = {}

  local function run(cmd)
    local output = vim.fn.system(cmd)
    return vim.v.shell_error == 0 and output or ""
  end

  vim.list_extend(items, M.parse_definitions(run(M.cmd_definitions())))
  vim.list_extend(items, M.parse_publishers(run(M.cmd_publishers())))

  local inline_items, seen_lines, seen_file_events = M.parse_inline_subscribers(run(M.cmd_inline_subscribers()))
  vim.list_extend(items, inline_items)
  vim.list_extend(items, M.parse_named_handlers(run(M.cmd_named_handlers()), seen_lines, seen_file_events))

  return items
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/events.lua
git commit -m "Extract events.lua from event_picker.lua (finding logic + rg building blocks)"
```

---

### Task 4: Create picker.lua

The dispatcher resolves which backend to use and delegates. If no supported picker is installed and the user hasn't specified one, error with a helpful message.

Also provides `events_pick_at_cursor()` — a convenience wrapper so users don't need boilerplate in their keymap for the cursor-scoped event picker.

**Files:**
- Create: `lua/incidentio/picker.lua`

- [ ] **Step 1: Create picker.lua**

```lua
-- Picker dispatch: resolves the configured backend and delegates to the adapter.
--
-- Public API (these are the functions users bind to keymaps):
--   picker.api_pick()               — open API browser picker
--   picker.events_pick(event_name)  — open event picker for a specific event
--   picker.events_pick_all()        — open browse-all-events picker
--   picker.events_pick_at_cursor()  — open event picker for event under cursor (convenience)
--
-- Adapter interface — each adapter module in pickers/ must export:
--   adapter.api_pick()
--   adapter.events_pick(event_name)
--   adapter.events_pick_all()

local M = {}

--- Resolve and return the picker adapter module.
--- Checks config.options.picker ("snacks", "telescope", or "auto") and
--- returns the corresponding incidentio.pickers.* module.
local function get_adapter()
  local config = require("incidentio.config")
  local picker = config.options.picker

  if picker == "auto" then
    if pcall(require, "snacks") then
      picker = "snacks"
    elseif pcall(require, "telescope") then
      picker = "telescope"
    end
  end

  if not picker or picker == "auto" then
    vim.notify(
      "nvim-incidentio: no supported picker found.\n"
        .. "Install snacks.nvim or telescope.nvim, or set picker in setup():\n"
        .. '  require("incidentio").setup({ picker = "snacks" })',
      vim.log.levels.ERROR
    )
    return nil
  end

  local ok, adapter = pcall(require, "incidentio.pickers." .. picker)
  if not ok then
    vim.notify(
      "nvim-incidentio: failed to load picker adapter '" .. picker .. "': " .. adapter,
      vim.log.levels.ERROR
    )
    return nil
  end

  return adapter
end

function M.api_pick()
  local adapter = get_adapter()
  if adapter then adapter.api_pick() end
end

function M.events_pick(event_name)
  local adapter = get_adapter()
  if adapter then adapter.events_pick(event_name) end
end

function M.events_pick_all()
  local adapter = get_adapter()
  if adapter then adapter.events_pick_all() end
end

--- Convenience: open the event picker for the event under the cursor.
--- Extracts the event name and delegates to events_pick(). Notifies if no
--- event name is found. Use this in keymaps to avoid boilerplate.
function M.events_pick_at_cursor()
  local name = require("incidentio.events").event_name_under_cursor()
  if not name or name == "" then
    vim.notify("No event name under cursor", vim.log.levels.WARN)
    return
  end
  M.events_pick(name)
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/picker.lua
git commit -m "Add picker.lua dispatcher with auto-detection and helpful errors"
```

---

### Task 5: Create pickers/snacks.lua

The primary adapter. Uses `Snacks.picker.format.filename()` for file paths, `snacks.picker.util.async` for parallel rg in `events_pick_all`. Filter cycling uses snacks' custom actions + transform API.

**Files:**
- Create: `lua/incidentio/pickers/snacks.lua`

- [ ] **Step 1: Create pickers directory and snacks.lua**

```lua
-- Snacks picker adapter: full async/parallel support for snacks.nvim.
--
-- This is the primary, native-supported picker backend. It uses snacks.picker.util.async
-- to run event rg searches in parallel, pushing results as each completes.
-- Filter cycling uses snacks' custom actions and transform API.

local M = {}

local api = require("incidentio.api")
local events = require("incidentio.events")

--- Format an API item for snacks picker display.
--- Layout: Badge  Service.Method  icon filepath:line
local function format_api(item, picker)
  local ret = {}
  local badge = api.badges[item.kind] or { icon = " ? ", hl = "Comment" }
  ret[#ret + 1] = { badge.icon, badge.hl }
  ret[#ret + 1] = { " " }
  -- field="text" tells snacks to apply fuzzy match highlights on this segment
  ret[#ret + 1] = { item.method_label or "", nil, field = "text" }
  ret[#ret + 1] = { " " }
  vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
  if item.pos then
    ret[#ret + 1] = { ":" .. item.pos[1], "SnacksPickerRow" }
  end
  return ret
end

--- Format an event item for snacks picker display.
--- Layout: Badge  EventName  icon filepath:line  code_snippet
local function format_event(item, picker)
  local ret = {}
  local badge = events.badges[item.kind] or { icon = " ? ", hl = "Comment" }
  ret[#ret + 1] = { badge.icon, badge.hl }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { item.event_name or "", nil, field = "text" }
  ret[#ret + 1] = { " " }
  vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
  if item.pos then
    ret[#ret + 1] = { ":" .. item.pos[1], "SnacksPickerRow" }
  end
  if item.code then
    ret[#ret + 1] = { "  " .. item.code, "SnacksPickerComment" }
  end
  return ret
end

--- Build snacks picker config for filter cycling.
--- mod must have .filter_modes and .filter_labels tables.
--- state_key is the picker field used to track current filter (e.g. "_api_filter").
--- title_fn(label) returns the picker title for the given filter label.
local function filter_config(mod, state_key, title_fn)
  return {
    actions = {
      toggle_filter = function(picker)
        local modes = mod.filter_modes
        local labels = mod.filter_labels

        local current = picker[state_key] or "all"
        local idx = 1
        for i, m in ipairs(modes) do
          if m == current then
            idx = i
            break
          end
        end
        local next_mode = modes[(idx % #modes) + 1]
        picker[state_key] = next_mode

        if next_mode == "all" then
          picker.opts.transform = nil
        else
          picker.opts.transform = function(item)
            if item.kind ~= next_mode then
              return false
            end
          end
        end

        picker.title = title_fn(labels[next_mode])
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-i>"] = { "toggle_filter", mode = { "i", "n" }, desc = "Toggle filter" },
        },
      },
    },
  }
end

--- Open the API picker for browsing all APIs.
function M.api_pick()
  local cfg = filter_config(api, "_api_filter", function(label)
    return "APIs [" .. label .. "] (C-i: toggle filter)"
  end)

  Snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = "APIs (C-i: toggle filter)",
    format = format_api,
    finder = function()
      return api.find_all()
    end,
  }))
end

--- Open the event picker pre-scoped to a specific event name.
function M.events_pick(event_name)
  local cfg = filter_config(events, "_event_filter", function(label)
    return event_name .. " [" .. label .. "] (C-i: toggle filter)"
  end)

  Snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = event_name .. " (C-i: toggle filter)",
    format = format_event,
    finder = function()
      return events.find(event_name)
    end,
  }))
end

--- Open the event picker for browsing all events.
--- Uses snacks async to run all 4 rg searches in parallel, pushing results
--- as each completes — definitions and publishers appear first while the
--- slower subscriber searches are still running.
function M.events_pick_all()
  local cfg = filter_config(events, "_event_filter", function(label)
    return "Events [" .. label .. "] (C-i: toggle filter)"
  end)

  ---@async
  local function finder(cb)
    local Async = require("snacks.picker.util.async")
    local self = Async.running()

    -- Launch all 4 rg searches concurrently
    local outputs = {}
    local done = {}
    local function launch(idx, cmd)
      vim.system({ "sh", "-c", cmd }, { text = true }, function(result)
        outputs[idx] = result.code == 0 and result.stdout or ""
        done[idx] = true
        self:resume()
      end)
    end

    launch(1, events.cmd_definitions())
    launch(2, events.cmd_publishers())
    launch(3, events.cmd_inline_subscribers())
    launch(4, events.cmd_named_handlers())

    -- Push definitions as soon as ready
    while not done[1] do
      self:suspend()
    end
    for _, item in ipairs(events.parse_definitions(outputs[1])) do
      cb(item)
    end

    -- Push publishers as soon as ready
    while not done[2] do
      self:suspend()
    end
    for _, item in ipairs(events.parse_publishers(outputs[2])) do
      cb(item)
    end

    -- Inline subscribers must finish before named handlers (for dedup)
    while not done[3] do
      self:suspend()
    end
    local inline_items, seen_lines, seen_file_events = events.parse_inline_subscribers(outputs[3])
    for _, item in ipairs(inline_items) do
      cb(item)
    end

    -- Named handlers, deduped against inline subscribers
    while not done[4] do
      self:suspend()
    end
    for _, item in ipairs(events.parse_named_handlers(outputs[4], seen_lines, seen_file_events)) do
      cb(item)
    end
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = "Events (C-i: toggle filter)",
    format = format_event,
    finder = finder,
  }))
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/pickers/snacks.lua
git commit -m "Add snacks picker adapter with async parallel event search"
```

---

### Task 6: Create pickers/telescope.lua

Sync adapter using telescope's `pickers.new`, `finders.new_table`, and `entry_display`. Filter cycling refreshes the finder with filtered items. File preview uses telescope's built-in file previewer.

**Files:**
- Create: `lua/incidentio/pickers/telescope.lua`

- [ ] **Step 1: Create telescope.lua**

```lua
-- Telescope picker adapter: sync/serial support for telescope.nvim.
--
-- Uses telescope's entry_display for badge formatting and finders.new_table for
-- static item lists. Filter cycling (<C-i>) replaces the finder with filtered items.
-- All searches run synchronously — for parallel execution, use the snacks adapter.

local M = {}

local api = require("incidentio.api")
local events = require("incidentio.events")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

--- Build a telescope entry maker for items with badges.
--- badges: table of kind -> {icon, hl}. label_field: item field for display text.
local function make_entry_maker(badges, label_field)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 4 },
      { remaining = true },
    },
  })

  return function(item)
    local badge = badges[item.kind] or { icon = "?", hl = "Comment" }
    return {
      value = item,
      display = function()
        return displayer({
          { badge.icon, badge.hl },
          item[label_field] or item.text or "",
        })
      end,
      ordinal = item.text or "",
      filename = item.file,
      lnum = item.pos and item.pos[1] or 1,
      col = item.pos and (item.pos[2] + 1) or 1,
    }
  end
end

--- Attach <C-i> filter cycling to a telescope picker.
--- mod must have .filter_modes and .filter_labels tables.
--- all_items: the unfiltered item list. entry_maker: telescope entry maker function.
local function attach_filter_mappings(mod, all_items, entry_maker)
  local filter_idx = 1

  return function(prompt_bufnr, map)
    map({ "i", "n" }, "<C-i>", function()
      local modes = mod.filter_modes
      local labels = mod.filter_labels

      filter_idx = (filter_idx % #modes) + 1
      local mode = modes[filter_idx]

      local filtered = mode == "all" and all_items
        or vim.tbl_filter(function(item) return item.kind == mode end, all_items)

      local picker = action_state.get_current_picker(prompt_bufnr)
      picker:refresh(
        finders.new_table({ results = filtered, entry_maker = entry_maker }),
        { reset_prompt = false }
      )
      picker.prompt_border:change_title(labels[mode])
    end)
    return true
  end
end

--- Open the API picker for browsing all APIs.
function M.api_pick()
  local items = api.find_all()
  local entry_maker = make_entry_maker(api.badges, "method_label")

  pickers
    .new({}, {
      prompt_title = "APIs (C-i: toggle filter)",
      finder = finders.new_table({ results = items, entry_maker = entry_maker }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = attach_filter_mappings(api, items, entry_maker),
    })
    :find()
end

--- Open the event picker pre-scoped to a specific event name.
function M.events_pick(event_name)
  local items = events.find(event_name)
  local entry_maker = make_entry_maker(events.badges, "event_name")

  pickers
    .new({}, {
      prompt_title = event_name .. " (C-i: toggle filter)",
      finder = finders.new_table({ results = items, entry_maker = entry_maker }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = attach_filter_mappings(events, items, entry_maker),
    })
    :find()
end

--- Open the event picker for browsing all events.
function M.events_pick_all()
  local items = events.find_all()
  local entry_maker = make_entry_maker(events.badges, "event_name")

  pickers
    .new({}, {
      prompt_title = "Events (C-i: toggle filter)",
      finder = finders.new_table({ results = items, entry_maker = entry_maker }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = attach_filter_mappings(events, items, entry_maker),
    })
    :find()
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/incidentio/pickers/telescope.lua
git commit -m "Add telescope picker adapter with sync search and filter cycling"
```

---

### Task 7: Rewrite init.lua and delete old files

Rewrite `init.lua` to be minimal — just delegates to config.setup. The plugin does not register keymaps; users configure their own keymaps via lazy.nvim `keys`, `vim.keymap.set`, or their plugin manager of choice.

Delete the old monolithic picker files that have been replaced by the new modules.

**Files:**
- Rewrite: `lua/incidentio/init.lua`
- Delete: `lua/incidentio/api_picker.lua`
- Delete: `lua/incidentio/event_picker.lua`

- [ ] **Step 1: Rewrite init.lua**

```lua
-- nvim-incidentio: Neovim plugins for working at incident.io.
--
-- Provides:
--   - API navigation: browse and jump between Goa design/impl
--   - Event references: find all publishers/subscribers of a domain event
--
-- Picker backends: snacks.nvim (recommended, async) or telescope.nvim (sync).
-- Detects automatically, or set opts.picker = "snacks" | "telescope".
--
-- This plugin does not register keymaps. See README.md for recommended keymap setup.

local M = {}

function M.setup(opts)
  require("incidentio.config").setup(opts)
end

return M
```

- [ ] **Step 2: Delete old files**

```bash
git rm lua/incidentio/api_picker.lua lua/incidentio/event_picker.lua
```

- [ ] **Step 3: Verify snacks path works end-to-end**

Source the plugin in neovim, set up keymaps manually, and check for errors:

```vim
:lua require("incidentio").setup()
:lua vim.keymap.set("n", "<leader>sA", require("incidentio.picker").api_pick)
:lua vim.keymap.set("n", "<leader>sE", require("incidentio.picker").events_pick_all)
:messages
```

Press `<leader>sA` to verify the snacks picker opens.

- [ ] **Step 4: Commit**

```bash
git add lua/incidentio/init.lua
git commit -m "Rewrite init.lua: minimal setup, no keymap registration

Users configure keymaps via lazy.nvim keys, vim.keymap.set, or their
plugin manager. See README.md for examples."
```

---

### Task 8: Update documentation

Update README and CLAUDE.md to reflect the new architecture: no default keymaps, multiple picker backends, public API for custom pickers.

**Files:**
- Rewrite: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite README.md**

```markdown
# nvim-incidentio

Neovim plugins for working in the [incident.io](https://incident.io) codebase.

## Installation

Requires one of: [snacks.nvim](https://github.com/folke/snacks.nvim) (recommended) or
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "incident-io/nvim-incidentio",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    { "<leader>sA", function() require("incidentio.picker").api_pick() end, desc = "APIs" },
    { "<leader>sE", function() require("incidentio.picker").events_pick_all() end, desc = "Events" },
    { "gA", function() require("incidentio.api").goto_counterpart() end, desc = "Goto API design/impl" },
    { "gE", function() require("incidentio.picker").events_pick_at_cursor() end, desc = "Event publishers/subscribers" },
  },
  opts = {},
}
```

### Other plugin managers

Add the plugin to your runtimepath, then call setup and configure keymaps:

```lua
require("incidentio").setup()

vim.keymap.set("n", "<leader>sA", function() require("incidentio.picker").api_pick() end, { desc = "APIs" })
vim.keymap.set("n", "<leader>sE", function() require("incidentio.picker").events_pick_all() end, { desc = "Events" })
vim.keymap.set("n", "gA", function() require("incidentio.api").goto_counterpart() end, { desc = "Goto API design/impl" })
vim.keymap.set("n", "gE", function() require("incidentio.picker").events_pick_at_cursor() end, { desc = "Event publishers/subscribers" })
```

### which-key icons

The plugin does not depend on which-key, but if you use it you can add a custom icon rule
to give all incidentio keymaps the fire icon:

```lua
-- In your which-key config
opts = {
  icons = {
    rules = {
      { plugin = "nvim-incidentio", icon = "\u{F0535}", color = "orange" },  -- nf-md-fire
    },
  },
}
```

## Configuration

```lua
require("incidentio").setup({
  -- Picker backend: "snacks" (recommended), "telescope", or "auto" (default).
  -- "auto" detects snacks first, then telescope. Errors if neither is found.
  picker = "auto",
})
```

## Plugins

### API Picker

`<leader>sA` opens a picker listing every API method.
Search for an endpoint or service to navigate to the design or implementation.
Use `<C-i>` to cycle the filter: All → Design only → Impl only.

`gA` is a quick jump: place your cursor inside a `Method("Name"` declaration in a design file
and it takes you to the implementation, or vice versa.

### Event Picker

`<leader>sE` opens a picker listing every domain event definition, publisher,
and subscriber. Type an event name to find everything related to it. Use `<C-i>` to
cycle the filter: All → Definitions → Publishers → Subscribers.

`gE` does the same thing but pre-scoped: place your cursor on an event type name — either
on the struct definition (e.g. `type AlertResolved struct`) or a reference (e.g.
`*event.AlertResolved`) — and it opens the picker already filtered to that event.

## Custom picker integration

If you use a picker other than snacks or telescope, you can call the finding logic directly:

```lua
local api = require("incidentio.api")
local events = require("incidentio.events")

-- All API items (design + impl) as a flat list
local api_items = api.find_all()

-- All refs for a specific event
local event_items = events.find("AlertResolved")

-- All events (sync, serial)
local all_events = events.find_all()
```

Each item is a plain table with `text`, `kind`, `file`, and `pos` fields. See the source
for badge/filter constants (`api.badges`, `events.filter_modes`, etc.) if you want to
replicate the built-in picker formatting.
```

- [ ] **Step 2: Update CLAUDE.md picker style and which-key sections**

In `CLAUDE.md`, replace the "Picker style" section with:

```markdown
### Picker style

Pickers should follow the pattern established in `pickers/snacks.lua` and `pickers/telescope.lua`:
- Badge definitions and filter mode constants live in the core module (e.g. `api.badges`, `events.filter_modes`)
- Each picker adapter handles its own formatting using the core module's badge constants
- Snacks adapter uses `Snacks.picker.format.filename(item, picker)` for file paths
- Telescope adapter uses `entry_display.create()` for column layout
- Nerd Font icon badge per item kind, colored with `DiagnosticInfo`/`DiagnosticWarn`/`DiagnosticHint`
- `text` field should contain only what the user would intuitively search for (e.g. event name,
  method name) — not code or file paths
- `<C-i>` filter toggle cycling through item kinds
```

Replace the "Which-key menu items" section with:

```markdown
### Which-key menu items

The plugin does not depend on which-key. Users who want the nf-md-fire icon (orange) can
add a which-key `icons.rules` entry matching the plugin name — see README.md for the snippet.
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Update docs for new architecture: no default keymaps, multiple pickers"
```

---

### Task 9: End-to-end verification

Run through the existing manual test cases to verify the refactor didn't break anything.

- [ ] **Step 1: Verify snacks adapter with API picker tests**

Run the test cases from `tests/api_picker.md` using nvim-mcp. All 9 test cases should pass unchanged — the snacks adapter produces identical picker behavior to the old api_picker.lua.

- [ ] **Step 2: Verify snacks adapter with event picker tests**

Run the test cases from `tests/event_picker.md` using nvim-mcp. All 11 test cases should pass unchanged.

- [ ] **Step 3: Verify no-picker error message**

Temporarily set `picker = "telescope"` without telescope installed to verify the helpful error:

```lua
require("incidentio").setup({ picker = "telescope" })
-- Call a picker function, should see:
-- "nvim-incidentio: failed to load picker adapter 'telescope': ..."
require("incidentio.picker").api_pick()
```

- [ ] **Step 4: Verify custom picker integration**

Test that the public API works for custom picker consumers:

```lua
:lua print(vim.inspect(require("incidentio.api").find_all()))
:lua print(vim.inspect(require("incidentio.events").find("AlertResolved")))
```

Both should return non-empty tables (when run in the incident.io repo).
