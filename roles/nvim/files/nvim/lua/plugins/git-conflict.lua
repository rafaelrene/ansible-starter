return {
  "akinsho/git-conflict.nvim",
  event = "User",
  version = "*",
  opts = function(_, opts)
    opts = opts or {}

    opts.disable_diagnostics = true -- This will disable the diagnostics in a buffer whilst it is conflicted

    vim.keymap.set("n", "<leader>gCo", "<Plug>(git-conflict-ours)", { desc = "Git Conflict: Ours" })
    vim.keymap.set("n", "<leader>gCt", "<Plug>(git-conflict-theirs)", { desc = "Git Conflict: Theirs" })
    vim.keymap.set("n", "<leader>gCb", "<Plug>(git-conflict-both)", { desc = "Git Conflict: Both" })
    vim.keymap.set("n", "<leader>gC0", "<Plug>(git-conflict-none)", { desc = "Git Conflict: None" })

    return opts
  end,
}
