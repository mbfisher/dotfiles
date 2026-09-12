-- Go's -trimpath (set repo-wide by mise in core) rewrites compiled-in source paths
-- from absolute to "<module path>/<relative>". Keeping it on for editor test runs
-- means they share the Go build cache with the shell instead of maintaining a
-- duplicate set, but Ginkgo then reports those trimmed paths while neotest keys
-- positions by absolute path. These helpers map a trimmed path back to disk.

local uv = vim.uv or vim.loop

local function parent_dir(path)
  local stripped = path:gsub("/+$", "")
  local parent = stripped:match("^(.*)/[^/]+$")
  if not parent or parent == "" then
    return "/"
  end
  return parent
end

-- Returns the module path declared in go.mod, and the directory containing it.
local function find_module(start_path)
  if not start_path or start_path == "" then
    return nil, nil
  end

  local resolved = uv.fs_realpath(start_path) or start_path
  local stat = uv.fs_stat(resolved)
  local dir = stat and stat.type == "directory" and resolved or parent_dir(resolved)

  local gomod_path
  while dir do
    local candidate = dir .. "/go.mod"
    local candidate_stat = uv.fs_stat(candidate)
    if candidate_stat and candidate_stat.type == "file" then
      gomod_path = candidate
      break
    end

    local parent = parent_dir(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  if not gomod_path then
    return nil, nil
  end

  local file = io.open(gomod_path, "r")
  if not file then
    return nil, nil
  end

  for _ = 1, 20 do
    local line = file:read("*l")
    if not line then
      break
    end
    local module_path = line:match("^module%s+(%S+)")
    if module_path then
      file:close()
      return module_path, dir
    end
  end
  file:close()

  return nil, nil
end

-- Anything already absolute, or that does not resolve to a file on disk (dependency
-- paths keep a "mod@v1.2.3/" prefix), is returned untouched.
local function untrim_path(path, module_path, module_dir)
  if not module_dir or path:sub(1, 1) == "/" then
    return path
  end

  local relative = path
  if module_path then
    local prefix = module_path .. "/"
    if path:sub(1, #prefix) == prefix then
      relative = path:sub(#prefix + 1)
    end
  end

  local candidate = module_dir .. "/" .. relative
  local stat = uv.fs_stat(candidate)
  if stat and stat.type == "file" then
    return candidate
  end

  return path
end

-- Monorepo fix: Delve runs `go test -c` from its working directory, which defaults
-- to nvim's cwd (repo root). In monorepos where go.mod is in a subdirectory, this
-- fails. We add dlvCwd to tell Delve to run from the go.mod directory instead.
-- See: https://github.com/go-delve/delve/pull/2660
local function wrap_ginkgo_adapter()
  local ginkgo = require("neotest-ginkgo")
  local original_build_spec = ginkgo.build_spec

  ginkgo.build_spec = function(args)
    local spec = original_build_spec(args)
    if not spec then
      return spec
    end

    local context = spec.context or {}
    local function focus_file_arg(path)
      if context.report_input_type == "namespace" then
        -- Ginkgo applies line focus to leaf specs, not container declarations.
        -- A Describe's declaration line therefore excludes all of its children.
        path = context.report_input_path
      end

      local file_path, line = path:match("^(.*):(%d+)$")
      if line then
        return vim.fn.fnamemodify(file_path, ":t") .. ":" .. line
      end
      return vim.fn.fnamemodify(path, ":t")
    end

    local function fix_focus_file(args_list, flag)
      if type(args_list) ~= "table" then
        return
      end
      for i, arg in ipairs(args_list) do
        if arg == flag and type(args_list[i + 1]) == "string" then
          args_list[i + 1] = focus_file_arg(args_list[i + 1])
        end
      end
    end

    -- Ginkgo's file filter only needs a basename. Keeping it independent of
    -- absolute/module-relative build paths makes regular neotest runs reliable.
    fix_focus_file(spec.command, "--focus-file")

    if spec.strategy and type(spec.strategy) == "table" and spec.strategy.cwd then
      local gomod = vim.fn.findfile("go.mod", spec.strategy.cwd .. ";")
      if gomod ~= "" then
        spec.strategy.dlvCwd = vim.fn.fnamemodify(gomod, ":p:h")
      end

      -- neotest-ginkgo passes --ginkgo.output-dir to the compiled test binary,
      -- but output-dir is a Ginkgo CLI-only flag. Point json-report directly at
      -- the absolute report path instead.
      local dap_args = spec.strategy.args
      local report_path = spec.context and spec.context.report_output_path
      if type(dap_args) == "table" and report_path then
        local fixed_args = {}
        local i = 1
        while i <= #dap_args do
          if dap_args[i] == "--ginkgo.output-dir" then
            i = i + 2
          elseif dap_args[i] == "--ginkgo.json-report" then
            vim.list_extend(fixed_args, { dap_args[i], report_path })
            i = i + 2
          else
            table.insert(fixed_args, dap_args[i])
            i = i + 1
          end
        end
        fix_focus_file(fixed_args, "--ginkgo.focus-file")
        spec.strategy.args = fixed_args
      end
    end
    return spec
  end

  local original_results = ginkgo.results

  -- Every id in the report collection starts with the spec's source path, which is
  -- trimmed. Rewrite that prefix so ids match the tree neotest built from the
  -- filesystem, otherwise no result maps back to a test and runs look empty.
  ginkgo.results = function(spec, result, tree)
    local collection = original_results(spec, result, tree)

    local reference = tree and tree:data() and tree:data().path or (spec and spec.cwd)
    local module_path, module_dir = find_module(reference)
    if not module_dir then
      return collection
    end

    local remapped = {}
    for id, value in pairs(collection) do
      local path, rest = id:match("^(.-)(::.*)$")
      if not path then
        path, rest = id, ""
      end
      remapped[untrim_path(path, module_path, module_dir) .. rest] = value
    end

    return remapped
  end

  return ginkgo
end

-- Ginkgo packages have a suite_test.go bootstrap file.
local function is_ginkgo_dir(file_path)
  local dir = vim.fn.fnamemodify(file_path, ":h")
  return vim.fn.filereadable(dir .. "/suite_test.go") == 1
end

-- Warn once if the Go treesitter parser is missing or broken, since neotest-ginkgo
-- silently returns no tests when it can't parse. Common after brew upgrades or
-- macOS provenance issues (see ~/dotfiles/issues/001-nvim-macos-provenance-crash.md).
local parser_checked = false
local function check_go_parser()
  if parser_checked then
    return
  end
  parser_checked = true
  local ok, err = pcall(vim.treesitter.language.add, "go")
  if not ok then
    vim.notify(
      "Go treesitter parser is missing or broken — neotest won't find tests.\n"
        .. "Run :TSInstall! go to fix.\n\n"
        .. tostring(err),
      vim.log.levels.ERROR
    )
  end
end

return {
  {
    "nvim-contrib/nvim-ginkgo",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "go",
        once = true,
        callback = function()
          vim.schedule(check_go_parser)
        end,
      })
    end,
  },
  {
    "nvim-neotest/neotest",
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      -- Make the two Go adapters exclusive: neotest-ginkgo claims files in Ginkgo
      -- packages (suite_test.go present), neotest-golang claims the rest. This
      -- avoids neotest's unordered adapter iteration picking the wrong one.

      -- Wrap neotest-golang to skip Ginkgo directories. Since the module is a
      -- singleton, modifying it here persists when LazyVim's config instantiates
      -- the adapter later.
      local ok, golang = pcall(require, "neotest-golang")
      if ok then
        local original_golang_is_test = golang.is_test_file
        golang.is_test_file = function(file_path)
          if is_ginkgo_dir(file_path) then
            return false
          end
          return original_golang_is_test(file_path)
        end
      end

      local adapter = wrap_ginkgo_adapter()

      -- Only claim files in Ginkgo packages.
      local original_is_test = adapter.is_test_file
      adapter.is_test_file = function(file_path)
        return original_is_test(file_path) and is_ginkgo_dir(file_path)
      end

      -- The default filter_dir requires suite_test.go in every directory, which
      -- blocks traversal through intermediate dirs like app/. Allow all
      -- directories so neotest can discover deeply nested test packages.
      adapter.filter_dir = function(name, rel_path, root)
        return name ~= "vendor" and name ~= "node_modules" and name ~= "testdata"
      end

      table.insert(opts.adapters, adapter)
      return opts
    end,
  },
}
