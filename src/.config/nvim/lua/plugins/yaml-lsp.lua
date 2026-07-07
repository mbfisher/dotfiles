-- Disable yamlls formatting for YAML files
-- Kubernetes manifests (especially patches) can be corrupted by LSP formatting
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              format = {
                enable = false,
              },
            },
          },
        },
      },
    },
  },

  -- yamlfmt is used by repo-local .nvim.lua configs (e.g. the manifests repo)
  -- to format kustomization.yaml in the indentless style kustomize tooling
  -- writes, instead of prettier's indented style.
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "yamlfmt" } },
  },
}
