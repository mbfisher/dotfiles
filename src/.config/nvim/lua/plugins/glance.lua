-- glance.nvim: VSCode-style "peek" window for LSP results.
-- Glance ships no global keymaps of its own, so we override LazyVim's default LSP
-- nav keys (gd/gr/gI/gy) to route through :Glance instead of jumping. Plain global
-- mappings don't win because LazyVim sets these buffer-locally in its LSP
-- on_attach; the canonical override is to extend its LSP keymap list, which
-- dedupes by lhs and replaces the action.
-- gD (declaration) is left alone — glance has no equivalent command.
return {
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    -- Spatial focus switch: list lives on the left, preview on the right, so
    -- H jumps focus to the list and L to the preview. Safe to shadow the
    -- normal-mode H/L (viewport top/bottom) because glance's mappings are
    -- buffer-local to the peek windows. opts is a function so we can require
    -- glance only when it's being loaded (cmd = "Glance" lazy-loads it).
    opts = function()
      local actions = require("glance").actions
      return {
        mappings = {
          list = { ["L"] = actions.enter_win("preview") },
          preview = { ["H"] = actions.enter_win("list") },
        },
      }
    end,
  },
  {
    "neovim/nvim-lspconfig",
    -- Set LSP nav keys via servers["*"].keys (the canonical LazyVim hook).
    -- The older require("lazyvim.plugins.lsp.keymaps").get() approach is
    -- deprecated and warns at startup. Resolve dedupes by lhs, so these
    -- override LazyVim's defaults (e.g. snacks picker's gd) since user
    -- plugin specs load after the built-in extras.
    opts = {
      servers = {
        ["*"] = {
          keys = {
            { "gd", "<cmd>Glance definitions<cr>", desc = "Goto Definition (Glance)", has = "definition" },
            { "gr", "<cmd>Glance references<cr>", desc = "References (Glance)", nowait = true },
            { "gI", "<cmd>Glance implementations<cr>", desc = "Goto Implementation (Glance)" },
            { "gy", "<cmd>Glance type_definitions<cr>", desc = "Goto Type Definition (Glance)" },
          },
        },
      },
    },
  },
}
