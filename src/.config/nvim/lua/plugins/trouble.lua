-- Jump to next/prev diagnostic in current buffer via Trouble,
-- mapped under <leader>x so it shows in the which-key diagnostics menu.
return {
  {
    "folke/trouble.nvim",
    keys = {
      {
        "<leader>xn",
        function()
          require("trouble").next({ mode = "diagnostics", jump = true, filter = { buf = 0 } })
        end,
        desc = "Next Diagnostic (buffer)",
      },
      {
        "<leader>xp",
        function()
          require("trouble").prev({ mode = "diagnostics", jump = true, filter = { buf = 0 } })
        end,
        desc = "Prev Diagnostic (buffer)",
      },
    },
  },
}
