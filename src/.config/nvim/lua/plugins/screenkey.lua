-- Screenkey: displays pressed keys in a floating window for screencasts/demos.
-- Used with VHS tape files to show keypresses in GIF recordings.
return {
  {
    "NStefan002/screenkey.nvim",
    lazy = true,
    cmd = "Screenkey",
    opts = {
      -- Keep screenkey visible on top of which-key and snacks picker windows.
      -- Uses Lua patterns matched against floating window filetypes.
      display_infront = { "wk", "snacks_picker.*" },
    },
  },
}
