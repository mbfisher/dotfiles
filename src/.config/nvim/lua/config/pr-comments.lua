-- :PRComments — load the latest PR review's comments into:
--   1. the quickfix list (for ]q/[q navigation, with a prettier formatter + soft-wrap)
--   2. diagnostics on each commented line (blue comment sign, view via <leader>cd)
--
-- Diagnostics use a dedicated namespace and INFO severity. INFO is blue in LazyVim's
-- default colorscheme (tokyonight), and INFO is unlikely to clash with LSP errors/warns
-- in the gutter. The sign text and virtual_text/underline are overridden per-namespace,
-- so this only affects our review-comment signs, not LSP INFO diagnostics.

local NS = vim.api.nvim_create_namespace("pr-comments")
-- nf-fa-comment_o (Nerd Font) — written as escape so the codepoint survives editor round-trips.
local COMMENT_ICON = "\u{f0e5}"

vim.diagnostic.config({
  signs = { text = { [vim.diagnostic.severity.INFO] = COMMENT_ICON } },
  -- Suppress inline noise: comment bodies are too long to live in virtual_text, and
  -- underlining whole lines makes the buffer visually noisy. The sign + open_float is enough.
  virtual_text = false,
  underline = false,
}, NS)

-- Path-keyed diagnostics, populated by :PRComments. We re-attach in BufReadPost so files
-- opened *after* :PRComments still get the signs (e.g. when navigating from the qf list).
local pending = {}

local function apply_to_buf(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return end
  local diags = pending[vim.fn.fnamemodify(name, ":p")]
  if diags and #diags > 0 then
    vim.diagnostic.set(NS, bufnr, diags)
  end
end

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("pr-comments-attach", { clear = true }),
  callback = function(args) apply_to_buf(args.buf) end,
})

-- Remove a comment from both the qf list and the diagnostic state. Used by `dd` in the qf
-- window — treats the line under the cursor as "this comment is addressed".
local function dismiss_at(idx)
  local items = vim.fn.getqflist()
  local target = items[idx]
  if not target or not target.user_data then return end
  local id = target.user_data

  local kept = {}
  for i, it in ipairs(items) do
    if i ~= idx then table.insert(kept, it) end
  end
  vim.fn.setqflist({}, "r", {
    items = kept,
    title = vim.fn.getqflist({ title = 0 }).title,
    quickfixtextfunc = "v:lua.PRCommentsQfText",
  })

  for path, diags in pairs(pending) do
    local pruned = {}
    for _, d in ipairs(diags) do
      if d.user_data ~= id then table.insert(pruned, d) end
    end
    pending[path] = pruned
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= "" and vim.fn.fnamemodify(name, ":p") == path then
          -- vim.diagnostic.set with an empty list clears; non-empty replaces.
          vim.diagnostic.set(NS, buf, pruned)
        end
      end
    end
  end

  if #kept == 0 then
    vim.cmd("cclose")
  else
    -- Keep cursor near the removed entry so `dd` repeats naturally.
    vim.fn.cursor(math.min(idx, #kept), 1)
  end
end

-- Soft-wrap the qf window AND bind `dd` to dismiss the comment under the cursor — but only for
-- our PR-review list (matched by title), so other qf lists (`:grep`, LSP refs, etc.) are untouched.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  group = vim.api.nvim_create_augroup("pr-comments-qf-wrap", { clear = true }),
  callback = function(args)
    local title = vim.fn.getqflist({ title = 0 }).title or ""
    if not title:match("^PR review") then return end
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
    vim.keymap.set("n", "dd", function() dismiss_at(vim.fn.line(".")) end, {
      buffer = args.buf,
      desc = "Mark PR comment as addressed (remove from qf + diagnostics)",
    })
  end,
})

