-- API navigation: search logic for Goa design files and their Go implementations.
--
-- Public API:
--   api.find_all()         — returns all design + impl items as a flat list
--   api.goto_counterpart() — jump between design and impl for method under cursor
--   api.badges             — icon/hl definitions for picker adapters
--   api.filter_modes       — filter mode names for <C-i> cycling
--   api.filter_labels      — human-readable labels for each filter mode
--
-- How it works:
--   1. Parse design files for Service/Method declarations (including ServicePublicV1/V2/V3).
--   2. Derive each service's gen package directory name (e.g. "Alert Events" + v2 -> alert_events_v2).
--   3. Find implementation files by searching server/app/, server/api/, and server/integrations/
--      (excluding gen/) for files that import a known gen package, then matching receiver method
--      definitions in those files back to the design Method names.
--   4. For goto_counterpart, use the nearest Method declaration at or above the cursor to
--      determine which method the user is in.

local M = {}

-- Badge definitions for picker adapters to render per-item icons
M.badges = {
  design = { icon = " \u{F1FC} ", hl = "DiagnosticInfo" },    -- nf-fa-paint_brush
  impl   = { icon = " \u{F121} ", hl = "DiagnosticHint" },    -- nf-fa-code
}

-- Filter modes for <C-i> cycling in pickers
M.filter_modes = { "all", "design", "impl" }
M.filter_labels = { all = "All", design = "Design only", impl = "Impl only" }

