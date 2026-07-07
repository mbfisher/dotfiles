-- Drives onedark from Ghostty's theme.conf instead of macOS dark/light.
-- The `ghostty-theme` shell script rewrites that file and sends SIGUSR1 to
-- every nvim process, which we handle here to re-apply the matching style.
-- Reading the file (vs. re-querying OSC 11) sidesteps zellij not always
-- forwarding terminal background queries to the outer Ghostty.
local function read_ghostty_style()
  local path = vim.fn.expand("~/.config/ghostty/theme.conf")
  local f = io.open(path, "r")
  if not f then
    return "dark"
  end
  local content = f:read("*a") or ""
  f:close()
  return content:match("Atom One Light") and "light" or "dark"
end

local function apply_style(style)
  vim.api.nvim_set_option_value("background", style, {})
  require("onedark").setup({ style = style })
  require("onedark").load()
end

return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = function()
      return { style = read_ghostty_style() }
    end,
    config = function(_, opts)
      require("onedark").setup(opts)
      require("onedark").load()

      -- SIGUSR1 sent by `ghostty-theme` after the user toggles. Re-read the
      -- marker file and reload the matching style so nvim follows Ghostty.
      local signal = vim.uv.new_signal()
      if signal then
        signal:start("sigusr1", function()
          vim.schedule(function()
            apply_style(read_ghostty_style())
          end)
        end)
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
