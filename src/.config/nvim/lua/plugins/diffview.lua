-- ============================================================================
-- The diffview way: review, stage, unstage and revert — all in one tab.
-- ============================================================================
-- Open with <leader>gd. If a diffview tab is already open it switches to it
-- instead of spawning a duplicate. Press g? in any diffview window for the full
-- keymap list. <leader>gD does the same for a PR preview: everything on this branch, committed and
-- uncommitted, against a freshly fetched origin base branch.
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
-- <leader>gD: "what would my PR look like?" — the diff GitHub would show if I opened a PR right
-- now, except taken against the live working tree so uncommitted changes are in it too. Fetching
-- origin is slow on big repos, so it runs async (vim.system) behind a spinner notification rather
-- than freezing the UI — same pattern as the PR picker action in plugins/snacks.lua.
local function pr_diff()
  local notif = "diffview-pr-diff"
  local done = false
  local timer = assert(vim.uv.new_timer())
  timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      if done then
        return
      end
      Snacks.notify(Snacks.util.spinner() .. "  Fetching origin…", {
        id = notif,
        title = "Diffview",
        timeout = false, -- keep it up until the fetch finishes
      })
    end)
  )

  -- Replaces the spinner notification (same id) with the outcome.
  local function finish(msg, level)
    done = true
    timer:stop()
    timer:close()
    Snacks.notify(msg, {
      id = notif,
      title = "Diffview",
      level = level,
      timeout = level == "error" and 5000 or 1000,
    })
  end

  vim.system(
    { "git", "fetch", "origin", "+refs/heads/*:refs/remotes/origin/*" },
    { text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        finish("Fetch failed\n" .. (res.stderr or ""), "error")
        return
      end

      -- Base branch is whatever origin/HEAD points at (master here, main elsewhere); fall back to
      -- the usual names for clones where the remote HEAD ref was never set up locally.
      local base
      for _, ref in ipairs({ "origin/HEAD", "origin/master", "origin/main" }) do
        if vim.system({ "git", "rev-parse", "--verify", "--quiet", ref }):wait().code == 0 then
          base = ref
          break
        end
      end
      if not base then
        finish("No origin/HEAD, origin/master or origin/main", "error")
        return
      end

      -- Merge-base rather than the branch tip, because GitHub's PR diff ignores commits landed on
      -- the base branch since we branched. Handing diffview a single rev puts the working tree on
      -- the right-hand side, so committed and uncommitted changes appear together.
      local mb = vim.system({ "git", "merge-base", base, "HEAD" }, { text = true }):wait()
      if mb.code ~= 0 then
        finish("No merge base with " .. base, "error")
        return
      end

      finish("Diffing working tree against " .. base)
      vim.cmd("DiffviewOpen " .. vim.trim(mb.stdout))
    end)
  )
end

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
      { "<leader>gD", pr_diff, desc = "Diff view (PR preview vs origin)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
    -- Clean up buffers that diffview opened when it closes. (Making the tabline visible for
    -- diffview's tab is handled in plugins/bufferline.lua — setting 'showtabline' here didn't
    -- stick, since bufferline resets it on every redraw.)
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
      -- Enable horizontal mouse scroll in all diffview windows (Keychron M6 horizontal wheel).
      -- Same caveat as config/keymaps.lua: zellij never forwards these events, so they only fire
      -- in a bare ghostty pane. See zellij-org/zellij#4628.
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
