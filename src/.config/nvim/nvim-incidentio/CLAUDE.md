## Development

### Prerequisites

The `nvim-mcp` MCP server must be configured. It provides these tools:
- `nvim_connect` — connect to a Neovim instance by socket path
- `nvim_send` — send ex commands, evaluate expressions, or send key sequences
- `nvim_state` — read current buffer, cursor position, mode, window layout, diagnostics
- `nvim_recipes` — browse available operation recipes (files, navigation, LSP, etc.)

### Setup Workflow

#### 1. Understand the goal

If the user hasn't already explained what they want to build or modify, ask them. You need to know
what plugin they're working on and what behavior they expect.

#### 2. Ask for a test repository

Ask the user for a path to a repository to open in Neovim. Plugins often need real code to develop
against (e.g. a Go project for testing a Go navigation plugin). If the plugin doesn't need a
specific codebase, any repo will do.

#### 3. Start a dedicated Neovim instance

Always start a fresh, session-scoped Neovim instance. Never reuse or auto-discover existing
instances — the user may have other Neovim sessions open for their own work.

Generate a unique socket path and start Neovim:

```bash
NVIM_SOCK="/tmp/nvim-claude-$(head -c 4 /dev/urandom | xxd -p).sock"
echo "Socket: $NVIM_SOCK"
nvim --listen "$NVIM_SOCK" --headless -c "cd /path/to/test/repo" &
sleep 1
ls -la "$NVIM_SOCK"
```

Save the socket path — you'll need it for all subsequent nvim-mcp calls.

#### 4. Connect

Use `nvim_connect` with the specific socket path from step 3. Do NOT let it auto-discover
instances.

#### 5. Verify connection

Use `nvim_state` to confirm you can read the editor state. Then use `nvim_send` to run
`:echo "connected"` to verify bidirectional communication.

### Development Loop

Follow this cycle when building or modifying a plugin:

#### Write
Edit the plugin's Lua files using the standard file editing tools (Write, Edit). The user's Neovim
config is at `~/.config/nvim/` and uses LazyVim.

#### Load
Source the plugin into the running Neovim instance:

```
nvim_send command: "source /path/to/plugin.lua"
```

Or for a Lazy-managed plugin, trigger a reload:

```
nvim_send command: "Lazy reload plugin-name"
```

#### Test
Run the plugin's commands or send keybinds to test functionality:

```
nvim_send command: "YourPluginCommand"
nvim_send keys: "<leader>xx"
```

#### Observe
Check for errors and inspect state:

```
nvim_send command: "messages"          -- check for errors/warnings
nvim_state                             -- read buffer contents, cursor, mode
nvim_send eval: "vim.diagnostic.get()" -- check LSP diagnostics
```

#### Iterate
Based on what you observe, fix issues and repeat the loop.

### Cleanup

When you're done, kill the Neovim instance and remove the socket:

```bash
nvim_send command: "qa!"
# or if that fails:
kill $(lsof -t /path/to/socket)
rm -f /path/to/socket
```

### Tips

- Always check `:messages` after sourcing — Lua errors appear there
- Use `nvim_send eval` to inspect Vim variables and Lua state
- Use `nvim_recipes` to discover available Neovim operations you might need
- If the plugin registers keymaps, verify them with `:map <key>` or `:verbose map <key>`
- For plugins that depend on other plugins, ensure they're installed via Lazy first
- Use `nvim_send command: "checkhealth plugin-name"` if the plugin provides a health check

## Testing

When a plugin is changed, run its test cases in `tests/` using nvim-mcp. Only run tests for
the plugin(s) that were modified. New plugins and features must include a test file.

### Running tests

1. Ask the user for the path to their incident-io/core repo
2. Start a headless Neovim instance cd'd into that repo (see Setup Workflow above)
3. Source the plugin and run through each test case in the relevant `tests/*.md` file
4. For each test case: navigate to the specified location, trigger the keymap, and verify
   the result matches the expected outcome
