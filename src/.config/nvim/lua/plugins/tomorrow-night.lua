-- Tomorrow Night for code, purely as a live A/B against onedark — NOT the active colorscheme.
--
-- Ghostty's default palette is verifiably Tomorrow Night (slots 1-6 match its theme file exactly,
-- 9-14 match Tomorrow Night Bright) on One Dark's #282c34 background with a pure white foreground.
-- Since we pin nvim's terminal ANSI colours to that same palette, adopting Tomorrow Night for code
-- too would mean one palette everywhere — and would need no Ghostty change at all, because Ghostty
-- is already there.
--
-- Try it:   :colorscheme base16-tomorrow-night     (compare against :colorscheme onedark)
-- Keep it:  set colorscheme in colorscheme.lua and delete this file's "lazy" flag.
-- Drop it:  delete this file.
--
-- Note if you do adopt it: base16 Tomorrow Night's background is #1d1f21, so Ghostty's background
-- would need to follow (`background = #1d1f21`, or `theme = Tomorrow Night`) or nvim's terminal
-- splits will sit darker than a bare zellij pane.
return {
  { "RRethy/base16-nvim", lazy = true },
}
