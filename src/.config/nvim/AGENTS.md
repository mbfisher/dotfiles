# Neovim Configuration - AI Agent Guidelines

This is a **LazyVim** configuration. The goal is minimal customization on top of LazyVim defaults.

## Before Making ANY Changes

1. **Read the existing config first** - Check `lua/plugins/` for existing customizations
2. **Check `lazy-lock.json`** - See what plugins are actually installed
3. **Check `lazyvim.json`** - See which LazyVim extras are enabled
4. **Don't assume plugins** - This config has changed significantly from LazyVim defaults

## Critical: Current Plugin Stack (2025)

LazyVim has replaced many popular plugins. **Do NOT suggest configs for deprecated plugins.**

| Component | THIS CONFIG USES | DO NOT SUGGEST |
|-----------|------------------|----------------|
| Completion | `saghen/blink.cmp` | ~~nvim-cmp, hrsh7th/nvim-cmp~~ |
| Fuzzy Finder | `snacks.nvim` picker | ~~telescope.nvim~~ |
| File Explorer | `snacks.nvim` explorer | ~~neo-tree.nvim, nvim-tree~~ |
| Git UI | `snacks.nvim` (lazygit) | - |
| Sessions | `olimorris/persisted.nvim` | ~~persistence.nvim~~ (custom choice) |
| Notifications | DISABLED | ~~folke/noice.nvim~~ (crashes on `:`) |

### Common Mistakes to Avoid

**DO NOT:**
- Suggest `require("telescope")` - use snacks picker instead
- Suggest `require("neo-tree")` - use snacks explorer instead
- Suggest nvim-cmp options like `cmp.setup()` - this uses blink.cmp
- Edit `lazyvim.json` directly - use `:LazyExtras` UI instead
- Suggest noice.nvim - it's disabled because it crashes

## LazyVim Extras System

Language support is added via LazyVim extras, NOT manual LSP/treesitter config.

**To add language support:**
```
:LazyExtras
```
Then enable the relevant `lang.*` extra (e.g., `lang.go`, `lang.typescript`).

**DO NOT manually configure:**
- LSP servers for languages with extras (gopls, tsserver, etc.)
- Treesitter parsers for supported languages
- Formatters/linters that extras handle

**Currently enabled extras** (check `lazyvim.json` for current list):
- `dap.core` - Debugging
- `lang.go`, `lang.typescript`, `lang.python`, etc.
- `test.core` - Testing with neotest
- `formatting.prettier`, `linting.eslint`

## Plugin Configuration Pattern

When extending LazyVim-managed plugins, merge with defaults:

```lua
-- lua/plugins/example.lua
return {
  {
    "plugin/name",
    opts = {
      -- These MERGE with LazyVim defaults
      setting = "value",
    },
  },
}
```

For complex logic, use a function:

```lua
return {
  {
    "plugin/name",
    opts = function(_, opts)
      -- Modify and return opts
      opts.setting = "value"
      return opts
    end,
  },
}
```

### LazyDev Type Completions

When a plugin ships LuaLS type annotations (check for `@class` in its source), add two things to
get completions on `opts`:

1. A **lazydev library entry** in the same file, so LuaLS loads the plugin's types
2. A **`---@type` annotation** on the `opts` table

```lua
return {
  -- LazyDev merges library entries across all plugin files
  { "folke/lazydev.nvim", opts = { library = { { path = "plugin-name", words = { "plugin" } } } } },
  {
    "author/plugin-name",
    ---@type PluginConfig
    opts = {
      -- You now get completions here
    },
  },
}
```

To find the config type name, grep the plugin source for `@class.*Config`:
```sh
grep -r '@class.*Config' ~/.local/share/nvim/lazy/plugin-name/lua/
```

**Plugins that don't need this:** ones where you call `require("plugin").setup(opts)` in a
`config` function — lazydev auto-loads types from `require()` calls.

## Known Gotchas in This Config

