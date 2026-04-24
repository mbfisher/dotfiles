return {
  { "folke/lazydev.nvim", opts = { library = { { path = "diffview.nvim", words = { "diffview" } } } } },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working changes)" },
      -- Three-dot diff: fetch first so origin/master is current, then show only this branch's changes (like GitHub PR view)
      {
        "<leader>gD",
        function()
          vim.notify("Fetching origin...")
          vim.fn.jobstart("git fetch", {
            on_exit = function(_, code)
              vim.schedule(function()
                if code == 0 then
                  vim.cmd("DiffviewOpen origin/master...HEAD")
                else
                  vim.notify("git fetch failed", vim.log.levels.ERROR)
                end
              end)
            end,
          })
        end,
        desc = "Diff view (vs origin/master)",
      },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
    -- Force tabline visible when diffview opens (so tab indicators show even with 1 buffer),
    -- then restore tabline and clean up buffers that diffview opened when it closes.
    init = function()
      local pre_diffview_bufs = {}

      vim.api.nvim_create_autocmd("User", {
        pattern = "DiffviewViewOpened",
        callback = function()
          -- Remember which buffers existed before diffview
          pre_diffview_bufs = {}
          for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
            pre_diffview_bufs[buf.bufnr] = true
          end
          vim.o.showtabline = 2
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "DiffviewViewClosed",
        callback = function()
          -- Delete buffers that were opened by diffview (not present before)
          for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
            if not pre_diffview_bufs[buf.bufnr] then
              pcall(vim.api.nvim_buf_delete, buf.bufnr, {})
            end
          end
          pre_diffview_bufs = {}
          vim.o.showtabline = vim.fn.len(vim.fn.getbufinfo({ buflisted = 1 })) > 1 and 2 or 0
        end,
      })
    end,
    ---@type DiffviewConfig
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal", -- side-by-side diff
        },
      },
      file_panel = {
        win_config = {
          position = "left",
          width = 35,
        },
      },
      -- Enable horizontal mouse scroll in all diffview windows (Keychron M6 horizontal wheel)
      keymaps = {
        view = {
          { "n", "<ScrollWheelLeft>", "3zh" },
          { "n", "<ScrollWheelRight>", "3zl" },
        },
        file_panel = {
          { "n", "<ScrollWheelLeft>", "3zh" },
          { "n", "<ScrollWheelRight>", "3zl" },
        },
        file_history_panel = {
          { "n", "<ScrollWheelLeft>", "3zh" },
          { "n", "<ScrollWheelRight>", "3zl" },
        },
      },
    },
  },
}
