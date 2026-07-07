-- Monorepo fix: Delve runs `go test -c` from its working directory, which defaults
-- to nvim's cwd (repo root). In monorepos where go.mod is in a subdirectory, this
-- fails. We add dlvCwd to tell Delve to run from the go.mod directory instead.
-- See: https://github.com/go-delve/delve/pull/2660
local function wrap_ginkgo_adapter()
  local ginkgo = require("neotest-ginkgo")
  local original_build_spec = ginkgo.build_spec

  ginkgo.build_spec = function(self, args)
    local spec = original_build_spec(self, args)
    if spec and spec.strategy and type(spec.strategy) == "table" and spec.strategy.cwd then
      local gomod = vim.fn.findfile("go.mod", spec.strategy.cwd .. ";")
      if gomod ~= "" then
        spec.strategy.dlvCwd = vim.fn.fnamemodify(gomod, ":p:h")
      end
    end
    return spec
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
