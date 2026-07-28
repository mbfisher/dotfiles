-- onedark, dark style, fixed. The old light/dark switch (read Ghostty's theme.conf on startup,
-- re-apply on SIGUSR1 from the `ghostty-theme` script) is gone along with the script and the
-- theme.conf include — never used in practice, and it forced every colour here to be computed
-- for two themes.
return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "dark" },
    config = function(_, opts)
      require("onedark").setup(opts)
      require("onedark").load()

      -- Terminal splits (shell + Claude Code) should look identical to the same program in a
      -- bare Ghostty pane. snacks maps their Normal to SnacksNormal, which resolves to onedark's
      -- NormalFloat — bg1 #31353f, measurably lighter than the #282c34 outside nvim — making
      -- Claude's output look washed out and its text dim by comparison. Pin these windows to
      -- Ghostty's own built-in defaults instead. Applied by styles.terminal in snacks.lua.
      -- Re-run on ColorScheme because loading a scheme clears custom highlight groups.
      local function set_terminal_hl()
        vim.api.nvim_set_hl(0, "TerminalNormal", { fg = "#ffffff", bg = "#282c34" })
      end
      set_terminal_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_terminal_hl })
    end,
  },

  -- Set LazyVim to use onedark
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
