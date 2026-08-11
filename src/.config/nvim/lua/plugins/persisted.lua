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

      -- Diffview's tabs hold git-blob buffers (index contents, "null" for added/deleted files)
      -- that only make sense for the session that opened them. Left open, they get baked into the
      -- saved session like any other tab, so restoring later reloads them as ordinary buffers —
      -- diffview never re-attaches, so its close-time cleanup (lua/plugins/diffview.lua) never
      -- runs and they linger in the bufferline forever. Closing every view before a save keeps
      -- them out of the session file in the first place.
      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistedSavePre",
        callback = function()
          for _, view in ipairs(require("diffview.lib").views) do
            require("diffview").close(view.tabpage, { force = true })
          end
        end,
      })
    end,
    keys = {
      { "<leader>qs", "<cmd>Persisted select<cr>", desc = "Select Session" },
      { "<leader>ql", "<cmd>SessionLoad<cr>", desc = "Load Session" },
      { "<leader>qd", "<cmd>SessionDelete<cr>", desc = "Delete Session" },
      { "<leader>qS", "<cmd>SessionSave<cr>", desc = "Save Session" },
    },
  },
}
