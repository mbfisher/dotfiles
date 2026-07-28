return {
  { "folke/lazydev.nvim", opts = { library = { { path = "claudecode.nvim", words = { "claudecode" } } } } },
  -- Register <leader>a which-key group for AI keymaps
  { "folke/which-key.nvim", opts = { spec = { { "<leader>a", group = "ai", icon = "󰚩", mode = { "n", "v" } } } } },
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    ---@type ClaudeCodeConfig
    opts = {
      -- Run Claude Code inside Neovim in a persistent LEFT vertical split (was
      -- provider = "none", which assumed Claude ran in an external terminal and
      -- connected via /ide). The snacks provider keeps one terminal instance and
      -- hides/shows it, so toggling reopens the same session rather than starting
      -- a new one. An external Claude can still connect via /ide, but ClaudeCodeSend
      -- now targets this in-editor instance.
      terminal = {
        provider = "snacks",
        split_side = "left",
        -- 33% to match the shell terminal's default; Option+[ / Option+] cycle it live
        -- (33/50/66) via the left-split resize keymaps in config/keymaps.lua.
        split_width_percentage = 0.33,
        -- stack = false because util/sidebar places this window itself — snacks' own
        -- stacking would put Claude BELOW the shell, and it misfires entirely once this
        -- provider has recreated the window by hand. See the note in util/sidebar.lua.
        snacks_win_opts = { stack = false },
      },
    },
    keys = {
      -- Every toggle goes through util/sidebar so Claude lands in the top half of the left
      -- column, sharing it with the <C-/> shell rather than opening a third split.
      -- ClaudeCode = plain show/hide toggle; ClaudeCodeFocus jumps to the split if
      -- it's open but unfocused, and only hides once you're already in it.
      --
      -- <C-;> mirrors <C-/>: mapped in terminal mode too, so it works from inside Claude
      -- itself or the shell — a <leader> sequence can't, since it goes to the Claude prompt.
      -- Ghostty sends it as CSI u text so it survives zellij (see ghostty/config).
      {
        "<C-;>",
        require("util.sidebar").claude("ClaudeCode"),
        mode = { "n", "t" },
        desc = "Claude Code (toggle)",
      },
      { "<leader>ac", require("util.sidebar").claude("ClaudeCode"), desc = "Claude Code (toggle)" },
      { "<leader>af", require("util.sidebar").claude("ClaudeCodeFocus"), desc = "Claude Code (focus)" },
      -- The terminal dies with nvim, so --continue is the way to pick the last
      -- conversation back up after a restart.
      {
        "<leader>aC",
        require("util.sidebar").claude("ClaudeCode --continue"),
        desc = "Claude Code (continue last)",
      },
      -- No <leader>ab (ClaudeCodeAdd %): with track_selection on (the default) the plugin
      -- already broadcasts the active buffer + cursor to Claude, so manually @-mentioning
      -- the current file is redundant now the session runs in-editor.
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
    },
  },
}
