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
    -- Match subscribe function calls only — not SubscribeParams, SubscriberID, etc.
    if file and text:match("[Ss]ubscribe%w*%(") then
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
    -- Match subscribe function calls only — not SubscribeParams, SubscriberID, etc.
    if file and text:match("[Ss]ubscribe%w*%(") then
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
