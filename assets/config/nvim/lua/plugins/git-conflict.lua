return {
  "akinsho/git-conflict.nvim",
  event = "User",
  version = "*",
  opts = function(_, opts)
    opts = opts or {}

    opts.disable_diagnostics = true -- This will disable the diagnostics in a buffer whilst it is conflicted

    vim.keymap.set("n", "<leader>gC", "", { desc = "Git Conflict" })
    vim.keymap.set("n", "<leader>gCd", "<Plug>(git-conflict-base)", { desc = "Base" })
    vim.keymap.set("n", "<leader>gCo", "<Plug>(git-conflict-ours)", { desc = "Ours" })
    vim.keymap.set("n", "<leader>gCt", "<Plug>(git-conflict-theirs)", { desc = "Theirs" })
    vim.keymap.set("n", "<leader>gCb", "<Plug>(git-conflict-both)", { desc = "Both" })
    vim.keymap.set("n", "<leader>gC0", "<Plug>(git-conflict-none)", { desc = "None" })
    vim.keymap.set("n", "<leader>gCq", "<Plug>(git-conflict-listqf)", { desc = "Quickfix" })

    return opts
  end,
}
