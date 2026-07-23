-- Show hidden files (dotfiles) by default in file and grep pickers.
-- Toggle with <Alt-h> while picker is open.
-- See: https://github.com/LazyVim/LazyVim/discussions/6807
return {
  { "folke/lazydev.nvim", opts = { library = { { path = "snacks.nvim", words = { "snacks" } } } } },
  {
    "folke/snacks.nvim",
    -- Keep <leader>gd / <leader>gD clear for diffview. (diffview.lua actively
    -- claims <leader>gd and <leader>gh, so LazyVim skips its own versions anyway;
    -- these are belt-and-braces.) LazyVim's lazygit binds (<leader>gg / <leader>gG)
    -- are intentionally left untouched — unused, but kept so any future upstream
    -- changes carry through.
    keys = {
      { "<leader>gd", false }, -- reserved for diffview
      { "<leader>gD", false }, -- unused
    },
    -- Route the snacks GitHub PR picker's "View PR diff" action into diffview
    -- instead of the built-in snacks gh_diff picker. Flow: <leader>gp -> pick a PR
    -- -> "View PR diff". We only swap that one action's function, so live search,
    -- comments, and every other PR action stay exactly as snacks provides them.
    -- Applied on VeryLazy because snacks (and its gh submodule) are loaded by then.
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          local ok, gh = pcall(require, "snacks.gh.actions")
          if not ok or not (gh.actions and gh.actions.gh_diff) then
            return
          end
          -- Keep the original so we can fall back for PRs in a different repo,
          -- where a raw `origin` fetch would resolve the wrong (or no) PR.
          local fallback = gh.actions.gh_diff.action

          -- Best-effort "owner/repo" of origin, to compare against the picked PR's repo.
          local function origin_repo()
            local url = vim.fn.systemlist({ "git", "config", "--get", "remote.origin.url" })[1] or ""
            return (url:gsub("%.git$", "")):match("([^/:]+/[^/]+)$")
          end

          gh.actions.gh_diff.action = function(item, ctx)
            if not item then
              return
            end
            -- Not the current repo → let snacks handle it (raw origin fetch wouldn't apply).
            if item.repo and origin_repo() and item.repo ~= origin_repo() then
              return fallback(item, ctx)
            end
            local ref = "origin/pr/" .. item.number
            -- Raw fetch of the PR head (refs/pull/N/head) into a local-tracking ref,
            -- plus the branches refspec so origin/HEAD's merge-base is current. No
            -- checkout — the working tree is left untouched.
            local out = vim.fn.system({
              "git",
              "fetch",
              "origin",
              "+refs/heads/*:refs/remotes/origin/*",
              "pull/" .. item.number .. "/head:refs/remotes/" .. ref,
            })
            if vim.v.shell_error ~= 0 then
              vim.notify("git fetch failed:\n" .. out, vim.log.levels.ERROR)
              return
            end
            -- Symmetric diff against the merge-base: the true "what this PR changes" view.
            vim.cmd("DiffviewOpen origin/HEAD..." .. ref)
          end
        end,
      })
    end,
    ---@type snacks.Config
    opts = {
      picker = {
        -- <c-f> in grep picker: toggle off live mode and append " file:" to input
        -- so you can immediately filter results by filename/path
        actions = {
          filter_by_file = function(picker)
            if picker.opts.live then
              picker.opts.live = false
              picker.input:set()
            end
            vim.api.nvim_win_call(picker.input.win.win, function()
              vim.api.nvim_put({ " file:" }, "c", true, true)
            end)
            picker.input:update()
          end,
        },
        win = {
          input = {
            keys = {
              ["<c-f>"] = { "filter_by_file", mode = { "i", "n" } },
            },
          },
        },
        sources = {
          files = {
            hidden = true,
          },
          grep = {
            hidden = true,
          },
          explorer = {
            hidden = true,
          },
        },
      },
    },
  },
}
