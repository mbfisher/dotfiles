return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      -- Keep the buffer tabs over the code window rather than spanning the <C-/> shell's left split
      -- too (filetype snacks_terminal), as LazyVim already does for the explorer. Painting the offset
      -- in BufferLineFill keeps the bar reading as one full-width strip instead of a hole above the
      -- terminal.
      opts.options.offsets = opts.options.offsets or {}
      table.insert(opts.options.offsets, { filetype = "snacks_terminal", highlight = "BufferLineFill" })

      -- bufferline's own auto-toggle counts only listed BUFFERS, and it re-runs from the tabline
      -- expression itself — i.e. on every redraw — so anything else that sets 'showtabline' (e.g.
      -- diffview opening its tab with a clean tree, one buffer) is reset before you can see it.
      -- Turn it off and drive 'showtabline' ourselves below, counting tabs as well as buffers.
      opts.options.auto_toggle_bufferline = false
      return opts
    end,
    init = function()
      -- Show the tabline when there's more than one buffer OR more than one tab, so diffview's tab
      -- (and its 1/2 tab indicators) is always visible. Scheduled because BufDelete/TabClosed fire
      -- before the buffer/tab is actually gone.
      local function toggle()
        local many_bufs = #vim.fn.getbufinfo({ buflisted = 1 }) > 1
        vim.o.showtabline = (many_bufs or vim.fn.tabpagenr("$") > 1) and 2 or 0
      end

      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "TabNew", "TabClosed", "TabEnter" }, {
        group = vim.api.nvim_create_augroup("bufferline_showtabline", { clear = true }),
        callback = vim.schedule_wrap(toggle),
      })
    end,
  },
}
