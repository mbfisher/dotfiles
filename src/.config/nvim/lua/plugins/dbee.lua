return {
  {
    "kndndrj/nvim-dbee",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    build = function()
      -- Install tries to automatically detect the install method.
      -- if it fails, try calling it with one of these parameters:
      --    "curl", "wget", "bitsadmin", "go"
      require("dbee").install()
    end,
    config = function()
      require("dbee").setup({
        sources = {
          require("dbee.sources").MemorySource:new({
            {
              id = "postgres-development",
              name = "Postgres",
              type = "postgres",
              url = "postgres://mbfisher@localhost:5432/development?sslmode=disable",
            },
          }),
        },
      })
    end,
    keys = {
      {
        "<leader>D",
        function()
          require("dbee").toggle()
        end,
        desc = "Toggle DBee",
      },
    },
  },
}