--- Parse design files to extract Service/Method definitions.
--- Matches Service(), ServicePublicV1/V2/V3() declarations and their Method() children.
--- Returns a list of {service, method, version, file, line} entries,
--- where version is nil for Service() or "v1"/"v2"/"v3" for versioned variants.
local function parse_design_files()
  local design_dir = "server/api/design"
  if vim.fn.isdirectory(design_dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(design_dir .. "/*_service*.go", false, true)
  local entries = {}

  for _, filepath in ipairs(files) do
    local current_service = nil
    local current_version = nil

    local lnum = 0
    for line in io.lines(filepath) do
      lnum = lnum + 1

      local variant, svc_name = line:match('^var%s+_%s*=%s*(Service[^(]*)%("([^"]+)"')
      if svc_name then
        current_service = svc_name
        local ver = variant:match("V(%d+)$")
        current_version = ver and ("v" .. ver) or nil
      end

      if current_service then
        local method_name = line:match('^%s+Method%("([^"]+)"')
        if method_name then
          table.insert(entries, {
            service = current_service,
            method = method_name,
            version = current_version,
            file = filepath,
            line = lnum,
          })
        end
      end
    end
  end

  return entries
end

--- Convert a service name to its gen package directory name.
--- Handles CamelCase, spaces, hyphens, and " - " separators.
--- Appends version suffix for ServicePublicV1/V2/V3.
local function service_to_gen_dir(name, version)
  local s = name
  s = s:gsub(" %- ", " ")
  s = s:gsub("(%l)(%u)", "%1_%2"):gsub("(%u+)(%u%l)", "%1_%2")
  s = s:lower():gsub("[ -]", "_")
  if version then
    s = s .. "_" .. version
  end
  return s
end

--- Build a mapping from gen package directory name to service name.
local function build_gen_to_service_map(design_entries)
  local seen = {}
  local map = {}

  for _, entry in ipairs(design_entries) do
    local skey = entry.service .. "|" .. (entry.version or "")
    if not seen[skey] then
      seen[skey] = true
      map[service_to_gen_dir(entry.service, entry.version)] = entry.service
    end
  end

  return map
end

--- Find implementation files by scanning for gen package imports and method definitions.
--- Returns a lookup table: "Service.Method" -> {file, line}
local function find_implementations(gen_to_service)
  local function rg(pattern)
    return table.concat({
      "rg", "-n", "--no-heading",
      '--glob "*.go"',
      '--glob "!server/api/gen/**"',
      '"' .. pattern .. '"',
      "server/app/", "server/api/", "server/integrations/",
    }, " ")
  end

  local import_output = vim.fn.system(rg("api/gen/"))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local file_to_service = {}
  for line in import_output:gmatch("[^\n]+") do
    local file, import_path = line:match("^([^:]+):%d+:%s*.*\"[^\"]*api/gen/([^\"]+)\"")
    if file and import_path then
      local gen_dir = import_path:match("([^/]+)$") or import_path
      local service_name = gen_to_service[gen_dir]
      if service_name and not file:match("_test%.go$") then
        file_to_service[file] = service_name
      end
    end
  end

  local method_output = vim.fn.system(rg("^func \\("))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local impl_lookup = {}
  for line in method_output:gmatch("[^\n]+") do
    local file, lnum, method_name = line:match("^([^:]+):(%d+):func%s+%([^)]+%)%s+(%w+)%s*%(")
    if file and method_name and file_to_service[file] then
      local service_name = file_to_service[file]
      local key = service_name .. "." .. method_name
      if not impl_lookup[key] then
        impl_lookup[key] = { file = file, line = tonumber(lnum) }
      end
    end
  end

  return impl_lookup
end

--- Build both lookup directions: design->impl and impl->design.
local function build_lookups()
  local design_entries = parse_design_files()
  if #design_entries == 0 then
    return {}, {}, {}
  end

  local gen_to_service = build_gen_to_service_map(design_entries)
  local impl_lookup = find_implementations(gen_to_service)

  local impl_file_methods = {}
  for _, entry in ipairs(design_entries) do
    local key = entry.service .. "." .. entry.method
    local impl = impl_lookup[key]
    if impl then
      if not impl_file_methods[impl.file] then
        impl_file_methods[impl.file] = {}
      end
      table.insert(impl_file_methods[impl.file], {
        impl_line = impl.line,
        method = entry.method,
        service = entry.service,
        design_file = entry.file,
        design_line = entry.line,
      })
    end
  end

  return design_entries, impl_lookup, impl_file_methods
end

--- Return all API items (design + implementation) as a flat list.
--- Each item has: text, method_label, kind ("design"|"impl"), file, pos ({line, col}).
function M.find_all()
  local design_entries = parse_design_files()
  if #design_entries == 0 then
    return {}
  end

  local gen_to_service = build_gen_to_service_map(design_entries)
  local impl_lookup = find_implementations(gen_to_service)

  local items = {}
  for _, entry in ipairs(design_entries) do
    local method_label = entry.service .. "." .. entry.method

    table.insert(items, {
      text = method_label,
      method_label = method_label,
      kind = "design",
      file = entry.file,
      pos = { entry.line, 0 },
    })

    local impl = impl_lookup[method_label]
    if impl then
      table.insert(items, {
        text = method_label,
        method_label = method_label,
        kind = "impl",
        file = impl.file,
        pos = { impl.line, 0 },
      })
    end
  end

  return items
end

--- Resolve a path to absolute, normalizing relative paths against cwd.
local function resolve_path(path)
  return vim.fn.fnamemodify(path, ":p")
end

--- Jump between design and implementation for the API method under the cursor.
--- If in a design file, jump to the implementation; if in an impl file, jump to the design.
function M.goto_counterpart()
  local current_file = resolve_path(vim.fn.expand("%"))
  local current_line = vim.fn.line(".")

  local design_entries, impl_lookup, impl_file_methods = build_lookups()
  if #design_entries == 0 then
    vim.notify("No API design entries found", vim.log.levels.WARN)
    return
  end

  if current_file:match("/server/api/design/") then
    local best_entry = nil
    for _, entry in ipairs(design_entries) do
      if resolve_path(entry.file) == current_file and entry.line <= current_line then
        if not best_entry or entry.line > best_entry.line then
          best_entry = entry
        end
      end
    end

    if best_entry then
      local key = best_entry.service .. "." .. best_entry.method
      local impl = impl_lookup[key]
      if impl then
        vim.cmd("edit " .. vim.fn.fnameescape(impl.file))
        vim.api.nvim_win_set_cursor(0, { impl.line, 0 })
        return
      else
        vim.notify("No implementation found for " .. key, vim.log.levels.WARN)
        return
      end
    end

    vim.notify("No API method found at cursor position (line " .. current_line .. ")", vim.log.levels.WARN)
    return
  end

  local methods = nil
  for file, file_methods in pairs(impl_file_methods) do
    if resolve_path(file) == current_file then
      methods = file_methods
      break
    end
  end

  if methods then
    local best = nil
    for _, m in ipairs(methods) do
      if m.impl_line <= current_line then
        if not best or m.impl_line > best.impl_line then
          best = m
        end
      end
    end

    if best then
      vim.cmd("edit " .. vim.fn.fnameescape(best.design_file))
      vim.api.nvim_win_set_cursor(0, { best.design_line, 0 })
      return
    end
  end

  vim.notify("Not in an API design or implementation file", vim.log.levels.WARN)
end

return M