### Monorepo Go Projects
- Go projects may have `go.mod` in subdirectories (e.g., `server/go.mod`)
- gopls needs the correct root directory - check `lsp-monorepo.lua`
- The ginkgo adapter has special `dlvCwd` handling for this

### Testing (neotest)
- Go: Uses `nvim-neotest-ginkgo` adapter (NOT standard golang adapter)
- Jest: Uses `bun` as test runner (NOT npm)
- Python: Uses standard neotest-python

### Sessions (persisted.nvim)
- Sessions are per git branch (`use_git_branch = true`)
- `<leader>qs` - Select session
- `<leader>ql` - Load current branch session
- Dashboard "s" key loads current branch session

### Clipboard
- Custom yank/paste mappings in `keymaps.lua`
- `clipboard = ""` in options - NOT synced with system by default
- This preserves register behavior for `dd` + `p` operations

### Blink.cmp Completion
- Completion is disabled in comments via treesitter capture check
- See `lua/plugins/cmp.lua` for the implementation

### Hidden Files
- Snacks picker/explorer configured to show hidden files by default
- Toggle with `<Alt-h>` in picker

## Debugging Problems

### "Changes didn't work after restart"
1. Check for syntax errors: `:messages`
2. Check plugin loaded: `:Lazy` and look at status
3. Check for conflicts with other plugins in `lua/plugins/`

### LSP Issues
1. `:LspInfo` - Check active clients and root directory
2. `:LspLog` - Check for errors
3. For Go monorepos, verify gopls root is at `go.mod` location

### Formatting Issues
1. `:ConformInfo` - Check active formatters
2. Log at `~/.local/state/nvim/conform.log`

## File Structure

```
lua/
├── config/
│   ├── lazy.lua      # Plugin manager + extras imports
│   ├── options.lua   # vim.opt settings
│   ├── autocmds.lua  # Auto-commands (e.g., organize imports on save)
│   └── keymaps.lua   # Custom keybindings
└── plugins/          # One file per feature/plugin
    ├── cmp.lua           # blink.cmp tweaks
    ├── snacks.lua        # Picker, explorer, lazygit config
    ├── persisted.lua     # Session management
    ├── ginkgo.lua        # Go test adapter
    ├── jest.lua          # JS test adapter
    └── ...
```

## Testing Changes

After making nvim config changes:
1. Restart nvim completely (`:qa!` then reopen)
2. Run `:checkhealth` for issues
3. Run `:Lazy` to verify plugins loaded
4. Test the specific feature that was changed

## Known Issues

Cross-cutting issues are documented in the repo-level `issues/` directory (at the dotfiles root, not inside
`src/.config/nvim/`). Issues may span multiple tools (zsh, zellij, nvim, etc.) so they live at the top level. Check
there first when diagnosing crashes or unexpected behavior.

Nvim-specific issues to be aware of:

| Issue | Summary |
|-------|---------|
| [001-nvim-macos-provenance-crash](../../../issues/001-nvim-macos-provenance-crash.md) | macOS 26+ tags Homebrew binaries with `com.apple.provenance`, propagates to treesitter/blink `.so` files, SIGKILL on `dlopen`. Fix: strip provenance via Terminal.app. |

When an investigation resolves a non-trivial problem, save it to `issues/NNN-short-description.md` at the repo root.
Include: symptoms, root cause, fix steps, and recurrence notes. If it's nvim-specific, add a row to the table above.

## Documentation Standards

### Add Comments Explaining "Why"

When landing on a working config, **proactively add succinct comments** explaining why it's configured that way. Future sessions won't have the conversation context.

```lua
-- Good: explains the why
-- Disable completion in comments using treesitter (more reliable than regex)
enabled = function()
  ...
end

-- Bad: just restates what the code does
-- Set enabled to false when in comment
```

### Update This File

When discovering something useful (new gotcha, plugin change, non-obvious fix), **prompt to update this AGENTS.md**. Only for genuinely useful info - not routine changes.

Examples worth adding:
- A plugin was replaced/deprecated
- A fix required non-obvious steps
- A common LazyVim pattern changed
- Monorepo or project-specific workarounds
