-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle comment with Cmd+/
vim.keymap.set("n", "<D-/>", "gcc", { remap = true, desc = "Toggle comment" })
vim.keymap.set("v", "<D-/>", "gc", { remap = true, desc = "Toggle comment" })

-- Yank to system clipboard (delete stays in vim register for dd+p line swapping)
vim.keymap.set({ "n", "v" }, "y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "Y", '"+Y', { desc = "Yank to end of line to system clipboard" })
vim.keymap.set("n", "yy", '"+yy', { desc = "Yank line to system clipboard" })

-- Cmd+[ / Cmd+] to navigate jumplist (cursor position history)
-- Ghostty sends CSI u sequences for these; see ghostty/config
vim.keymap.set("n", "<D-[>", "<C-o>", { desc = "Jump to previous cursor position" })
vim.keymap.set("n", "<D-]>", "<C-i>", { desc = "Jump to next cursor position" })

-- Paste from system clipboard. If the clipboard holds an image, defer to img-clip.nvim
-- (writes image to disk + inserts a markdown link); otherwise fall back to "+p.
-- Without this, <leader>p in keymaps.lua wins over the plugin's lazy keys mapping and
-- pastes from the empty "+" register when an image is on the clipboard.
-- Guard the "+p fallback: if the register is empty, "+p throws E353 with a stack trace;
-- show a clean message instead so the user knows neither image nor text was available.
vim.keymap.set({ "n", "v" }, "<leader>p", function()
  local ok, img_clip = pcall(require, "img-clip")
  if ok and img_clip.paste_image() then
    return
  end
  if vim.fn.getreg("+") == "" then
    vim.notify("Clipboard is empty (no image, no text)", vim.log.levels.WARN)
    return
  end
  vim.cmd('normal! "+p')
end, { desc = "Paste from system clipboard (or image via img-clip)" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste from system clipboard (before)" })

-- Yank current buffer path to system clipboard. LazyVim's <leader>f group
-- has no fy/fY out of the box; fill the gap rather than open a picker.
-- %:. forces relative-to-cwd — %  alone returns whatever the buffer was
-- opened with, which is often absolute (e.g. via Snacks picker).
vim.keymap.set("n", "<leader>fy", function()
  local p = vim.fn.expand("%:.")
  vim.fn.setreg("+", p)
  vim.notify(p)
end, { desc = "Yank relative path" })
vim.keymap.set("n", "<leader>fY", function()
  local p = vim.fn.expand("%:p")
  vim.fn.setreg("+", p)
  vim.notify(p)
end, { desc = "Yank absolute path" })

-- Horizontal mouse scroll (Magic Mouse, Keychron M6 horizontal wheel)
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", "3zh", { desc = "Scroll left" })
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", "3zl", { desc = "Scroll right" })
