-- Detect whether the cursor sits inside a comment using the treesitter *tree*,
-- not the highlighter. The original implementation used
-- vim.treesitter.get_captures_at_pos(), which returns {} the moment no
-- highlighter is attached to the buffer (Neovim runtime treesitter.lua:
-- `if not buf_highlighter then return {} end`). vim.treesitter.get_node()
-- parses on demand and does not depend on the highlighter, so it works before
-- highlighting attaches and on big files where LazyVim disables highlight.
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
  -- Comment node types vary by language (comment, line_comment, block_comment,
  -- comment_content, ...), so match any ancestor type containing "comment".
  while node do
    if node:type():find("comment") then
      return true
    end
    node = node:parent()
  end
  return false
end

return {
  {
    "saghen/blink.cmp",
    -- @module triggers lazydev to load blink.cmp's lua/ dir into LuaLS's workspace,
    -- making the blink.cmp.Config alias resolvable for the @type below. This is the
    -- canonical pattern from blink.cmp's own docs and replaces a custom lazydev
    -- `library` entry that wasn't reliably loading the type.
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- Disable ALL completion while the cursor is inside a comment. This
      -- top-level `enabled` gate is the effective lever: gating only
      -- ghost_text.enabled left the auto-showing menu firing on LSP items in
      -- comments, because LazyVim forces completion.menu.auto_show to a function
      -- (overriding our auto_show=false). blink's completion trigger calls
      -- config.enabled() and hides completion entirely when it returns false,
      -- which covers the menu, ghost text, and keymaps in one place.
      enabled = function()
        return not in_comment()
      end,
      completion = {
        menu = {
          auto_show = false,
        },
        ghost_text = {
          enabled = function()
            return not in_comment()
          end,
        },
      },
    },
  },
}
