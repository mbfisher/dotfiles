-- Event search: find domain events with their publishers and subscribers.
--
-- Public API:
--   events.find_all()                — all events as a flat item list (sync, serial)
--   events.event_name_under_cursor() — extract event name at cursor position
--   events.badges / filter_modes / filter_labels — constants for picker adapters
--
-- Building blocks (used by snacks adapter for parallel execution):
--   events.cmd_definitions()                — rg command for all event definitions
--   events.cmd_publishers()                 — rg command for all event publishers
--   events.cmd_inline_subscribers()         — rg command for inline subscribers
--   events.cmd_named_handlers()             — rg command for named handler func defs
--   events.cmd_handler_traceback(fn, dir)   — rg command tracing a named handler to its subscribe call
--   events.parse_definitions(output)        — parse rg output into def items
--   events.parse_publishers(output)         — parse rg output into pub items
--   events.parse_inline_subscribers(output) — returns (sub items, sub_seen set)
--   events.parse_named_handlers(output)     — returns handler records {file, lnum, func_name, event_name}
--   events.parse_handler_traceback(output, fn, event_name) — returns sub items for one handler
--
-- Search strategy:
--   Definitions: rg for `type XXX struct` in **/event/*.go package files.
--   Publishers:  rg for `event.{Name}{` struct literals (arg to eventadapter.Publish).
--   Subscribers — both phases report the subscribe() call site as the sub item line:
--     a. Inline: `subscribe(func(... *event.X ...))` — multiline-dotall match, strict
--        `func(` requirement after subscribe() so thin wrappers don't accidentally match.
--     b. Named:  `func Foo(... *event.X ...)` defs are first found, then each is traced
--        back via a per-handler rg to its `subscribe(Foo, …)` / `Subscribe(…, s.Foo, …)`
--        call. Dedupes against inline subscribers by (file, line).
--   Both phases tolerate prefixed event packages (e.g. `*oncallevent.X`, `*pkgevent.X`)
--   and subscribe variants with suffixes (e.g. `subscribeLowPriority`).

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

--- rg command for inline subscribers: `subscribe(func(... *event.X ...))`.
--- The `\s*func\s*\(` after `subscribe(` keeps the match strict — thin wrappers like
--- `subscribe(handlerName, ...)` go through the named-handler path instead.
--- `\w*event\.` matches both bare `event.X` and prefixed packages (`oncallevent`,
--- `pkgevent`, `aievent`).
function M.cmd_inline_subscribers()
  return rg_cmd(
    "--multiline --multiline-dotall "
      .. "'[Ss]ubscribe\\w*\\(\\s*func\\s*\\([\\s\\S]{0,300}\\*\\w*event\\.\\w+[,)]' "
      .. dir_str
  )
end

--- rg command for all named handler function definitions accepting an event type.
--- These need a trace-back step (see `cmd_handler_traceback`) to find the subscribe()
--- call site where they're registered. `\w*event\.` covers prefixed event packages.
function M.cmd_named_handlers()
  return rg_cmd("'^func\\b.*\\s\\*\\w*event\\.\\w+[,)]' " .. dir_str)
end

--- rg command tracing a named handler back to its subscribe() call site.
--- Searches within the handler's package for `subscribe(...funcName,...)` or
--- `Subscribe(..., s.funcName, ...)`. `\.?` allows for method-receiver references.
--- Run once per handler returned by cmd_named_handlers.
function M.cmd_handler_traceback(func_name, pkg_dir)
  return rg_cmd(
    "--multiline --multiline-dotall "
      .. "'[Ss]ubscribe\\w*\\([\\s\\S]{0,500}\\.?" .. func_name .. "[,)]' "
      .. pkg_dir
  )
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

--- Walk rg multi-line output and yield contiguous match blocks. Each block is a
--- list of {file, lnum, text} rows whose file and line numbers are consecutive
--- (i.e. they came from one --multiline rg match). Used by inline-subscribers
--- and handler-traceback parsers — both need to correlate `subscribe(` with a
--- token (event type or func name) that may land on a different output line.
local function iter_blocks(output)
  local rows = {}
  for line in output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file then
      table.insert(rows, { file = file, lnum = tonumber(lnum), text = text })
    end
  end

  local i = 1
  return function()
    if i > #rows then return nil end
    local start = i
    while i + 1 <= #rows
        and rows[i + 1].file == rows[i].file
        and rows[i + 1].lnum == rows[i].lnum + 1 do
      i = i + 1
    end
    local block = {}
    for k = start, i do
      table.insert(block, rows[k])
    end
    i = i + 1
    return block
  end
end

--- Parse inline subscriber rg output into items.
--- Returns (items, sub_seen) where sub_seen is a set of "file:lnum" keys for
--- the subscribe() call sites — passed to handler-traceback dedup.
function M.parse_inline_subscribers(output)
  local items = {}
  local sub_seen = {}
  for block in iter_blocks(output) do
    -- Filter `subscribe(` calls only — not SubscribeParams, SubscriberID, etc.
    local sub_row, event_name
    for _, row in ipairs(block) do
      if not sub_row and row.text:match("[Ss]ubscribe%w*%(") then
        sub_row = row
      end
      if not event_name then
        event_name = extract_event_name(row.text)
      end
    end

    if sub_row and event_name then
      local key = sub_row.file .. ":" .. sub_row.lnum
      if not sub_seen[key] then
        sub_seen[key] = true
        table.insert(items, make_item("sub", event_name, vim.trim(sub_row.text), sub_row.file, sub_row.lnum))
      end
    end
  end
  return items, sub_seen
end

--- Parse named-handler rg output into handler records (NOT sub items).
--- Each record is {file, lnum, func_name, event_name}, suitable for feeding
--- into cmd_handler_traceback + parse_handler_traceback to find the actual
--- subscribe() call site. Skips lines where the func name can't be extracted.
function M.parse_named_handlers(output)
  local handlers = {}
  for line in output:gmatch("[^\n]+") do
    local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
    if file then
      -- Plain func: `func Foo(...)`. Method receiver: `func (s *T) Foo(...)`.
      local func_name = text:match("^func%s+(%w+)%(")
      if not func_name then
        func_name = text:match("^func%s+%([^)]+%)%s+(%w+)%(")
      end
      local event_name = extract_event_name(text)
      if func_name and event_name then
        table.insert(handlers, {
          file = file,
          lnum = tonumber(lnum),
          func_name = func_name,
          event_name = event_name,
        })
      end
    end
  end
  return handlers
end

--- Parse the trace-back rg output for one handler. Returns sub items pointing
--- to the subscribe() call site. event_name is supplied by the caller since the
--- subscribe call line doesn't itself contain `event.X`.
---
--- A single multiline match block can contain multiple `subscribe(...)` calls
--- when they're close together (e.g. two back-to-back `subscribe(funcA,…)` /
--- `subscribe(funcB,…)` calls inside one `init()`). For each occurrence of
--- func_name in the block, pair it with the latest preceding `subscribe(`
--- row in the same block — that's the call that actually registered this
--- handler.
function M.parse_handler_traceback(output, func_name, event_name)
  local items = {}
  local seen = {}
  for block in iter_blocks(output) do
    local sub_rows, func_rows = {}, {}
    for _, row in ipairs(block) do
      if row.text:match("[Ss]ubscribe%w*%(") then
        table.insert(sub_rows, row)
      end
      if row.text:find(func_name, 1, true) then
        table.insert(func_rows, row)
      end
    end

    for _, frow in ipairs(func_rows) do
      local sub_row
      for _, srow in ipairs(sub_rows) do
        if srow.lnum <= frow.lnum and (not sub_row or srow.lnum > sub_row.lnum) then
          sub_row = srow
        end
      end
      if sub_row then
        local key = sub_row.file .. ":" .. sub_row.lnum
        if not seen[key] then
          seen[key] = true
          table.insert(items, make_item("sub", event_name, vim.trim(sub_row.text), sub_row.file, sub_row.lnum))
        end
      end
    end
  end
  return items
end

-- ── High-level sync API ────────────────────────────────────────────────────

--- Find all event definitions, publishers, and subscribers.
--- The 4 main rg searches run serially via vim.fn.system, then the per-handler
--- trace-back fans out in parallel via vim.system callbacks (driven by vim.wait).
--- For streaming async execution (UI shows items as each phase completes), drive
--- cmd_*/parse_* directly — see pickers/snacks.lua.
function M.find_all()
  local items = {}

  local function run(cmd)
    local output = vim.fn.system(cmd)
    return vim.v.shell_error == 0 and output or ""
  end

  vim.list_extend(items, M.parse_definitions(run(M.cmd_definitions())))
  vim.list_extend(items, M.parse_publishers(run(M.cmd_publishers())))

  local inline_items, sub_seen = M.parse_inline_subscribers(run(M.cmd_inline_subscribers()))
  vim.list_extend(items, inline_items)

  local handlers = M.parse_named_handlers(run(M.cmd_named_handlers()))
  if #handlers == 0 then
    return items
  end

  -- Fan out trace-backs in parallel. libuv queues subprocesses, so spawning all
  -- ~hundreds at once is fine. vim.wait spins the event loop until all complete.
  local outputs = {}
  local remaining = #handlers
  for i, h in ipairs(handlers) do
    local pkg_dir = h.file:match("^(.*/)") or ""
    vim.system({ "sh", "-c", M.cmd_handler_traceback(h.func_name, pkg_dir) }, { text = true }, function(result)
      outputs[i] = result.code == 0 and result.stdout or ""
      remaining = remaining - 1
    end)
  end
  vim.wait(60000, function() return remaining == 0 end, 20)

  for i, h in ipairs(handlers) do
    for _, item in ipairs(M.parse_handler_traceback(outputs[i] or "", h.func_name, h.event_name)) do
      local key = item.file .. ":" .. item.pos[1]
      if not sub_seen[key] then
        sub_seen[key] = true
        table.insert(items, item)
      end
    end
  end

  return items
end

return M
