return {
  { "folke/lazydev.nvim", opts = { library = { { path = "flash.nvim", words = { "flash" } } } } },
  {
    "folke/flash.nvim",
    ---@type Flash.Config
    opts = {
      labels = "hjklasdfgqwertyuiopzxcvbnm",
    },
  },
}
