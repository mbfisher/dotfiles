# nvim-incidentio

Neovim plugins for working in the [incident.io](https://incident.io) codebase.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "incident-io/nvim-incidentio",
  dependencies = { "folke/snacks.nvim", "folke/which-key.nvim" },
  config = function()
    require("incidentio").setup()
  end,
}
```

## Plugins

### API Picker

`<leader>sA` opens a snacks picker listing every API method.
Search for an endpoint or service to easily navigate to the design (`[D]`) or implementation (`[I]`).
Use `<C-i>` to cycle the filter: All → Design only → Impl only.

`gA` is a quick jump: place your cursor inside a `Method("Name"` declaration in a design file
and it takes you to the implementation, or vice versa.

### Event Picker

`<leader>sE` opens a picker listing every domain event definition `[E]`, publisher `[P]`,
and subscriber `[S]`. Type an event name to find everything related to it. Use `<C-i>` to
cycle the filter: All → Definitions → Publishers → Subscribers.

`gE` does the same thing but pre-scoped: place your cursor on an event type name — either
on the struct definition (e.g. `type AlertResolved struct`) or a reference (e.g.
`*event.AlertResolved`) — and it opens the picker already filtered to that event.
