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
        split_width_percentage = 0.4,
      },
    },
    keys = {
      -- ClaudeCode = plain show/hide toggle; ClaudeCodeFocus jumps to the split if
      -- it's open but unfocused, and only hides once you're already in it.
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude Code (toggle)" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude Code (focus)" },
      -- The terminal dies with nvim, so --continue is the way to pick the last
      -- conversation back up after a restart.
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude Code (continue last)" },
      -- No <leader>ab (ClaudeCodeAdd %): with track_selection on (the default) the plugin
      -- already broadcasts the active buffer + cursor to Claude, so manually @-mentioning
      -- the current file is redundant now the session runs in-editor.
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
    },
  },
}
