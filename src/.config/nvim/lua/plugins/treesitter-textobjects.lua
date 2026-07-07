return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  event = "VeryLazy",
  config = function()
    local move = require("nvim-treesitter-textobjects.move")
    local map = function(lhs, fn, desc)
      vim.keymap.set({ "n", "x", "o" }, lhs, fn, { desc = desc })
    end

    -- Parameters / arguments
    map("]a", function() move.goto_next_start("@parameter.inner", "textobjects") end, "Next argument")
    map("[a", function() move.goto_previous_start("@parameter.inner", "textobjects") end, "Prev argument")

    -- Functions
    map("]m", function() move.goto_next_start("@function.outer", "textobjects") end, "Next function")
    map("[m", function() move.goto_previous_start("@function.outer", "textobjects") end, "Prev function")
    map("]M", function() move.goto_next_end("@function.outer", "textobjects") end, "Next function end")
    map("[M", function() move.goto_previous_end("@function.outer", "textobjects") end, "Prev function end")

    -- Classes / blocks
    map("]]", function() move.goto_next_start("@class.outer", "textobjects") end, "Next class")
    map("[[", function() move.goto_previous_start("@class.outer", "textobjects") end, "Prev class")
  end,
}
