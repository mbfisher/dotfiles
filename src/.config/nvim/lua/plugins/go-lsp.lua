-- Go LSP configuration.

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          -- Pin root_dir to skip pkg/mod (2026-04-29). Without this,
          -- navigating into a Go module dependency makes lspconfig find
          -- the dep's own go.mod inside ~/go/pkg/mod/... and spawn a
          -- *second* gopls rooted there: two gopls instances competing for
          -- CPU/RAM. Returning nil here prevents the second spawn;
          -- nvim still opens dep files, just without LSP features on them.
          --
          -- Signature note: nvim 0.12's vim.lsp.config invokes root_dir as
          -- (bufnr, on_dir) — async style, result passed via the callback.
          -- Some lspconfig codepaths still call (fname) and use the return
          -- value (e.g. snacks picker jump → BufReadPost). We handle both:
          -- if arg is a bufnr (number), resolve fname from it and invoke
          -- on_dir; otherwise return the result.
          root_dir = function(arg, on_dir)
            local fname
            if type(arg) == "number" then
              fname = vim.api.nvim_buf_get_name(arg)
            else
              fname = arg
            end
            local result
            if fname == "" or fname:match("/pkg/mod/") then
              result = nil
            else
              result = require("lspconfig.util").root_pattern("go.work", "go.mod", ".git")(fname)
            end
            if on_dir then
              on_dir(result)
            else
              return result
            end
          end,
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
