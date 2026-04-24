-- LSP configuration for monorepos
return {
  -- Disable golangci-lint via nvim-lint
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        go = {},
      },
    },
  },
}
