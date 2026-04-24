local function in_comment()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- In insert mode, check position one character to the left
  if vim.api.nvim_get_mode().mode == "i" then
    col = math.max(0, col - 1)
  end
  local captures = vim.treesitter.get_captures_at_pos(0, row - 1, col)
  for _, capture in ipairs(captures) do
    if capture.capture == "comment" then
      return true
    end
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
