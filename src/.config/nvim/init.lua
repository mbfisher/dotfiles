---------------------------------------------------------------------------------------------------
-- 1. General options (Must be set BEFORE plugins)
---------------------------------------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true -- show line numbers
vim.opt.termguicolors = true -- required by bufferline

-- Timeouts for which-key
vim.opt.timeout = true
vim.opt.timeoutlen = 300

-- Indentation
vim.opt.expandtab = true   -- use spaces instead of tabs
vim.opt.shiftwidth = 4     -- size of an indent
vim.opt.softtabstop = 4    -- number of spaces tabs count for the editing operations
vim.opt.tabstop = 4        -- number of spaces that a <Tab> in the file counts for

---------------------------------------------------------------------------------------------------
-- 2. Packages (Add everything first)
---------------------------------------------------------------------------------------------------
vim.pack.add({
	-- theme
    { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	-- telescope
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
	-- which-key
    "https://github.com/nvim-tree/nvim-web-devicons",
    "https://github.com/nvim-mini/mini.icons",
    "https://github.com/folke/which-key.nvim",
    -- bufferline
    "https://github.com/akinsho/bufferline.nvim",
    -- treesitter
    "https://github.com/mason-org/mason.nvim",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
    -- lsp
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason-lspconfig.nvim",
})

---------------------------------------------------------------------------------------------------
-- 3. Theme (Set this after packages are added)
---------------------------------------------------------------------------------------------------
vim.cmd.colorscheme "catppuccin"

---------------------------------------------------------------------------------------------------
-- 4. Plugin Setup
---------------------------------------------------------------------------------------------------

-- mason
-- Needs to be before treesitter and lsp sections
require("mason").setup()

-- treesitter
-- Installing treesitter parsers requires the tree-sitter-cli. We use mason to ensure it's installed.

local function setup_treesitter()
    -- Ensure Neovim knows where Mason's binaries live
    -- vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH
    
    -- Now that we know the CLI is there, install the parser
    require('nvim-treesitter').install { 'python' }
end

-- 3. Logic to "Wait" for the CLI
local registry = require("mason-registry")
local ts_cli = registry.get_package("tree-sitter-cli")

if ts_cli:is_installed() then
    -- If already installed, just run setup
    setup_treesitter()
else
    -- If not installed, wait for the event
    ts_cli:on("install:success", function()
        vim.schedule(function()
            print("tree-sitter-cli installed! Now setting up Python...")
            setup_treesitter()
        end)
    end)
    
    print("tree-sitter-cli is missing. Installing now...")
    ts_cli:install()
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python' },
  callback = function() vim.treesitter.start() end,
})

-- lsp
-- As of Neovim 0.12, roles are changing in the usual set of plugins:
-- Neovim core: Provides the LSP client (vim.lsp.start, vim.lsp.enabled)
-- mason: Downloads language servers
-- nvim-lspconfig: A collection of JSON-like files in /lsp/ that give Neovim default config for 400+ language servers
-- mason-lspconfig: Bridges mason and nvim-lspconfig
--
-- With mason and nvim-lspconfig set up, we use mason-lspconfig as the entry point. We declaratively state which
-- LSP servers we want, and they get automatically installed via Mason, and enabled via the nvim-lspconfig
-- server config.
-- Configs provided by nvim-lspconfig contain "root markers", which are files in nvim root that are detected
-- in order to enable LSP servers.
-- To debug LSP setup run :checkhealth vim.lsp
require("mason-lspconfig").setup {
    ensure_installed = { "lua_ls" },
}

-- bufferline
require("bufferline").setup({})

-- which-key
local wk = require("which-key")
wk.setup({
    preset = "helix", -- Recommended for v3
})
wk.add({
    -- { "<leader>b", group = "buffer" },
    { "<leader>f", group = "file" },
    {
            "<leader>b",
            group = "buffer",
            expand = function()
              return require("which-key.extras").expand.buf()
            end,
          },
})


---------------------------------------------------------------------------------------------------
-- 5. Keymaps
---------------------------------------------------------------------------------------------------
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete Buffer" })

vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename" })

vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })

vim.keymap.set("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })

-- Keep 'y' internal, but make 'Y' copy to system
vim.keymap.set({"n", "v"}, "Y", '"+y', { desc = "Yank to system clipboard" })
