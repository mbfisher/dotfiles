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
      { plugin = "nvim-incidentio", icon = "󰈸", color = "orange" },  -- nf-md-fire
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
