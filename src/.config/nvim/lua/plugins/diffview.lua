-- ============================================================================
-- The diffview way: review, stage, unstage and revert — all in one tab.
-- ============================================================================
-- Open with <leader>gd. If a diffview tab is already open it switches to it
-- instead of spawning a duplicate. Press g? in any diffview window for the full
-- keymap list.
--
-- THE ONE IDEA: staging is just editing the INDEX buffer and saving it (:w).
-- Each file shows two versions:
--   * index buffer      = "what will be committed"  (editable)
--   * working-tree buffer = your actual file on disk
-- Make the index buffer say what you want, then :w. The panel keys below are
-- just shortcuts for the whole-file version of that.
--
-- WHERE EACH BUFFER SITS:
--   Changes (unstaged) section:  LEFT = index (editable)   RIGHT = working tree
--   Staged changes section:      LEFT = HEAD (read-only)    RIGHT = index (editable)
--   (The index window's title always contains ":0:".)
--
-- 90% LOOP — whole files, from the file panel:
--   <Tab> / <S-Tab>   next / previous file (review them in order)
--   -  or  s          stage / unstage the file under the cursor
--   S  /  U           stage all / unstage all
--   X                 discard the file's changes entirely (revert whole file)
--
-- HUNK-LEVEL — without leaving diffview. Jump hunks with ]c / [c, then:
--   Stage one hunk (Changes section):   cursor on hunk in the working-tree (RIGHT)
--                                       window -> dp (push into index) -> <C-w>h -> :w
--   Unstage one hunk (Staged section):  index is the RIGHT window here; edit it to
--                                       drop the hunk (or do/dp from HEAD) -> :w
--   Revert one hunk (throw it away):    cursor on hunk in working-tree window ->
--                                       do (obtain original from index/LEFT) -> :w
--   do = obtain from the OTHER window; dp = put into the OTHER window.
--   Mnemonic: decide which buffer is the index, make it say what should be staged, :w.
--   Overshot? U unstages everything and you start over — cheap to experiment.
--
-- WHEN DONE: diffview leaves committing to your git tooling. Close the view with
-- :DiffviewClose (or :tabclose) and commit however you like.
-- ============================================================================
return {
  { "folke/lazydev.nvim", opts = { library = { { path = "diffview-plus.nvim", words = { "diffview" } } } } },
  {
    -- Maintained fork of sindrets/diffview.nvim (drop-in: same DiffviewOpen/FileHistory commands, same require("diffview")).
    "dlyongemallo/diffview-plus.nvim",
    version = "*",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      -- Primary git flow: review + stage uncommitted changes (stage/unstage hunks or files with `-` in the file panel).
      -- DiffviewOpen reuses an already-open diffview tab if one exists (switches to it) rather than spawning a duplicate.
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working changes)" },
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
