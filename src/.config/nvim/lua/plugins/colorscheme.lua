-- onedark, dark style, fixed. The old light/dark switch (read Ghostty's theme.conf on startup,
-- re-apply on SIGUSR1 from the `ghostty-theme` script) is gone along with the script and the
-- theme.conf include — never used in practice.
--
-- The goal of the colour tweaks below is that nvim and a bare Ghostty pane are indistinguishable
-- for the same content. Three separate palettes are in play, which is why this needs three fixes:
--   1. onedark's syntax palette      -> code. Left completely stock (see below).
--   2. nvim's g:terminal_color_*     -> ANSI colours inside :terminal buffers.
--   3. Claude's own hardcoded RGB    -> not themeable at all; it emits truecolor, so it already
--                                       looks the same inside nvim and out. Nothing to do.
return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      -- Body text sits halfway between onedark's #abb2bf (6.6:1, washes out in Go, where most of
      -- the screen is plain identifiers) and Ghostty's pure white (14:1, too hot once there's a
      -- lot of it). This is the perceptual midpoint — interpolated in CIELAB, not hex, so it keeps
      -- onedark's cool grey tint rather than drifting neutral. Nudge along that line if needed:
      -- #c0c5cf (8.1:1) / #ccd0d8 (9.1:1) / #dde0e5 (10.6:1) / #eaebef (11.8:1).
      -- Accents stay stock: onedark's blue carries 2.12x the chroma of Ghostty's and purple 2.52x,
      -- which is the vividness that makes code readable here — WCAG contrast can't see it.
      colors = { fg = "#d4d8df" },
    },
    config = function(_, opts)
      require("onedark").setup(opts)
      require("onedark").load()

      -- Ghostty's built-in palette (`ghostty +show-config --default | grep palette`), which is
      -- Tomorrow Night. Terminal buffers render ANSI colours through g:terminal_color_*, and
      -- onedark fills those from its own more saturated palette — so `ls` in the nvim shell split
      -- came out punchier than the identical command in a bare zellij pane. Pinning them here
      -- makes a shell inside nvim match one outside it. Code is unaffected: syntax highlighting
      -- uses onedark's palette, not these.
      local ghostty_palette = {
        "#1d1f21", "#cc6666", "#b5bd68", "#f0c674", "#81a2be", "#b294bb", "#8abeb7", "#c5c8c6",
        "#666666", "#d54e53", "#b9ca4a", "#e7c547", "#7aa6da", "#c397d8", "#70c0b1", "#eaeaea",
      }

      -- Terminal splits (shell + Claude Code) get their own Normal so they match a bare Ghostty
      -- pane: snacks otherwise maps them to SnacksNormal -> onedark's NormalFloat (bg1 #31353f,
      -- lighter than the surrounding background). Background follows the active scheme's Normal so
      -- switching colorschemes keeps them in step; foreground is pinned to Ghostty's white, which
      -- is what a terminal session gets outside nvim — deliberately independent of onedark's `fg`,
      -- so terminals match Ghostty while code stays stock onedark. Note a plain `:terminal` (not
      -- opened via snacks) misses this and falls back to onedark's dimmer Normal.
      -- TerminalWinSeparator gives the terminal/code edge a visible rule — onedark's
      -- WinSeparator is #3b3f4c, about 1.2:1. The left window owns a vertical separator column and
      -- the terminals are always on the left, so code-to-code splits keep onedark's version.
      -- Both are re-applied on ColorScheme, which clears custom groups and re-runs onedark's own
      -- terminal_color_* assignment.
      local function apply_terminal_colours()
        for i, hex in ipairs(ghostty_palette) do
          vim.g["terminal_color_" .. (i - 1)] = hex
        end
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        local bg = normal.bg and ("#%06x"):format(normal.bg) or "#282c34"
        vim.api.nvim_set_hl(0, "TerminalNormal", { fg = "#ffffff", bg = bg })
        vim.api.nvim_set_hl(0, "TerminalWinSeparator", { fg = "#ffffff", bg = bg })
      end
      apply_terminal_colours()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_terminal_colours })
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
