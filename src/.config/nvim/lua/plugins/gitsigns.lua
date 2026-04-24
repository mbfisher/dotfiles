return {
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      -- Disable default gitsigns diff/hunks bindings so diffview.lua can use <leader>gd and <leader>gh
      { "<leader>gd", false },
      { "<leader>gh", false },
      -- Toggle between HEAD (uncommitted) and master (branch diff)
      {
        "<leader>gm",
        function()
          local gs = require("gitsigns")
          local current_base = vim.b.gitsigns_base
          if current_base == "master" then
            gs.change_base(nil, true) -- Reset to HEAD
            vim.notify("Gitsigns: showing uncommitted changes", vim.log.levels.INFO)
          else
            gs.change_base("master", true)
            vim.notify("Gitsigns: showing diff from master", vim.log.levels.INFO)
          end
        end,
        desc = "Toggle gitsigns base (HEAD/master)",
      },
    },
  },
}