-- Custom qf renderer: "<icon> path:line │ @author: message".
-- No truncation — soft-wrap (set above) handles long bodies.
function _G.PRCommentsQfText(info)
  local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
  local lines = {}
  for i = info.start_idx, info.end_idx do
    local item = items[i]
    local fname = item.bufnr > 0 and vim.fn.bufname(item.bufnr) or ""
    fname = vim.fn.fnamemodify(fname, ":.")
    lines[#lines + 1] = string.format("%s  %s:%d  │  %s", COMMENT_ICON, fname, item.lnum, item.text)
  end
  return lines
end

local function gh_json(args)
  local out = vim.fn.system(vim.list_extend({ "gh" }, args))
  if vim.v.shell_error ~= 0 then
    vim.notify("gh " .. table.concat(args, " ") .. " failed:\n" .. out, vim.log.levels.ERROR)
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok then
    vim.notify("Failed to parse gh output: " .. decoded, vim.log.levels.ERROR)
    return nil
  end
  return decoded
end

vim.api.nvim_create_user_command("PRComments", function()
  local pr = gh_json({ "pr", "view", "--json", "number" })
  if not pr then return end

  -- gh api substitutes {owner}/{repo} from the current repo's default remote.
  local reviews = gh_json({ "api", string.format("repos/{owner}/{repo}/pulls/%d/reviews", pr.number) })
  if not reviews or #reviews == 0 then
    vim.notify("No reviews on PR #" .. pr.number, vim.log.levels.WARN)
    return
  end
  -- Use the PR-scoped /comments endpoint, NOT /reviews/{id}/comments — the latter returns
  -- `line: null` and only the diff `position`. The PR-scoped endpoint returns file `line`,
  -- and each comment carries `pull_request_review_id` so we can filter to a specific review.
  local comments = gh_json({ "api", "--paginate",
    string.format("repos/{owner}/{repo}/pulls/%d/comments", pr.number) })
  if not comments then return end

  -- Pick the latest review that has top-level comments (not replies). Naively picking the
  -- newest review by submitted_at breaks the moment you reply to a comment yourself: GitHub
  -- treats each reply as its own one-comment "review", so the "latest review" becomes a reply
  -- to a reply, not the original feedback you want to step through.
  local by_review = {}
  for _, c in ipairs(comments) do
    local parent = c.in_reply_to_id
    if parent == nil or parent == vim.NIL then
      by_review[c.pull_request_review_id] = by_review[c.pull_request_review_id] or {}
      table.insert(by_review[c.pull_request_review_id], c)
    end
  end

  local latest_id, latest_time
  for _, r in ipairs(reviews) do
    if by_review[r.id] and (not latest_time or (r.submitted_at or "") > latest_time) then
      latest_id = r.id
      latest_time = r.submitted_at or ""
    end
  end
  if not latest_id then
    vim.notify("No top-level review comments on PR #" .. pr.number, vim.log.levels.WARN)
    return
  end
  comments = by_review[latest_id]

  -- Reset prior state so a re-run doesn't pile up stale signs/qf entries.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.diagnostic.reset(NS, buf)
  end
  pending = {}

  local qf = {}
  for _, c in ipairs(comments) do
    local lnum = c.line
    if lnum == nil or lnum == vim.NIL then lnum = c.original_line end
    if lnum == nil or lnum == vim.NIL then lnum = 1 end
    local body = c.body or ""
    local author = (c.user and c.user.login) or "?"
    local one_line = ("@" .. author .. ": " .. body):gsub("\n", " ")

    -- user_data is the GitHub comment id, used by `dd` in the qf window to match a qf row
    -- to its corresponding diagnostic and drop both atomically.
    table.insert(qf, { filename = c.path, lnum = lnum, col = 1, text = one_line, user_data = c.id })

    local abs = vim.fn.fnamemodify(c.path, ":p")
    pending[abs] = pending[abs] or {}
    table.insert(pending[abs], {
      lnum = lnum - 1, -- vim.diagnostic uses 0-indexed lines
      col = 0,
      end_col = 0,
      severity = vim.diagnostic.severity.INFO,
      source = "PR review",
      -- Keep newlines so open_float renders the body with paragraphs intact.
      message = "@" .. author .. ":\n" .. body,
      user_data = c.id,
    })
  end

  if #qf == 0 then
    vim.notify("Latest review on PR #" .. pr.number .. " has no inline comments", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, "r", {
    items = qf,
    title = "PR review " .. latest_id,
    quickfixtextfunc = "v:lua.PRCommentsQfText",
  })

  -- Attach to already-open buffers (BufReadPost handles the rest as they're opened).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      apply_to_buf(buf)
    end
  end

  vim.cmd("copen")
end, { desc = "Load latest PR review's comments into quickfix + diagnostics" })
