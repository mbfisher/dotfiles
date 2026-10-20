-- Teamtype: peer-to-peer live collaboration (formerly Ethersync). Needs the `teamtype` binary from the Brewfile.
-- Run `teamtype share` (host) or `teamtype join <code>` (guest) in the project dir, then open files in nvim.
return {
  {
    "teamtype/teamtype-nvim",
    -- Must load eagerly so it can attach to buffers inside a shared (`.teamtype`) directory.
    lazy = false,
    keys = {
      { "<leader>Tj", "<cmd>TeamtypeJumpToCursor<cr>", desc = "Jump to peer cursor" },
      { "<leader>Tf", "<cmd>TeamtypeFollow<cr>", desc = "Follow peer" },
      { "<leader>Ti", "<cmd>TeamtypeInfo<cr>", desc = "Teamtype info" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>T", group = "teamtype" } } },
  },
}