5. Report pass/fail for each case

### Test both the data layer AND the picker

Testing the data layer (calling `find()`, `find_all()` via `:lua`) is not sufficient. You must
also invoke the actual picker functions (`picker.api_pick()`, `picker.events_pick_all()`, etc.)
and check `:messages` for errors. Snacks pickers won't render in headless mode, but they will
surface Lua errors — a picker that silently does nothing in headless is likely crashing. Always
check `:messages` after invoking a picker function. Data functions returning correct results does
not mean the picker adapter is wired up correctly.

### Bug fixes: TDD approach

When fixing a bug, always use test-driven development:

1. **Investigate** the root cause — understand exactly what's wrong and what correct behavior is
2. **Write a failing test** in the relevant `tests/*.md` file that captures the bug
3. **Run the test** and confirm it fails
4. **Fix the code**
5. **Re-run the test** and confirm it passes
6. **Re-run existing tests** to check for regressions

Do not skip straight to a fix. The test documents the bug and prevents regressions.

### Writing tests for new features

New plugins and features must include a test file in `tests/`. Each test case should have:
- A short description of what's being tested
- The file:line to navigate to
- The keymap or command to trigger
- The expected result (item count, file navigated to, etc.)
- Edge cases (empty results, ambiguous cursor position, multiple event types in one file)

## Code Style

Each plugin file must start with a header comment that explains how it works for both AIs and
developers. The comment should cover:
- What the plugin does (one-line summary)
- Public API functions it exposes
- How it works internally (the search strategy, data flow, or key algorithm)
- Any non-obvious assumptions (e.g. expected directory structure, rg patterns, cwd)

See `api.lua`, `events.lua`, and `pickers/snacks.lua` for examples.

## Nerd Font Icons

### Which-key menu items

The plugin does not depend on which-key. Users who want the nf-md-fire icon (orange) can
add a which-key `icons.rules` entry matching the plugin name — see README.md for the snippet.

### Choosing icons

The user will pick icon names from the Nerd Fonts cheat sheet at https://www.nerdfonts.com/cheat-sheet
and give you the name (e.g. `nf-md-lightning_bolt`). To get the actual Unicode character:

1. **Find the codepoint.** Search the cheat sheet or fetch the canonical mapping:
   ```
   https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/glyphnames.json
   ```
   Find the icon name and note the hex codepoint from the `code` field.

2. **Use Lua Unicode escapes.** Write `\u{XXXXX}` with the hex codepoint directly in the
   string literal. Do NOT try to copy-paste the rendered character — it will get lost or
   corrupted passing through tool calls.
   ```lua
   { " \u{F140B} ", "DiagnosticInfo" },    -- nf-md-lightning_bolt
   ```

3. **Always comment the icon name** next to the escape so it's searchable on the cheat sheet.

### Picker style

Pickers should follow the pattern established in `pickers/snacks.lua` and `pickers/telescope.lua`:
- Badge definitions and filter mode constants live in the core module (e.g. `api.badges`, `events.filter_modes`)
- Each picker adapter handles its own formatting using the core module's badge constants
- Snacks adapter uses `Snacks.picker.format.filename(item, picker)` for file paths
- Telescope adapter uses `entry_display.create()` for column layout
- Nerd Font icon badge per item kind, colored with `DiagnosticInfo`/`DiagnosticWarn`/`DiagnosticHint`
- `text` field should contain only what the user would intuitively search for (e.g. event name,
  method name) — not code or file paths
- `<C-i>` filter toggle cycling through item kinds

## Documentation

Keep `README.md` up to date when adding or changing plugins. Style guidelines:

- Write from the user's perspective: what do I press, what happens
- Lead with the keymap inline in prose, not in tables
- Keep it concise — a couple of sentences per feature, no implementation details
- Don't list dependencies or explain how the plugin works internally (that's for header comments)
- Match the tone of the existing entries: direct, practical, no filler
