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
      { "<leader>gD", false }, -- reserved for diffview's PR-preview diff
    },
    -- Route the snacks GitHub PR picker's "View PR diff" action into diffview
    -- instead of the built-in snacks gh_diff picker. Flow: <leader>gp -> pick a PR
    -- -> "View PR diff". We only swap that one action's function, so live search,
    -- comments, and every other PR action stay exactly as snacks provides them.
    -- Also adds a "Checkout & review in diffview" action (gh_diffview_review) to the same menu.
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

          -- Spinner notification for slow async git work; returns finish(msg, level), which swaps
          -- the spinner (same id) for the outcome.
          local function spinner(notif, msg)
            local done = false
            local timer = assert(vim.uv.new_timer())
            timer:start(
              0,
              80,
              vim.schedule_wrap(function()
                if done then
                  return
                end
                Snacks.notify(Snacks.util.spinner() .. "  " .. msg, {
                  id = notif,
                  title = "Diffview",
                  timeout = false, -- keep it up until the work finishes
                })
              end)
            )
            return function(text, level)
              done = true
              timer:stop()
              timer:close()
              Snacks.notify(text, {
                id = notif,
                title = "Diffview",
                level = level,
                timeout = level == "error" and 5000 or 1000,
              })
            end
          end

          gh.actions.gh_diff.action = function(item, ctx)
            if not item then
              return
            end
            -- Not the current repo → let snacks handle it (raw origin fetch wouldn't apply).
            if item.repo and origin_repo() and item.repo ~= origin_repo() then
              return fallback(item, ctx)
            end
            local pr = item.number
            local ref = "origin/pr/" .. pr
            local finish = spinner("diffview-pr-fetch-" .. pr, "Fetching PR #" .. pr .. "…")

            -- Raw fetch of the PR head (refs/pull/N/head) into a local-tracking ref,
            -- plus the branches refspec so origin/HEAD's merge-base is current. No
            -- checkout — the working tree is left untouched.
            vim.system({
              "git",
              "fetch",
              "origin",
              "+refs/heads/*:refs/remotes/origin/*",
              "pull/" .. pr .. "/head:refs/remotes/" .. ref,
            }, { text = true }, vim.schedule_wrap(function(res)
              if res.code ~= 0 then
                finish("Fetch failed for PR #" .. pr .. "\n" .. (res.stderr or ""), "error")
                return
              end
              finish("PR #" .. pr .. " fetched")
              -- Symmetric diff against the merge-base: the true "what this PR changes" view.
              vim.cmd("DiffviewOpen origin/HEAD..." .. ref)
            end))
          end

          -- "Review PR": check the PR branch out, then open its diff in a new diffview tab with the
          -- working tree on the right. Because the right side is the real files, the original tab
          -- holds ordinary buffers on the PR branch (LSP, gd, etc. all work), and gf on a file in
          -- the diffview panel opens it in that previous tab.
          gh.actions.gh_diffview_review = {
            desc = "Checkout & review in diffview",
            icon = " ",
            priority = 100,
            type = "pr",
            title = "Checkout & review PR #{number} in diffview",
            action = function(item)
              if not item then
                return
              end
              if item.repo and origin_repo() and item.repo ~= origin_repo() then
                Snacks.notify.error("PR #" .. item.number .. " is in " .. item.repo .. ", not this repo")
                return
              end
              -- gh pr checkout refuses to clobber local changes anyway; say so up front instead.
              local dirty = vim.system({ "git", "status", "--porcelain", "--untracked-files=no" }, { text = true }):wait()
              if vim.trim(dirty.stdout or "") ~= "" then
                Snacks.notify.error("Working tree has uncommitted changes — stash or commit before checking out a PR")
                return
              end

              local pr = tostring(item.number)
              local finish = spinner("diffview-pr-review-" .. pr, "Checking out PR #" .. pr .. "…")
              local function fail(what, res)
                finish(what .. " failed for PR #" .. pr .. "\n" .. (res.stderr or ""), "error")
              end

              vim.system({ "gh", "pr", "checkout", pr }, { text = true }, vim.schedule_wrap(function(co)
                if co.code ~= 0 then
                  return fail("Checkout", co)
                end
                -- Reload any open buffers so the first tab shows the PR branch's contents.
                vim.cmd("checktime")
                -- Refresh origin's branches so the merge-base with origin/HEAD is current.
                vim.system(
                  { "git", "fetch", "origin", "+refs/heads/*:refs/remotes/origin/*" },
                  { text = true },
                  vim.schedule_wrap(function(fe)
                    if fe.code ~= 0 then
                      return fail("Fetch", fe)
                    end
                    local mb = vim.system({ "git", "merge-base", "origin/HEAD", "HEAD" }, { text = true }):wait()
                    if mb.code ~= 0 then
                      return fail("merge-base", mb)
                    end
                    finish("Checked out PR #" .. pr)
                    -- Single rev → working tree on the right, so diffview edits the real files.
                    vim.cmd("DiffviewOpen " .. vim.trim(mb.stdout))
                  end)
                )
              end))
            end,
          }
        end,
      })
    end,
    ---@type snacks.Config
    opts = {
      styles = {
        -- Put every snacks terminal (e.g. the <C-/> shell) on the terminal colour scheme via
        -- TerminalNormal, which colorscheme.lua defines from Ghostty's own values — see
        -- docs/colours.md. Without this they inherit SnacksNormal -> onedark NormalFloat (bg1,
        -- lighter than the terminal's own background), which looks washed out. No colours here,
        -- only group names.
        -- The whole winhighlight string replaces snacks' default, so the non-Normal mappings are
        -- repeated verbatim from snacks' win defaults to keep winbar/border styling intact.
        terminal = {
          wo = {
            winhighlight = table.concat({
              "Normal:TerminalNormal",
              "NormalNC:TerminalNormal",
              "WinBar:SnacksWinBar",
              "WinBarNC:SnacksWinBarNC",
              "FloatTitle:SnacksTitle",
              "FloatFooter:SnacksFooter",
              "WinSeparator:TerminalWinSeparator",
            }, ","),
          },
        },
      },
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
