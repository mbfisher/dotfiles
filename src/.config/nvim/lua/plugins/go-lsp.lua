-- Go LSP configuration
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              analyses = {
                -- ST1000: "at least one file in a package should have a package comment"
                ST1000 = false,
              },
            },
          },
        },
      },
    },
  },
}
