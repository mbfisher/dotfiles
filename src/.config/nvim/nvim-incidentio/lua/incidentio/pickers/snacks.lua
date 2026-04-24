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

  -- Snacks finder protocol: function(opts, ctx) returns items[] or function(cb).
  -- Return an async function(cb) so snacks wraps it in Async.new, giving us
  -- coroutine-based suspend/resume for parallel rg execution.
  local function finder(opts, ctx)
    ---@async
    return function(cb)
      local Async = require("snacks.picker.util.async")
      local async = Async.running()

      -- Launch all 4 rg searches concurrently
      local outputs = {}
      local done = {}
      local function launch(idx, cmd)
        vim.system({ "sh", "-c", cmd }, { text = true }, function(result)
          outputs[idx] = result.code == 0 and result.stdout or ""
          done[idx] = true
          async:resume()
        end)
      end

      launch(1, events.cmd_definitions())
      launch(2, events.cmd_publishers())
      launch(3, events.cmd_inline_subscribers())
      launch(4, events.cmd_named_handlers())

      -- Push definitions as soon as ready
      while not done[1] do
        async:suspend()
      end
      for _, item in ipairs(events.parse_definitions(outputs[1])) do
        cb(item)
      end

      -- Push publishers as soon as ready
      while not done[2] do
        async:suspend()
      end
      for _, item in ipairs(events.parse_publishers(outputs[2])) do
        cb(item)
      end

      -- Inline subscribers must finish before named handlers (for dedup)
      while not done[3] do
        async:suspend()
      end
      local inline_items, seen_lines, seen_file_events = events.parse_inline_subscribers(outputs[3])
      for _, item in ipairs(inline_items) do
        cb(item)
      end

      -- Named handlers, deduped against inline subscribers
      while not done[4] do
        async:suspend()
      end
      for _, item in ipairs(events.parse_named_handlers(outputs[4], seen_lines, seen_file_events)) do
        cb(item)
      end
    end
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = "Events (C-i: toggle filter)",
    format = format_event,
    finder = finder,
  }))
end

return M
