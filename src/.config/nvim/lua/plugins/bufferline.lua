return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      -- Keep the buffer tabs over the CODE half of the screen rather than spanning the sidebar too.
      -- The tabline is inherently full width, but an offset reserves the left portion for a sidebar
      -- window and draws it in that window's own background, so the tabs start where the code window
      -- does. LazyVim already does this for the snacks explorer (snacks_layout_box); both sidebar
      -- terminals — the <C-/> shell and the Claude Code split — are filetype snacks_terminal.
      -- One entry covers every case: bufferline takes the width from the TOPMOST window of a split
      -- column, so it works for Claude alone, the shell alone, and the two stacked.
      opts.options.offsets = opts.options.offsets or {}
      table.insert(opts.options.offsets, { filetype = "snacks_terminal" })
      return opts
    end,
  },
}
