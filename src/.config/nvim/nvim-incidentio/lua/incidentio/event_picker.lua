-- Event Picker: find and browse domain events with their publishers and subscribers.
--
-- Two entry points:
--   <leader>sE opens a picker listing all event definitions, publishers,
--   and subscribers. Search by event name to find everything related to it.
--
--   gE (with cursor on an event type name) opens the same picker pre-scoped to
--   that specific event — no searching needed.
--
-- Toggle the filter with <C-i>: All → Definitions → Publishers → Subscribers.
--
-- How it works:
--   Event definitions: rg for `type XXX struct` in **/event/*.go package files.
--   Publishers: rg for `event.{Name}{` struct literals (arg to eventadapter.Publish).
--   Subscribers: two-phase rg search:
--     a. Inline: multiline match for subscribe() with *event.{Name} in function args
--     b. Named: handler functions accepting *event.{Name}, then (for single-event
--        mode) trace back to the subscribe() call that wires them up
--   Handles subscribe() variants with suffixes (e.g. subscribeLowPriority).

local M = {}

--- Common rg flags: Go files, excluding tests and generated event matchers.
local rg_glob = "-g '*.go' -g '!*_test.go' -g '!**/event/matchers/**'"

--- Restrict to event package files (where domain event structs are defined).
local rg_event_def_glob = "-g '**/event/*.go' -g '!*_test.go'"

--- Build an rg command string (does not execute it).
local function rg_cmd(args)
  return "rg -Hn --no-heading " .. rg_glob .. " " .. args
end

--- Build an rg command string restricted to event package files.
local function rg_event_def_cmd(args)
  return "rg -Hn --no-heading " .. rg_event_def_glob .. " " .. args
end

--- Run rg synchronously and return raw output (empty string on failure).
local function rg_raw(args)
  -- -H ensures filename is always shown, even when searching a single file
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

--- Get the event type name under the cursor.
--- Handles both `event.AlertResolved` references and bare `AlertResolved` in
--- struct definitions. Returns nil if no word found.
local function event_name_under_cursor()
  -- cWORD grabs the broader token (e.g. "event.AlertResolved{" or "&event.AlertResolved{")
  local cword = vim.fn.expand("<cWORD>")

  -- Try to extract from a qualified reference like event.AlertResolved or &event.AlertResolved{
  local name = cword:match("event%.(%w+)")
  if name then
    return name
  end

  -- Fall back to the simple word under cursor (for struct definitions like `type AlertResolved struct`)
  return vim.fn.expand("<cword>")
end

--- Search dirs within the repo — all non-generated server code.
local search_dirs = { "server/app/", "server/pkg/", "server/integrations/", "server/cmd/", "server/api/", "server/slack/" }

--- Format a single event picker item for display.
--- Layout: Badge  EventName  icon dir/file:line  code_snippet
local function format_event(item, picker)
  local ret = {}

  local badges = {
    def = { " \u{F140B} ", "DiagnosticInfo" },    -- nf-md-lightning_bolt
    pub = { " \u{F10DD} ", "DiagnosticWarn" },    -- nf-md-email_send_outline
    sub = { " \u{F02FB} ", "DiagnosticHint" },    -- nf-md-inbox_arrow_down
  }
  local badge = badges[item.kind] or { " ? ", "Comment" }
  ret[#ret + 1] = { badge[1], badge[2] }
  ret[#ret + 1] = { " " }

  -- Event name — field="text" tells snacks to apply fuzzy match highlights here
  ret[#ret + 1] = { item.event_name or "", nil, field = "text" }
  ret[#ret + 1] = { " " }

  -- File path with icon (reuse snacks built-in filename formatter)
  vim.list_extend(ret, Snacks.picker.format.filename(item, picker))

  -- Line number
  if item.pos then
    ret[#ret + 1] = { ":" .. item.pos[1], "SnacksPickerRow" }
  end

  -- Code snippet for publishers/subscribers (dimmed)
  if item.code then
    ret[#ret + 1] = { "  " .. item.code, "SnacksPickerComment" }
  end

  return ret
end

--- Build a picker item with consistent fields for display and search.
local function make_item(kind, event_name, code, file, line)
  return {
    -- text is only the event name so fuzzy matching searches by event name, not code/filepath
    text = event_name,
    event_name = event_name,
    code = code,
    kind = kind,
    file = file,
    pos = { line, 0 },
  }
end

--- Find definition, publishers, and subscribers of the given event name.
--- Returns a list of snacks picker items tagged with kind="def"/"pub"/"sub".
function M.find(event_name)
  local dir_str = table.concat(search_dirs, " ")
  local items = {}

  -- Definition: type EventName struct in event package files
  local defs = parse_rg(rg_event_defs("'^type " .. event_name .. " struct' server/"))
  for _, hit in ipairs(defs) do
    table.insert(items, make_item("def", event_name, nil, hit.file, hit.line))
  end

  -- Publishers: struct literal instantiation (the arg to eventadapter.Publish)
  local pubs = parse_rg(rg_raw("'event\\." .. event_name .. "\\{' " .. dir_str))
  for _, hit in ipairs(pubs) do
    table.insert(items, make_item("pub", event_name, hit.text, hit.file, hit.line))
  end

  -- Subscribers phase 1: inline anonymous functions passed directly to subscribe().
  -- Multiline match: [Ss]ubscribe( followed by *event.EventName within ~300 chars.
  -- Case-insensitive prefix catches both local subscribe() helpers and eventadapter.Subscribe().
  local inline_output = rg_raw(
    "--multiline --multiline-dotall "
      .. "'[Ss]ubscribe\\w*\\([\\s\\S]{0,300}\\*event\\."
      .. event_name
      .. "[,)]' "
      .. dir_str
  )
  -- Each multiline match spans several lines; keep only the [Ss]ubscribe( line.
  local seen = {} -- deduplicate by file:line
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

  -- Subscribers phase 2: named handler functions wired up via subscribe(handlerName, ...).
  -- Find function/method definitions that accept this event, extract the handler name,
  -- then locate the subscribe() call that references it.
  -- Uses '^func\b' to match both plain functions and method receivers.
  -- Require \s before *event to exclude generated matcher methods whose return types
  -- reference the event (e.g. func(...) func(*event.XXX, ...)) — real handlers have a
  -- named parameter like `ev *event.XXX`.
  local def_output = rg_raw("'^func\\b.*\\s\\*event\\." .. event_name .. "[,)]' " .. dir_str)
  for line in def_output:gmatch("[^\n]+") do
    -- Extract function name: plain func or method receiver (last word before opening paren)
    local file, _, func_name = line:match("^([^:]+):(%d+):func%s+(%w+)%(")
    if not func_name then
      -- Method receiver: func (r *Type) MethodName(
      file, _, func_name = line:match("^([^:]+):(%d+):func%s+%([^)]+%)%s+(%w+)%(")
    end
    if func_name then
      -- Search the same Go package (directory) for a subscribe call passing this handler.
      -- The subscribe() wiring is often in a different file (e.g. service.go) than the handler.
      -- Uses \.?FuncName to match both bare FuncName and receiver.FuncName references.
      local pkg_dir = file:match("^(.*/)")
      local sub_output = rg_raw(
        "--multiline --multiline-dotall '[Ss]ubscribe\\w*\\([\\s\\S]{0,500}\\.?" .. func_name .. "[,)]' " .. pkg_dir
      )
      for sub_line in sub_output:gmatch("[^\n]+") do
        local sf, sl, st = sub_line:match("^([^:]+):(%d+):(.*)")
        -- Line must contain both a subscribe call and the handler name to filter out
        -- noise lines from multiline matches (comments, wrapper functions, etc.)
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

