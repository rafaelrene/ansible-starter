return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "echasnovski/mini.files",
    opts = {
      mappings = {
        go_in = "",
        go_out = "",
      },
      windows = {
        width_preview = 100,
      },
    },
    keys = {
      {
        "-",
        function()
          require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
        end,
        desc = "Open mini.files (Directory of Current File)",
      },
      {
        "--",
        function()
          require("mini.files").open(vim.uv.cwd(), true)
        end,
        desc = "Open mini.files (cwd)",
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    opts = function()
      local winopts_preview = {
        layout = "vertical",
        vertical = "down:80%,border-top",
      }

      if not vim.tbl_isempty(LazyVim.lsp.get_clients({ bufnr = 0, name = "vtsls" })) then
        winopts_preview = {
          layout = "vertical",
          vertical = "down:80%,border-top",
          hidden = "hidden",
        }
      end

      return {
        winopts = {
          layout = "vertical",
          fullscreen = true,
          preview = winopts_preview,
        },
      }
    end,
  },
}
