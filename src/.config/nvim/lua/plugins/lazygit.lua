return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    styles = {
      lazygit = {
        -- Have lazygit fill the whole window, but leaving enough height for the "bottom line" of keybind hints etc.
        -- Don't know why this isn't included in the calculation
        width = 0,
        height = 0.99,
      },
    },
  },
}