--- Async finder for all event definitions, publishers, and subscribers.
--- Returns a function(cb) so snacks opens the picker immediately and populates
--- results as each rg search completes — definitions and publishers appear first
--- while the slower subscriber searches are still running.
function M.find_all()
  local dir_str = table.concat(search_dirs, " ")

  ---@async
  return function(cb)
    local Async = require("snacks.picker.util.async")
    local self = Async.running()

    -- Launch all 4 rg searches concurrently. Each notifies via resume on completion.
    local outputs = {}
    local done = {}
    local function launch(idx, cmd)
      vim.system({ "sh", "-c", cmd }, { text = true }, function(result)
        outputs[idx] = result.code == 0 and result.stdout or ""
        done[idx] = true
        self:resume()
      end)
    end

    launch(1, rg_event_def_cmd("'^type \\w+ struct' server/"))
    launch(2, rg_cmd("'event\\.\\w+\\{' " .. dir_str))
    launch(3, rg_cmd(
      "--multiline --multiline-dotall "
        .. "'[Ss]ubscribe\\w*\\([\\s\\S]{0,300}\\*event\\.\\w+[,)]' "
        .. dir_str
    ))
    launch(4, rg_cmd("'^func\\b.*\\s\\*event\\.\\w+[,)]' " .. dir_str))

    -- Wait for definitions, push as soon as ready
    while not done[1] do self:suspend() end
    for _, hit in ipairs(parse_rg(outputs[1])) do
      local name = hit.text:match("^type (%w+) struct")
      if name then
        cb(make_item("def", name, nil, hit.file, hit.line))
      end
    end

    -- Wait for publishers, push as soon as ready
    while not done[2] do self:suspend() end
    for _, hit in ipairs(parse_rg(outputs[2])) do
      local name = extract_event_name(hit.text)
      if name then
        cb(make_item("pub", name, hit.text, hit.file, hit.line))
      end
    end

    -- Wait for inline subscribers — must finish before named handlers for dedup
    local seen = {}
    local sub_file_events = {}
    while not done[3] do self:suspend() end
    for line in outputs[3]:gmatch("[^\n]+") do
      local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
      if file and text:match("[Ss]ubscribe") then
        local key = file .. ":" .. lnum
        if not seen[key] then
          seen[key] = true
          local name = extract_event_name(text)
          if name then
            sub_file_events[file .. ":" .. name] = true
            cb(make_item("sub", name, vim.trim(text), file, tonumber(lnum)))
          end
        end
      end
    end

    -- Wait for named handlers, deduped against inline subscribers above
    while not done[4] do self:suspend() end
    for line in outputs[4]:gmatch("[^\n]+") do
      local file, lnum, text = line:match("^([^:]+):(%d+):(.*)")
      if file then
        local name = extract_event_name(text)
        if name and not sub_file_events[file .. ":" .. name] then
          local key = file .. ":" .. lnum
          if not seen[key] then
            seen[key] = true
            cb(make_item("sub", name, vim.trim(text), file, tonumber(lnum)))
          end
        end
      end
    end
  end
