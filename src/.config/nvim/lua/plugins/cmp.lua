-- Detect whether the cursor sits inside a comment using the treesitter *tree*,
-- not the highlighter. The previous implementation used
-- vim.treesitter.get_captures_at_pos(), which returns {} the moment no
-- highlighter is attached to the buffer (see Neovim runtime treesitter.lua:
-- `if not buf_highlighter then return {} end`). That happens more often than
-- you'd think — buffer opened before treesitter loaded, parser still installing,
-- or LazyVim's big-file guard disabling highlight — and in every such case
-- in_comment() silently returned false, so ghost text was NOT suppressed in
-- comments (the "feature isn't working" bug). vim.treesitter.get_node() parses
-- on demand and does not need the highlighter, so it works regardless.
local function in_comment()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1 -- get_node expects a 0-indexed row
  -- In insert mode, check position one character to the left
  if vim.api.nvim_get_mode().mode == "i" then
    col = math.max(0, col - 1)
  end
  local ok, node = pcall(vim.treesitter.get_node, { pos = { row, col } })
  if not ok or not node then
    return false
  end
  -- Walk up ancestors: comment nodes vary by language (comment, line_comment,
  -- block_comment, comment_content, ...), so match any type containing "comment".
  while node do
    if node:type():find("comment") then
      return true
    end
    node = node:parent()
  end
  return false
end

return {
  -- Load blink.cmp types into lazydev so we get completions for opts
  {
    "folke/lazydev.nvim",
    opts = {
      library = {
        { path = "blink.cmp", words = { "blink.cmp" } },
      },
    },
  },
  {
    "saghen/blink.cmp",
    ---@type blink.cmp.Config
    opts = {
      completion = {
        menu = {
          auto_show = false,
        },
      },
    },
  },
}
