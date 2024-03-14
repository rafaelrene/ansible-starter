return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Add required parsers
      vim.list_extend(opts.ensure_installed, {
        "css",
        "graphql",
        "html",
        "jsdoc",
        "json",
        "lua",
        "rust",
        "scss",
        "typescript",
        "go",
        "gomod",
        "gowork",
        "gosum",
      })

      -- Disable hightlighing on big files
      opts.highlight.disable = function()
        return vim.b.large_buf
      end

      return opts
    end,
  },
}