end

--- Filter modes for the picker, cycled by <C-i>
M.filter_modes = { "all", "def", "pub", "sub" }
M.filter_labels = { all = "All", def = "Definitions only", pub = "Publishers only", sub = "Subscribers only" }

--- Shared picker config: toggle filter action and keybind.
local function picker_actions_and_keys(title_fn)
  return {
    actions = {
      toggle_event_filter = function(picker)
        local modes = M.filter_modes
        local labels = M.filter_labels

        local current = picker._event_filter or "all"
        local idx = 1
        for i, m in ipairs(modes) do
          if m == current then
            idx = i
            break
          end
        end
        local next_mode = modes[(idx % #modes) + 1]
        picker._event_filter = next_mode

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
          ["<C-i>"] = { "toggle_event_filter", mode = { "i", "n" }, desc = "Toggle event filter" },
        },
      },
    },
  }
end

--- Open the event picker for the event under the cursor.
function M.pick()
  local name = event_name_under_cursor()
  if not name or name == "" then
    vim.notify("No event name under cursor", vim.log.levels.WARN)
    return
  end

  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    vim.notify("snacks.nvim picker not available", vim.log.levels.ERROR)
    return
  end

  local cfg = picker_actions_and_keys(function(label)
    return name .. " [" .. label .. "] (C-i: toggle filter)"
  end)

  snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = name .. " (C-i: toggle filter)",
    format = format_event,
    finder = function()
      return M.find(name)
    end,
  }))
end

--- Open the event picker for browsing all events.
--- Unlike pick(), this doesn't require the cursor to be on an event name.
function M.pick_all()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    vim.notify("snacks.nvim picker not available", vim.log.levels.ERROR)
    return
  end

  local cfg = picker_actions_and_keys(function(label)
    return "Events [" .. label .. "] (C-i: toggle filter)"
  end)

  snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = "Events (C-i: toggle filter)",
    format = format_event,
    finder = M.find_all,
  }))
end

return M
