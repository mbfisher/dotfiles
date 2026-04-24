-- Plugin configuration: stores resolved options for other modules to read.
--
-- Options:
--   picker — "snacks" | "telescope" | "auto" (default: "auto")

local M = {}

M.defaults = {
  picker = "auto",
}

-- Active options, updated by setup()
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
