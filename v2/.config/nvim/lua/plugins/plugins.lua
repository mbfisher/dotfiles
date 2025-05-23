return {
  { "nickkadutskyi/jb.nvim" },

  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["ruby"] = { "rubocop" },
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "jb",
    },
  },
}
