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
    -- completion engine
    "https://github.com/saghen/blink.cmp",
    -- nvim config dev support
    "https://github.com/folke/lazydev.nvim",
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

-- lazydev
require("lazydev").setup({
  library = {
    -- Load luvit types when the `vim.uv` word is found
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
})

-- blink.cmp
require("blink.cmp").setup({
  fuzzy = {
    -- 1. Use the prebuilt binary if possible
    prebuilt_binaries = {
      download = true,
      -- This glob ensures it tries to find the latest stable prebuilt
      force_version = "v*",
    },
    -- 2. If it still fails, fall back to Lua silently 
    -- (keeps the editor usable while you troubleshoot)
    implementation = "prefer_rust",
  },

  -- 'default' preset: <C-space> to open, up/down arrows to choose, continue typing to select, <C-e> to cancel
  keymap = { preset = 'default' },

  appearance = {
    -- Sets the fallback highlight groups to nvim-cmp's groups 
    -- Useful if your colorscheme hasn't updated for blink yet
    use_nvim_cmp_as_default = true,
    -- 'mono' variant helps icons align better in some terminal fonts
    nerd_font_variant = 'mono'
  },

  -- THE "OPT-IN" CONTROL CENTER
  completion = {
    -- Controls the popup list
    menu = {
      -- Don't show automatically while typing
      auto_show = false
    },

    -- Shows a small preview window next to the completion item
    documentation = {
        auto_show = true,
        auto_show_delay_ms = 200 -- Slight delay so it doesn't flicker while scrolling
    },

    -- Ghost text shows the "predicted" completion in gray after your cursor
    -- You mentioned wanting 'opt-in', so keeping this off prevents extra visual noise
    ghost_text = { enabled = false },
  },

  -- SIGNATURE HELP
  -- This automatically opens function parameter hints (like "name: string") as you type
  signature = { enabled = true },

  -- SOURCE MANAGEMENT
  sources = {
    -- 'default' defines the order and priority of where results come from
    -- We put 'lazydev' first so nvim-api results always beat out random buffer text
    default = { "lazydev", "lsp", "path", "snippets", "buffer" },

    providers = {
      -- This connects folke/lazydev.nvim directly to the blink engine
      lazydev = {
        name = "LazyDev",
        module = "lazydev.integrations.blink",
        score_offset = 100, -- Boosts priority so LazyDev items appear at the top
      },
    },
  },
})

---------------------------------------------------------------------------------------------------
-- 5. Keymaps
---------------------------------------------------------------------------------------------------
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete Buffer" })

-- Show diagnostic under cursor in a floating window
vim.keymap.set('n', '<leader>cd', vim.diagnostic.open_float, { desc = "Line Diagnostics" })
vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename" })

-- Clear existing gr maps; see https://neovim.io/doc/user/lsp/#gra
for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
    if map.lhs:sub(1, 2) == "gr" then
        vim.keymap.del("n", map.lhs)
    end
end
-- Set LSP keymaps on a buffer when a client attaches
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
        end

        -- Navigation using Telescope with 'reuse_win'
        -- reuse_win will check if a buffer is already open and move the cursor in it
        map("n", "gd", function() 
            require("telescope.builtin").lsp_definitions({ reuse_win = true }) 
        end, "Goto Definition")

        map("n", "gr", "<cmd>Telescope lsp_references<cr>", "References")

        map("n", "gI", function() 
            require("telescope.builtin").lsp_implementations({ reuse_win = true }) 
        end, "Goto Implementation")

        map("n", "gy", function() 
            require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) 
        end, "Goto T[y]pe Definition")

        -- Actions
        map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
    end,
})

vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })

vim.keymap.set("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })

-- Keep 'y' internal, but make 'Y' copy to system
vim.keymap.set({"n", "v"}, "Y", '"+y', { desc = "Yank to system clipboard" })
