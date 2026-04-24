return {
  { "folke/lazydev.nvim", opts = { library = { { path = "claudecode.nvim", words = { "claudecode" } } } } },
  -- Register <leader>a which-key group for AI keymaps
  { "folke/which-key.nvim", opts = { spec = { { "<leader>a", group = "ai", icon = "󰚩", mode = { "n", "v" } } } } },
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    ---@type ClaudeCodeConfig
    opts = {
      -- Disable built-in terminal; Claude Code runs in an external terminal
      -- and connects via /ide. Without this, ClaudeCodeSend opens a new
      -- Claude Code instance inside Neovim instead of sending to the
      -- connected one.
      terminal = {
        provider = "none",
      },
    },
    keys = {
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer to context" },
    },
  },
}
