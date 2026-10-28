-- `terminal-theme` switches the entire terminal stack between these two schemes. Ghostty reads the
-- same state file directly; nvim reads it because Zellij does not reliably forward OSC background
-- queries. Full rationale and every place colours are set: docs/colours.md.
local theme_file = vim.fn.expand("~/.config/ghostty/theme.conf")

local terminal_schemes = {
  dark = {
    bg = "#282c34",
    fg = "#ffffff",
    ansi = {
      "#1d1f21", "#cc6666", "#b5bd68", "#f0c674", "#81a2be", "#b294bb", "#8abeb7", "#c5c8c6",
      "#666666", "#d54e53", "#b9ca4a", "#e7c547", "#7aa6da", "#c397d8", "#70c0b1", "#eaeaea",
    },
  },
  light = {
    bg = "#fffcf0",
    fg = "#100f0f",
    ansi = {
      "#100f0f", "#af3029", "#66800b", "#ad8301", "#205ea6", "#a02f6f", "#24837b", "#6f6e69",
      "#b7b5ac", "#d14d41", "#879a39", "#d0a215", "#4385be", "#ce5d97", "#3aa99f", "#cecdc3",
    },
  },
}

local editor_schemes = {
  dark = {
    style = "dark",
    colors = {
      bg0 = "#282c34",
      bg1 = "#31353f",
      bg2 = "#393f4a",
      bg3 = "#3b3f4c",
      bg_d = "#21252b",
      fg = "#d4d8df",
    },
  },
  light = {
    style = "light",
    -- Keep onedark's readable syntax accents, but replace its neutral greys with Flexoki's warm
    -- paper scale so the editor and surrounding terminal read as one surface.
    colors = {
      bg0 = "#fffcf0",
      bg1 = "#f2f0e5",
      bg2 = "#e6e4d9",
      bg3 = "#cecdc3",
      bg_d = "#dad8ce",
      fg = "#343331",
    },
  },
}

local function read_style()
  local file = io.open(theme_file, "r")
  if not file then
    return "dark"
  end
  local content = file:read("*a") or ""
  file:close()
  return content:match("theme%s*=%s*Flexoki Light") and "light" or "dark"
end

local function onedark_opts(style)
  local scheme = editor_schemes[style]
  return { style = scheme.style, colors = scheme.colors }
end

local function apply_terminal_scheme(style)
  local scheme = terminal_schemes[style]
  for i, hex in ipairs(scheme.ansi) do
    vim.g["terminal_color_" .. (i - 1)] = hex
  end
  vim.api.nvim_set_hl(0, "TerminalNormal", { fg = scheme.fg, bg = scheme.bg })
  vim.api.nvim_set_hl(0, "TerminalWinSeparator", { fg = scheme.fg, bg = scheme.bg })
end

local function apply_style(style)
  vim.api.nvim_set_option_value("background", style, {})
  require("onedark").setup(onedark_opts(style))

  -- onedark's colour-dependent modules capture the palette when first required. Evict them so
  -- switching style in a running process computes highlights from the new palette.
  package.loaded["onedark.colors"] = nil
  package.loaded["onedark.highlights"] = nil
  package.loaded["onedark.terminal"] = nil

  require("onedark").load()
  apply_terminal_scheme(style)
end

return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = function()
      return onedark_opts(read_style())
    end,
    config = function(_, opts)
      local style = read_style()
      vim.api.nvim_set_option_value("background", style, {})
      require("onedark").setup(opts)
      require("onedark").load()

      apply_terminal_scheme(style)
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          apply_terminal_scheme(read_style())
        end,
      })

      local signal = vim.uv.new_signal()
      if signal then
        signal:start("sigusr1", function()
          vim.schedule(function()
            apply_style(read_style())
          end)
        end)
        vim.api.nvim_create_autocmd("VimLeavePre", {
          once = true,
          callback = function()
            signal:stop()
            signal:close()
          end,
        })
      end
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
