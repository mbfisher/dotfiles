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

--- Open the event picker. Uses snacks async to run rg searches in parallel,
--- pushing results as each completes — the picker opens immediately with a
--- spinner and items stream in. Pass pick_opts.pattern to pre-fill the search
--- (used by events_pick_at_cursor via picker.lua).
function M.events_pick(pick_opts)
  pick_opts = pick_opts or {}
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

      -- Launch the 4 main rg searches concurrently.
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

      -- Push definitions ASAP
      while not done[1] do async:suspend() end
      for _, item in ipairs(events.parse_definitions(outputs[1])) do cb(item) end

      -- Push publishers ASAP
      while not done[2] do async:suspend() end
      for _, item in ipairs(events.parse_publishers(outputs[2])) do cb(item) end

      -- Push inline subscribers; remember their subscribe() call sites for dedup
      while not done[3] do async:suspend() end
      local inline_items, sub_seen = events.parse_inline_subscribers(outputs[3])
      for _, item in ipairs(inline_items) do cb(item) end

      -- Wait for the named-handler list, then fan out a trace-back rg per handler
      -- in parallel. Each trace-back finds the subscribe() call site for one named
      -- handler. We process them in launch order so streaming is predictable; head-
      -- of-line blocking is bounded by the slowest single rg, which is small.
      while not done[4] do async:suspend() end
      local handlers = events.parse_named_handlers(outputs[4])

      if #handlers == 0 then return end

      local tb_outputs = {}
      local tb_done = {}
      for i, h in ipairs(handlers) do
        tb_done[i] = false
        local pkg_dir = h.file:match("^(.*/)") or ""
        vim.system({ "sh", "-c", events.cmd_handler_traceback(h.func_name, pkg_dir) }, { text = true }, function(result)
          tb_outputs[i] = result.code == 0 and result.stdout or ""
          tb_done[i] = true
          async:resume()
        end)
      end

      for i, h in ipairs(handlers) do
        while not tb_done[i] do async:suspend() end
        for _, item in ipairs(events.parse_handler_traceback(tb_outputs[i], h.func_name, h.event_name)) do
          local key = item.file .. ":" .. item.pos[1]
          if not sub_seen[key] then
            sub_seen[key] = true
            cb(item)
          end
        end
      end
    end
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", cfg, pick_opts, {
    title = "Events (C-i: toggle filter)",
    format = format_event,
    finder = finder,
  }))
end

function M.events_pick_all()
  M.events_pick()
end

return M
