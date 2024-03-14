return {
  "wallpants/github-preview.nvim",
  cmd = { "GithubPreviewToggle" },
  keys = { "<leader>fp" },
  ft = "markdown",
  config = function(_, opts)
    local gpreview = require("github-preview")
    gpreview.setup(opts)

    local fns = gpreview.fns

    vim.keymap.set("n", "<leader>fp", fns.toggle, { desc = "Markdown preview" })
  end,
}
