-- Two colour schemes are in use across these dotfiles, and this file defines the nvim half of both.
-- Full rationale, measurements and the list of every place colours are set: docs/colours.md.
--
--   TERMINAL — Ghostty's built-in default. Every shell, inside nvim or out, plus Claude Code.
--   EDITOR   — onedark 'dark' with exactly one change: a lighter body foreground.
--
-- Claude Code belongs to neither: it emits hardcoded truecolor RGB, so it looks the same in both
-- and takes only its default fg/bg from the terminal scheme.

-- Ghostty's built-in default scheme, mirrored so terminal buffers inside nvim render exactly as
-- they do in a bare pane — nvim renders ANSI through g:terminal_color_*, and onedark would
-- otherwise fill those from its own, more saturated palette.
-- Source of truth is `ghostty +show-config --default`: the Ghostty config deliberately sets no
-- colours, so these ARE the live values. Setting a Ghostty theme means updating these too.
local terminal_scheme = {
  bg = "#282c34", -- One Dark's background, not Tomorrow Night's #1d1f21
  fg = "#ffffff", -- pure white, not Tomorrow Night's #c5c8c6
  -- Tomorrow Night for the normal colours, Tomorrow Night Bright for the brights.
  ansi = {
    "#1d1f21", "#cc6666", "#b5bd68", "#f0c674", "#81a2be", "#b294bb", "#8abeb7", "#c5c8c6",
    "#666666", "#d54e53", "#b9ca4a", "#e7c547", "#7aa6da", "#c397d8", "#70c0b1", "#eaeaea",
  },
}

local editor_scheme = {
  style = "dark",
  -- Body text only. Perceptual midpoint (CIELAB, so it keeps onedark's cool grey tint) between
  -- onedark's own #abb2bf, which washes out in languages like Go where most of the screen is
  -- unstyled identifiers, and the terminal scheme's pure white, which is too hot at that volume.
  -- Nudge along the same line: #c0c5cf / #ccd0d8 / #dde0e5 / #eaebef.
  -- Accents are deliberately stock: onedark's blue carries 2.12x the chroma of Ghostty's and its
  -- purple 2.52x, and that colourfulness is the reason to run a different scheme for code at all.
  fg = "#d4d8df",
}

return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = editor_scheme.style, colors = { fg = editor_scheme.fg } },
    config = function(_, opts)
      require("onedark").setup(opts)
      require("onedark").load()

      -- Apply the terminal scheme to anything in nvim that hosts a terminal:
      --   * g:terminal_color_* so ANSI output matches a bare Ghostty pane.
      --   * TerminalNormal for the panes' own fg/bg. snacks would otherwise map them to
      --     SnacksNormal -> onedark's NormalFloat (bg1 #31353f), lighter than the surrounding
      --     background. Wired up by styles.terminal in snacks.lua.
      --   * TerminalWinSeparator so the terminal/code edge is visible at all — onedark's
      --     WinSeparator is #3b3f4c, about 1.2:1. The left window owns a vertical separator column
      --     and the terminals always sit on the left, so code-to-code splits keep onedark's.
      -- Held in the terminal scheme's own values rather than read from the active colorscheme: a
      -- terminal should look like Ghostty whichever scheme the editor is using. Re-applied on
      -- ColorScheme, which clears custom groups and re-runs onedark's own terminal_color_* pass.
      -- Note a plain `:terminal` (not opened via snacks) misses TerminalNormal and falls back to
      -- onedark's Normal, so its body text is the editor foreground rather than white.
      local function apply_terminal_scheme()
        for i, hex in ipairs(terminal_scheme.ansi) do
          vim.g["terminal_color_" .. (i - 1)] = hex
        end
        vim.api.nvim_set_hl(0, "TerminalNormal", { fg = terminal_scheme.fg, bg = terminal_scheme.bg })
        vim.api.nvim_set_hl(0, "TerminalWinSeparator", { fg = terminal_scheme.fg, bg = terminal_scheme.bg })
      end
      apply_terminal_scheme()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_terminal_scheme })
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
