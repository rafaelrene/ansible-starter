return {
  {
    "folke/sidekick.nvim",
    keys = {
      {
        "<leader>aa",
        function()
          require("sidekick.cli").toggle({ focus = true, name = "opencode" })
        end,
        desc = "Toggle Sidekick (Opencode)",
        mode = { "n", "v" },
      },
      {
        "<leader>ap",
        function()
          require("sidekick.cli").prompt()
        end,
        desc = "Sidekick Ask Prompt",
        mode = { "n", "v" },
      },
    },
  },
}
