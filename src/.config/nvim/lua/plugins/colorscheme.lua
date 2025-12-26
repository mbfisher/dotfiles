return {
  -- Configure onedark
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark", -- dark, darker, cool, deep, warm, warmer, light
    },
  },

  -- Auto dark mode - syncs with macOS appearance
  -- {
  --   "f-person/auto-dark-mode.nvim",
  --   opts = {
  --     update_interval = 1000,
  --     set_dark_mode = function()
  --       vim.api.nvim_set_option_value("background", "dark", {})
  --       require("onedark").setup({ style = "dark" })
  --       require("onedark").load()
  --     end,
  --     set_light_mode = function()
  --       vim.api.nvim_set_option_value("background", "light", {})
  --       require("onedark").setup({ style = "light" })
  --       require("onedark").load()
  --     end,
  --   },
  -- },

  -- Set LazyVim to use onedark
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
