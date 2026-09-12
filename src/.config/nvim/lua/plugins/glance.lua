-- glance.nvim: VSCode-style "peek" window for LSP results.
-- Glance ships no global keymaps of its own, so we override LazyVim's default LSP
-- nav keys (gd/gr/gI/gy) to route through :Glance instead of jumping. Plain global
-- mappings don't win because LazyVim sets these buffer-locally in its LSP
-- on_attach; the canonical override is to extend its LSP keymap list, which
-- dedupes by lhs and replaces the action.
-- Reuse Neotest's public window picker so `i` has the same labelled A/B/C prompt as its summary.
-- Glance closes its floats before running cmd, leaving only the real code windows to choose from.
local function jump_with_window_picker(actions)
  return function()
    actions.jump({
      cmd = function(item)
        local bufnr = item.bufnr
        if not vim.api.nvim_buf_is_valid(bufnr) then
          bufnr = vim.fn.bufadd(item.filename)
          vim.fn.bufload(bufnr)
        end
        vim.bo[bufnr].buflisted = true
        require("neotest.lib").ui.open_buf(bufnr, item.start_line, item.start_col)
      end,
    })
  end
end

return {
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    -- Spatial focus switch: preview (code) renders on the left, list
    -- (references) on the right, so H (like <S-h> "prev buffer") jumps left
    -- into the preview and L (like <S-l> "next buffer") jumps right into the
    -- list — matching the left/right muscle memory those keys already have.
    -- Safe to shadow normal-mode H/L (viewport top/bottom) because glance's
    -- mappings are buffer-local to the peek windows. opts is a function so we
    -- can require glance only when it's being loaded (cmd = "Glance" lazy-loads it).
    opts = function()
      local actions = require("glance").actions
      return {
        mappings = {
          list = {
            ["H"] = actions.enter_win("preview"),
            ["i"] = jump_with_window_picker(actions),
          },
          preview = { ["L"] = actions.enter_win("list") },
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
