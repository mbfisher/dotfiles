-- Local plugin: nvim-incidentio (API navigation tooling for the incident.io codebase).
-- When published, swap dir for "incident-io/nvim-incidentio".
-- Updated to use new picker-agnostic architecture: keymaps defined here, not in the plugin.
return {
  {
    dir = vim.fn.stdpath("config") .. "/nvim-incidentio",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      {
        "<leader>sA",
        function()
          require("incidentio.picker").api_pick()
        end,
        desc = "APIs",
      },
      {
        "<leader>sE",
        function()
          require("incidentio.picker").events_pick()
        end,
        desc = "Events",
      },
      {
        "gA",
        function()
          require("incidentio.api").goto_counterpart()
        end,
        desc = "Goto API design/impl",
      },
      {
        "gE",
        function()
          require("incidentio.picker").events_pick_at_cursor()
        end,
        desc = "Event pub/sub",
      },
    },
    opts = {},
  },
  {
    "folke/which-key.nvim",
    opts = {
      icons = {
        rules = {
          -- nf-md-fire in orange for all incidentio keymaps
          { plugin = "nvim-incidentio", icon = "󰈸", color = "orange" },
        },
      },
    },
  },
}
