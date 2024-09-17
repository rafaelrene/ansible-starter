-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local large_buffer_augroup = augroup("large_buffer", { clear = true })

local MAX_FILE_SIZE = 1024 * 10 * 100 -- 100kb

autocmd({ "BufReadPre" }, {
  pattern = "*",
  group = large_buffer_augroup,
  callback = function()
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))

    if ok and stats and (stats.size > MAX_FILE_SIZE) then
      print("File too large! Disabled additional features!")

      vim.b.large_buf = true

      vim.cmd("setlocal noswapfile noundofile nocursorline")
      vim.cmd("syntax off")
      vim.cmd("syntax clear")

      vim.cmd("NoMatchParen")
    end
  end,
})
