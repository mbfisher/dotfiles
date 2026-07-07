return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  opts = {
    picker = "snacks",
    -- bare Octo command opens picker of commands
    enable_builtin = true,
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
}
