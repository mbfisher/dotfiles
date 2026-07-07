-- Observability instrumentation for gopls / LSP debugging (2026-04-28).
--
-- Goal: collect rich data through a day's work in a large Go monorepo so we
-- can diagnose persistent slowness later — 10-15 s diagnostic refresh,
-- stuck stale diagnostics, missing inline errors. Paired with cmd-line
-- changes in lua/plugins/go-lsp.lua. Spec at
-- docs/superpowers/specs/2026-04-28-nvim-gopls-observability-design.md
-- (gitignored).
--
-- Three always-on capture layers:
--   1. gopls log + debug HTTP server (configured in go-lsp.lua)
--   2. nvim LSP log at DEBUG (this file)
--   3. Diagnostic-refresh timer → /tmp/gopls/refresh-times.jsonl
-- Plus one on-demand snapshot keybind <leader>os that bundles a moment.

local M = {}

local LOG_DIR = "/tmp/gopls"
local REFRESH_LOG = LOG_DIR .. "/refresh-times.jsonl"
local DEBUG_PORT = 6060

-- Stuck-diagnostic threshold (2026-04-29): if no DiagnosticChanged fires
-- within this window after a save, we record an explicit "stuck" event.
-- This catches the user-reported "stale errors" symptom that the plain
-- refresh metric misses (because it only fires on actual diagnostic deltas).
local STUCK_TIMEOUT_MS = 30000

-- bufnr → { start = hrtime ns, file = "...", timer = uv_timer }. Cleared on
-- the first diagnostic refresh after save (or on the stuck-timer firing) so
-- we measure first-refresh latency only and don't accumulate noise from
-- subsequent incremental diagnostic mutations.
local pending = {}

local function append_jsonl(obj)
  local f = io.open(REFRESH_LOG, "a")
  if not f then return end
  f:write(vim.json.encode(obj) .. "\n")
  f:close()
end

local function close_timer(t)
  if t and not t:is_closing() then
    t:stop()
    t:close()
  end
end

local function on_buf_write(args)
  local name = vim.api.nvim_buf_get_name(args.buf)
  if not name:match("%.go$") then return end

  -- Cancel any prior pending entry (e.g. user saved twice quickly without
  -- gopls publishing in between). The new save resets the clock.
  local existing = pending[args.buf]
  if existing then close_timer(existing.timer) end

  local timer = vim.uv.new_timer()
  pending[args.buf] = { start = vim.uv.hrtime(), file = name, timer = timer }

  -- Stuck detector. If diagnostics haven't refreshed within the timeout we
  -- emit an explicit event the user can grep for. Identity-check on the
  -- timer guards against a stale callback firing for a buffer whose entry
  -- was already replaced by a newer save.
  timer:start(STUCK_TIMEOUT_MS, 0, vim.schedule_wrap(function()
    local p = pending[args.buf]
    if not p or p.timer ~= timer then return end
    pending[args.buf] = nil
    timer:close()
    append_jsonl({
      ts = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      event = "stuck",
      file = p.file,
      timeout_ms = STUCK_TIMEOUT_MS,
    })
  end))
end

local function on_diagnostic_changed(args)
  local p = pending[args.buf]
  if not p then return end
  pending[args.buf] = nil
  close_timer(p.timer)
  local elapsed_ms = math.floor((vim.uv.hrtime() - p.start) / 1e6)
  append_jsonl({
    ts = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    event = "refresh",
    file = p.file,
    elapsed_ms = elapsed_ms,
  })
end

