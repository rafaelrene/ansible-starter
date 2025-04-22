return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim", -- required
    "ibhagwan/fzf-lua", -- optional
  },
  config = true,
  keys = {
    { "<leader>gg", [[:Neogit<CR>]], desc = "Neogit", silent = true },
  },
  event = "VeryLazy",
}
