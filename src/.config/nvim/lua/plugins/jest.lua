return {
  { "nvim-neotest/neotest-jest" },
  {
    "nvim-neotest/neotest",
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-jest"] = {
        jestCommand = "bun jest",
        cwd = function()
          return vim.fn.getcwd()
        end,
      }
      return opts
    end,
  },
}