-- Rotate ~/.local/state/nvim/lsp.log if it has grown beyond a threshold.
-- We log at DEBUG which produces ~hundreds of MB to GBs per session, and
-- nvim emits a "large log file" warning past ~1 GB. Move the old log into
-- /tmp/gopls/ as forensic backup so today's session starts fresh. Must run
-- before LSP starts (i.e. before any plugin loads) — that's why setup()
-- calls this before vim.lsp.set_log_level.
local LSP_LOG_ROTATE_BYTES = 100 * 1024 * 1024
local function rotate_lsp_log_if_large()
  local lsp_log = vim.fn.stdpath("state") .. "/lsp.log"
  if vim.fn.filereadable(lsp_log) ~= 1 then return end
  local size = vim.fn.getfsize(lsp_log)
  -- getfsize: -2 means "too large to express" (effectively very big), -1 is
  -- a read error. Treat -2 as rotate-now; ignore -1 (don't risk losing data).
  if size == -2 or (size >= 0 and size > LSP_LOG_ROTATE_BYTES) then
    local backup = LOG_DIR .. "/lsp-prev-" .. os.date("%Y%m%d-%H%M%S") .. ".log"
    os.rename(lsp_log, backup)
  end
end

-- Take a moment-of-pain snapshot. User triggers this via <leader>os when
-- something feels stuck. Bundles gopls debug endpoints + tails of both log
-- streams + active LSP client state into a self-contained directory.
function M.snapshot()
  local ts = os.date("%Y%m%d-%H%M%S")
  local dir = LOG_DIR .. "/snap-" .. ts
  vim.fn.mkdir(dir, "p")

  -- Marker in refresh log so the moment is greppable in the aggregate stream.
  append_jsonl({
    ts = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    event = "snapshot",
    dir = dir,
  })

  -- Scrape gopls debug HTTP endpoints. -fsS: fail quietly on HTTP errors but
  -- print transport errors. --max-time: don't hang nvim if gopls is wedged.
  -- Endpoints live at the root (/info, /memory, /rpc) — the /debug/ prefix
  -- only applies to the embedded pprof handlers (/debug/pprof/...). Earlier
  -- snapshots curled /debug/info etc. and got the index page back; this
  -- avoids that pitfall.
  for _, ep in ipairs({ "info", "memory", "rpc" }) do
    vim.fn.system({
      "curl", "-fsS", "--max-time", "5",
      "-o", dir .. "/" .. ep .. ".html",
      string.format("http://localhost:%d/%s", DEBUG_PORT, ep),
    })
  end

  -- Tail bounded number of lines from each big log into the snapshot.
  -- 10 000 lines is enough context to see what gopls was doing around the
  -- moment of pain without dragging in gigabytes.
  local function tail_into(src, dest)
    if vim.fn.filereadable(src) == 1 then
      vim.fn.system(string.format(
        "tail -n 10000 %s > %s",
        vim.fn.shellescape(src),
        vim.fn.shellescape(dest)
      ))
    end
  end

  tail_into(vim.fn.stdpath("state") .. "/lsp.log", dir .. "/lsp.log.tail")

  -- Latest gopls log = lexicographically last (we name with timestamps).
  local gopls_logs = vim.fn.glob(LOG_DIR .. "/gopls-*.log", false, true)
  if #gopls_logs > 0 then
    table.sort(gopls_logs)
    tail_into(gopls_logs[#gopls_logs], dir .. "/gopls.log.tail")
  end

  -- Active LSP clients — root dirs, cmd, attached buffers. Catches misconfig
  -- like "gopls rooted at the wrong go.mod in a monorepo".
  local clients = {}
  for _, c in ipairs(vim.lsp.get_clients()) do
    table.insert(clients, {
      id = c.id,
      name = c.name,
      root_dir = c.config.root_dir,
      cmd = c.config.cmd,
      attached_buffers = vim.tbl_keys(c.attached_buffers or {}),
    })
  end
  local f = io.open(dir .. "/lsp-clients.json", "w")
  if f then
    f:write(vim.json.encode(clients))
    f:close()
  end

  vim.notify("Observability snapshot saved to " .. dir, vim.log.levels.INFO)
end

function M.setup()
  -- Set leaders before defining the snapshot keymap. LazyVim sets these
  -- itself but only later during plugin load, so doing it here ensures
  -- <leader>os resolves to <space>os (and not the default "\os") when this
  -- module runs from init.lua. Same values LazyVim uses — idempotent.
  vim.g.mapleader = " "
  vim.g.maplocalleader = "\\"

  vim.fn.mkdir(LOG_DIR, "p")

  -- Rotate before setting log level so the big-log warning doesn't fire
  -- during this startup. /tmp/gopls/ already exists from the mkdir above.
  rotate_lsp_log_if_large()

  -- Must run before any LSP client starts so we capture the full handshake.
  -- Logs to ~/.local/state/nvim/lsp.log. Updated 2026-04-30 for nvim 0.12:
  -- vim.lsp.set_log_level is deprecated in favour of vim.lsp.log.set_level.
  vim.lsp.log.set_level("DEBUG")

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.go",
    callback = on_buf_write,
    desc = "observability: record save time for diagnostic refresh timer",
  })

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    callback = on_diagnostic_changed,
    desc = "observability: log first-refresh latency after save",
  })

  vim.keymap.set("n", "<leader>os", M.snapshot, {
    desc = "Observability: snapshot gopls state",
  })
end

M.setup()

return M
