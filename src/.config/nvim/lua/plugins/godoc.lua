return {
  "fredrikaverpil/godoc.nvim",
  version = "*",
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main",
      build = ":TSUpdate godoc go", -- install/update parsers
      -- Use `opts` rather than `config`: lazy.nvim lets the last `config` win, so defining one
      -- here would silently replace LazyVim's treesitter config — the thing that starts
      -- highlighting on FileType. `opts` functions are chained instead.
      opts = function(_, opts)
        local godoc_parser = {
          install_info = {
            url = "https://github.com/fredrikaverpil/tree-sitter-godoc",
            files = { "src/parser.c" },
            version = "*",
          },
          filetype = "godoc",
        }
        require("nvim-treesitter.parsers").godoc = godoc_parser

        -- Map godoc filetype to use godoc parser
        vim.treesitter.language.register("godoc", "godoc")

        -- Enable :TSInstall godoc, :TSUpdate godoc
        vim.api.nvim_create_autocmd("User", {
          pattern = "TSUpdate",
          callback = function()
            require("nvim-treesitter.parsers").godoc = godoc_parser
          end,
        })

        -- Enable godoc filetype for .godoc files (optional)
        vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
          pattern = "*.godoc",
          callback = function()
            vim.bo.filetype = "godoc"
          end,
        })

        vim.list_extend(opts.ensure_installed, { "go", "godoc" })
      end,
    },
  },
  cmd = { "GoDoc" },
  ft = "godoc",
  opts = {
    adapters = {
      {
        name = "go",
        opts = {
          -- vim.tbl_deep_extend replaces list-style tables, so overriding `adapters`
          -- drops the default `command = "GoDoc"` and lazy never registers the user
          -- command. Re-state it explicitly here.
          command = "GoDoc",
          get_syntax_info = function()
            return {
              filetype = "godoc",
              language = "godoc", -- Enable tree-sitter godoc parser
            }
          end,
        },
      },
    },
  },
}
