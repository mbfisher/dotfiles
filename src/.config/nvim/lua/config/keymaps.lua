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

-- Paste from system clipboard
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste from system clipboard (before)" })
