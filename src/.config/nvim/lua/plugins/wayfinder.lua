return {
  "error311/wayfinder.nvim",
  opts = {},
  config = function(_, opts)
    require("wayfinder").setup(opts)

    -- Search's pale background clashes with Tree-sitter's syntax foreground in previews.
    -- Visual supplies only a dark selection background, so syntax colours remain readable.
    local function apply_highlights()
      vim.api.nvim_set_hl(0, "WayfinderPreviewTarget", { link = "Visual" })
    end

    apply_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("WayfinderHighlights", { clear = true }),
      callback = apply_highlights,
    })
  end,
}
