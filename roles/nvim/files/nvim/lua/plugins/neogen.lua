return {
  "danymat/neogen",
  lazy = true,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  cmd = "Neogen",
  keys = {
    { "gcd", "<cmd>Neogen<CR>", desc = "Neogen" },
  },
  event = "BufEnter",
  config = function(opts)
    opts.snippet_engine = "luasnip"

    if opts.languages == nil then
      opts.languages = {}
    end

    vim.list_extend(opts.languages, {
      javascript = {
        template = {
          annotation_convention = "jsdoc",
        },
      },
    })

    return require("neogen").setup(opts)
  end,
}
