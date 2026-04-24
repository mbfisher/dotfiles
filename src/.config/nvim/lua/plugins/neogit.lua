-- Neogit: magit-style git UI inside nvim, as an alternative to lazygit
-- integrations.diffview only adds the `d` popup for side-by-side diffs;
-- inline diffs in the status buffer always use Neogit's own highlight groups.
-- We override them with explicit onedark colors since linking to Diff* doesn't
-- work (onedark's DiffAdd/DiffDelete have fg=NONE, leaving text unstyled).
return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim", -- already installed; used for diff integration
    },
    keys = {
      { "<leader>gn", function() require("neogit").open() end, desc = "Neogit" },
    },
    config = function(_, opts)
      require("neogit").setup(opts)

      -- Override Neogit's diff highlights AFTER setup so they aren't clobbered.
      -- Colors taken from onedark "dark" palette to match diffview appearance.
      -- Re-applied on ColorScheme change for theme-switch resilience.
      local function set_neogit_highlights()
        local hl = vim.api.nvim_set_hl

        -- Added lines: green-tinted bg with green fg
        hl(0, "NeogitDiffAdd", { bg = "#31392b", fg = "#98c379" })
        hl(0, "NeogitDiffAddHighlight", { bg = "#31392b", fg = "#98c379", bold = true })
        hl(0, "NeogitDiffAddCursor", { bg = "#31392b", fg = "#98c379", bold = true })

        -- Deleted lines: red-tinted bg with red fg
        hl(0, "NeogitDiffDelete", { bg = "#382b2c", fg = "#e06c75" })
        hl(0, "NeogitDiffDeleteHighlight", { bg = "#382b2c", fg = "#e06c75", bold = true })
        hl(0, "NeogitDiffDeleteCursor", { bg = "#382b2c", fg = "#e06c75", bold = true })

        -- Context lines: normal background
        hl(0, "NeogitDiffContext", { link = "Normal" })
        hl(0, "NeogitDiffContextHighlight", { link = "CursorLine" })
        hl(0, "NeogitDiffContextCursor", { link = "CursorLine" })

        -- Hunk/diff headers: blue-tinted like DiffChange/DiffText
        hl(0, "NeogitHunkHeader", { bg = "#1c3448", fg = "#61afef", bold = true })
        hl(0, "NeogitHunkHeaderHighlight", { bg = "#2c5372", fg = "#61afef", bold = true })
        hl(0, "NeogitHunkHeaderCursor", { bg = "#2c5372", fg = "#61afef", bold = true })
        hl(0, "NeogitDiffHeader", { bg = "#1c3448", fg = "#61afef", bold = true })
        hl(0, "NeogitDiffHeaderHighlight", { bg = "#2c5372", fg = "#e5c07b", bold = true })

        -- Summary counts
        hl(0, "NeogitDiffAdditions", { fg = "#98c379" })
        hl(0, "NeogitDiffDeletions", { fg = "#e06c75" })
      end

      set_neogit_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_neogit_highlights })
    end,
  },
}
