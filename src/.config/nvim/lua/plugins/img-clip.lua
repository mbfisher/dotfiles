-- img-clip.nvim: paste images from system clipboard into markdown as files + links.
-- LazyVim's lang.markdown extra does NOT include this, so we add it ourselves.
-- The <leader>p trigger lives in config/keymaps.lua (it has to share with the
-- existing system-clipboard paste mapping), so this spec just registers the plugin.
-- Requires `pngpaste` on macOS to read images from the system clipboard:
--   brew install pngpaste
-- Without it, :checkhealth img-clip flags it and paste_image() silently returns false.
return {
  "HakonHarnes/img-clip.nvim",
  event = "VeryLazy",
  opts = {
    default = {
      -- Save image next to the current file (no assets/ subdir) and always prompt
      -- for the filename — per user preference, no default name is set.
      dir_path = ".",
      relative_to_current_file = true,
      prompt_for_file_name = true,
      use_absolute_path = false,
    },
  },
}
