-- Go LSP configuration.
--
-- Observability (2026-04-28): start gopls with verbose RPC tracing, a
-- per-session logfile, and the debug HTTP server enabled. We're using this
-- data to investigate persistent slowness in a large monorepo (10-15 s
-- diagnostic refresh, stuck stale diagnostics, missing inline errors).
-- See docs/superpowers/specs/2026-04-28-nvim-gopls-observability-design.md
-- (gitignored) for the full plan.

-- Per-session logfile path so concurrent/restarted nvim instances don't
-- clobber each other. Created in /tmp/gopls/ which we wipe at end of day.
local gopls_log_dir = "/tmp/gopls"
vim.fn.mkdir(gopls_log_dir, "p")
local gopls_logfile = gopls_log_dir .. "/gopls-" .. os.date("%Y%m%d-%H%M%S") .. ".log"

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          -- Override default cmd ({"gopls"}) to add tracing + debug server.
          -- -rpc.trace -v: log every LSP request/response with timing.
          -- -logfile: persistent log; survives nvim crashes.
          -- -debug=localhost:6060: enables /info, /memory, /rpc, /debug/pprof/
          --   for the <leader>os snapshot keybind to scrape on demand.
          cmd = {
            "gopls",
            "-rpc.trace",
            "-v",
            "-logfile=" .. gopls_logfile,
            "-debug=localhost:6060",
          },
          -- Pin root_dir to skip pkg/mod (2026-04-29). Without this,
          -- navigating into a Go module dependency makes lspconfig find
          -- the dep's own go.mod inside ~/go/pkg/mod/... and spawn a
          -- *second* gopls rooted there. Yesterday's snapshots caught this:
          -- two gopls instances competing for CPU/RAM and racing on the
          -- shared -logfile. Returning nil here prevents the second spawn;
          -- nvim still opens dep files, just without LSP features on them.
          --
          -- Signature note: nvim 0.12's vim.lsp.config invokes root_dir as
          -- (bufnr, on_dir) — async style, result passed via the callback.
          -- Some lspconfig codepaths still call (fname) and use the return
          -- value (e.g. snacks picker jump → BufReadPost). We handle both:
          -- if arg is a bufnr (number), resolve fname from it and invoke
          -- on_dir; otherwise return the result.
          root_dir = function(arg, on_dir)
            local fname
            if type(arg) == "number" then
              fname = vim.api.nvim_buf_get_name(arg)
            else
              fname = arg
            end
            local result
            if fname == "" or fname:match("/pkg/mod/") then
              result = nil
            else
              result = require("lspconfig.util").root_pattern("go.work", "go.mod", ".git")(fname)
            end
            if on_dir then
              on_dir(result)
            else
              return result
            end
          end,
          settings = {
            gopls = {
              analyses = {
                -- ST1000: "at least one file in a package should have a package comment"
                ST1000 = false,
              },
            },
          },
        },
      },
    },
  },
}
