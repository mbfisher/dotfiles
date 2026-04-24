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
