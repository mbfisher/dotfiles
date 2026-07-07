-- Show hidden files (dotfiles) by default in file and grep pickers.
-- Toggle with <Alt-h> while picker is open.
-- See: https://github.com/LazyVim/LazyVim/discussions/6807
return {
  { "folke/lazydev.nvim", opts = { library = { { path = "snacks.nvim", words = { "snacks" } } } } },
  {
    "folke/snacks.nvim",
    -- Keep <leader>gd / <leader>gD clear for diffview. (diffview.lua actively
    -- claims <leader>gd and <leader>gh, so LazyVim skips its own versions anyway;
    -- these are belt-and-braces.) LazyVim's lazygit binds (<leader>gg / <leader>gG)
    -- are intentionally left untouched — unused, but kept so any future upstream
    -- changes carry through.
    keys = {
      { "<leader>gd", false }, -- reserved for diffview
      { "<leader>gD", false }, -- unused
    },
    ---@type snacks.Config
    opts = {
      picker = {
        -- <c-f> in grep picker: toggle off live mode and append " file:" to input
        -- so you can immediately filter results by filename/path
        actions = {
          filter_by_file = function(picker)
            if picker.opts.live then
              picker.opts.live = false
              picker.input:set()
            end
            vim.api.nvim_win_call(picker.input.win.win, function()
              vim.api.nvim_put({ " file:" }, "c", true, true)
            end)
            picker.input:update()
          end,
        },
        win = {
          input = {
            keys = {
              ["<c-f>"] = { "filter_by_file", mode = { "i", "n" } },
            },
          },
        },
        sources = {
          files = {
            hidden = true,
          },
          grep = {
            hidden = true,
          },
          explorer = {
            hidden = true,
          },
        },
      },
    },
  },
}
