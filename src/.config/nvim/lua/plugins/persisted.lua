-- Session management with git branch support and picker
return {
  -- Disable the default persistence.nvim from LazyVim
  { "folke/persistence.nvim", enabled = false },

  -- Use persisted.nvim instead
  {
    "olimorris/persisted.nvim",
    lazy = false,
    opts = {
      autostart = true,
      autoload = false,
      use_git_branch = true, -- Sessions per git branch
      should_save = function()
        -- Don't save session if no buffers are open
        return vim.fn.argc() > 0 or vim.fn.len(vim.fn.getbufinfo({ buflisted = 1 })) > 0
      end,
    },
    config = function(_, opts)
      require("persisted").setup(opts)
    end,
    keys = {
      { "<leader>qs", "<cmd>Persisted select<cr>", desc = "Select Session" },
      { "<leader>ql", "<cmd>SessionLoad<cr>", desc = "Load Session" },
      { "<leader>qd", "<cmd>SessionDelete<cr>", desc = "Delete Session" },
      { "<leader>qS", "<cmd>SessionSave<cr>", desc = "Save Session" },
    },
  },
}
