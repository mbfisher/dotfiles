-- Local plugin: nvim-incidentio (API navigation tooling for the incident.io codebase).
-- When published, swap dir for "incident-io/nvim-incidentio".
return {
  {
    dir = vim.fn.stdpath("config") .. "/nvim-incidentio",
    dependencies = { "folke/snacks.nvim", "folke/which-key.nvim" },
    config = function()
      require("incidentio").setup()
    end,
  },
}
