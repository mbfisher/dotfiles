# Neovim Configuration - AI Agent Guidelines

This is a **LazyVim** configuration. The goal is minimal customization on top of LazyVim defaults.

## Target Versions

- **Neovim 0.12+** (currently 0.12.2). Anything below 0.12 is unsupported — don't write
  compatibility shims back to 0.11 unless explicitly asked. Notably, 0.12 ships `vim.lsp.config`
  with an async `root_dir(bufnr, on_dir)` signature; see the gotcha below.
- **LazyVim** latest (managed via `:Lazy`).

## Before Making ANY Changes

1. **Read the existing config first** - Check `lua/plugins/` for existing customizations
2. **Check `lazy-lock.json`** - See what plugins are actually installed
3. **Check `lazyvim.json`** - See which LazyVim extras are enabled
4. **Don't assume plugins** - This config has changed significantly from LazyVim defaults

## Critical: Current Plugin Stack (2026)

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

When a plugin ships LuaLS type annotations (check for `@class` in its source), pair two
annotations on the `opts` table:

1. **`---@module 'plugin-name'`** — lazydev detects this (and `require()` calls) and loads the
   plugin's `lua/` dir into LuaLS's workspace
2. **`---@type PluginConfig`** — gives you completions on the `opts` table itself

```lua
return {
  {
    "author/plugin-name",
    ---@module 'plugin-name'
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

After adding the annotations, `:LspRestart lua_ls` so LuaLS picks up the new workspace library.

**Avoid the older `library` entry pattern** (`{ "folke/lazydev.nvim", opts = { library = { ... } } }`)
unless the plugin doesn't ship a top-level Lua module matching its name. The `---@module` form is
canonical (it's what blink.cmp's own docs use) and keeps each plugin's type loading colocated with
its own spec.

## Known Gotchas in This Config

### Monorepo Go Projects
- Go projects may have `go.mod` in subdirectories (e.g., `server/go.mod`)
- gopls needs the correct root directory - check `lsp-monorepo.lua` and `go-lsp.lua`
- The ginkgo adapter has special `dlvCwd` handling for this
- `go-lsp.lua` overrides `root_dir` to return `nil` for paths under `/pkg/mod/`. Without this,
  jumping to a Go module dependency makes lspconfig find the dep's own `go.mod` and spawn a
  *second* gopls rooted there — two long-lived servers compete for CPU/RAM and race on the shared
  `-logfile`. Trade-off: dep files open without LSP features (no hover/goto inside deps).

### Async `root_dir` signature (Neovim 0.12)
nvim 0.12's `vim.lsp.config` invokes `root_dir` as `(bufnr, on_dir)` — the first arg is a buffer
number, and the resolved root must be passed back via `on_dir(result)` rather than returned. Older
lspconfig codepaths still call `(fname)` and use the return value. New `root_dir` callbacks must
handle both signatures or risk `attempt to index local 'fname' (a number value)` errors when the
async path fires (e.g. on BufReadPost from a snacks picker jump). See `go-lsp.lua` for the pattern:
type-check the first arg, resolve `fname` from bufnr if needed, then either call `on_dir(result)`
or return.

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
