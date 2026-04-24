-- API Picker: navigate between Goa design files and their Go implementations.
--
-- Links the Goa DSL in server/api/design/ to the receiver methods that implement
-- each endpoint. Exposes:
--
--   <leader>sA  — snacks picker listing both design and impl items,
--                  tagged with kind="design"/"impl" for filtering via <C-i>
--   gA          — jump between design and impl for the method under cursor
--
-- How it works:
--   1. Parse design files for Service/Method declarations (including ServicePublicV1/V2/V3).
--   2. Derive each service's gen package directory name (e.g. "Alert Events" + v2 -> alert_events_v2).
--   3. Find implementation files by searching server/app/ and server/api/ (excluding gen/) for
--      files that import a known gen package, then matching receiver method definitions in those
--      files back to the design Method names.
--   4. For goto_counterpart, use the nearest Method declaration at or above the cursor to
--      determine which method the user is in.

local M = {}

--- Parse design files to extract Service/Method definitions.
--- Matches Service(), ServicePublicV1/V2/V3() declarations and their Method() children.
--- Returns a list of {service, method, version, file, line} entries,
--- where version is nil for Service() or "v1"/"v2"/"v3" for versioned variants.
local function parse_design_files()
  local design_dir = "server/api/design"
  if vim.fn.isdirectory(design_dir) == 0 then
    return {}
  end

  -- Match all service files including versioned ones like _service_v2.go
  local files = vim.fn.glob(design_dir .. "/*_service*.go", false, true)
  local entries = {}

  for _, filepath in ipairs(files) do
    local current_service = nil
    local current_version = nil

    local lnum = 0
    for line in io.lines(filepath) do
      lnum = lnum + 1

      -- Match Service("Name"), ServicePublicV1("Name"), ServicePublicV2("Name"), etc.
      local variant, svc_name = line:match('^var%s+_%s*=%s*(Service[^(]*)%("([^"]+)"')
      if svc_name then
        current_service = svc_name
        local ver = variant:match("V(%d+)$")
        current_version = ver and ("v" .. ver) or nil
      end

      -- Match indented Method("Name" declarations within a service
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
--- Searches server/app/, server/api/, and server/integrations/ (excluding gen/) for
--- receiver methods in files that import a known gen package.
--- Returns a lookup table: "Service.Method" -> {file, line}
local function find_implementations(gen_to_service)
  -- List specific subdirectories rather than all of server/ to keep rg fast
  local function rg(pattern)
    return table.concat({
      "rg", "-n", "--no-heading",
      '--glob "*.go"',
      '--glob "!server/api/gen/**"',
      '"' .. pattern .. '"',
      "server/app/", "server/api/", "server/integrations/",
    }, " ")
  end

  -- Step 1: Find which files import which gen packages
  local import_output = vim.fn.system(rg("api/gen/"))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  -- Build file -> service_name mapping
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

  -- Step 2: Find method definitions in those files
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

  -- Build reverse lookup: impl file -> list of method mappings
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

--- Format a single API picker item for display.
--- Layout: Badge  Service.Method  icon filepath:line
local function format_api(item, picker)
  local ret = {}

  local badges = {
    design = { " \u{F1FC} ", "DiagnosticInfo" },    -- nf-fa-paint_brush
    impl   = { " \u{F121} ", "DiagnosticHint" },    -- nf-fa-code
  }
  local badge = badges[item.kind] or { " ? ", "Comment" }
  ret[#ret + 1] = { badge[1], badge[2] }
  ret[#ret + 1] = { " " }

  -- Service.Method name (normal foreground — prominent by position, not color)
  -- field="text" tells snacks to apply fuzzy match highlights here
  ret[#ret + 1] = { item.method_label or "", nil, field = "text" }
  ret[#ret + 1] = { " " }

  -- File path with icon (reuse snacks built-in filename formatter)
  vim.list_extend(ret, Snacks.picker.format.filename(item, picker))

  -- Line number
  if item.pos then
    ret[#ret + 1] = { ":" .. item.pos[1], "SnacksPickerRow" }
  end

  return ret
end

--- Snacks picker finder: returns both design and implementation items.
--- Each item has a `kind` field ("design" or "impl") for filtering.
function M.find_all(opts, ctx)
  local design_entries = parse_design_files()
  if #design_entries == 0 then
    return {}
  end

  local gen_to_service = build_gen_to_service_map(design_entries)
  local impl_lookup = find_implementations(gen_to_service)

  local items = {}
  for _, entry in ipairs(design_entries) do
    local method_label = entry.service .. "." .. entry.method

    -- Design item
    table.insert(items, {
      text = method_label,
      method_label = method_label,
      kind = "design",
      file = entry.file,
      pos = { entry.line, 0 },
    })

    -- Implementation item (if found)
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

--- Filter modes for the picker, cycled by <C-i>
M.filter_modes = { "all", "design", "impl" }
M.filter_labels = { all = "All", design = "Design only", impl = "Impl only" }

--- Shared picker config: toggle filter action and keybind.
local function picker_actions_and_keys(title_fn)
  return {
    actions = {
      toggle_api_filter = function(picker)
        local modes = M.filter_modes
        local labels = M.filter_labels

        local current = picker._api_filter or "all"
        local idx = 1
        for i, m in ipairs(modes) do
          if m == current then
            idx = i
            break
          end
        end
        local next_mode = modes[(idx % #modes) + 1]
        picker._api_filter = next_mode

        if next_mode == "all" then
          picker.opts.transform = nil
        else
          picker.opts.transform = function(item)
            if item.kind ~= next_mode then
              return false
            end
          end
        end

        picker.title = title_fn(labels[next_mode])
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-i>"] = { "toggle_api_filter", mode = { "i", "n" }, desc = "Toggle design/impl filter" },
        },
      },
    },
  }
end

--- Open the API picker for browsing all APIs.
function M.pick()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    vim.notify("snacks.nvim picker not available", vim.log.levels.ERROR)
    return
  end

  local cfg = picker_actions_and_keys(function(label)
    return "APIs [" .. label .. "] (C-i: toggle filter)"
  end)

  snacks.picker.pick(vim.tbl_deep_extend("force", cfg, {
    title = "APIs (C-i: toggle filter)",
    format = format_api,
    finder = function(opts, ctx)
      return M.find_all(opts, ctx)
    end,
  }))
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

  -- Check if we're in a design file: find the closest design entry at or above cursor
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

  -- Check if we're in an implementation file (compare via absolute paths)
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
