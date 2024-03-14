return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "piersolenski/telescope-import.nvim",
      config = function()
        require("telescope").load_extension("import")
      end,
    },
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      config = function()
        require("telescope").load_extension("fzf")
      end,
    },
  },
  keys = {
    { "<leader>gb", "<cmd> Telescope git_branches <cr>", desc = "branches" },
    { "<leader>sv", "<cmd> Telescope treesitter <cr>", desc = "treesitter symbols" },
    { "<leader>i", "<cmd> Telescope import <cr>", desc = "Import" },
  },
  opts = function(_, opts)
    opts.defaults.path_display = { shorten = 10 }
    opts.defaults.layout_strategy = "vertical"
    opts.defaults.layout_config = {
      vertical = {
        height = 0.99,
        mirror = true,
        preview_height = 0.75,
        preview_cutoff = 0,
        prompt_position = "top",
        width = 0.99,
      },
    }

    opts.extensions = vim.tbl_deep_extend("error", opts.extensions or {}, {
      import = { insert_at_top = true },
      fzf = {
        case_mode = "smart_case",
        fuzzy = true,
        override_file_sorter = true,
        override_generic_sorter = true,
      },
    })

    return opts
  end,
}
