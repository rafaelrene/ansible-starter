-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

---@param mode string|table
---@param lhs string
---@param rhs string|function
---@param desc string
local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

---@param lhs string
---@param rhs string|function
---@param desc string
local nmap = function(lhs, rhs, desc)
  map("n", lhs, rhs, desc)
end

---@param lhs string
---@param rhs string|function
---@param desc string
local vmap = function(lhs, rhs, desc)
  map("v", lhs, rhs, desc)
end

---@param lhs string
---@param rhs string|function
---@param desc string
local imap = function(lhs, rhs, desc)
  map("i", lhs, rhs, desc)
end

-- Basic normal mappings
nmap("J", "mzJ`z", "Join lines")

nmap("<C-d>", "<C-d>zz", "Move buffer page down")
nmap("<C-u>", "<C-u>zz", "Move bugger page up")

nmap("n", "nzzzv", "Next")
nmap("N", "Nzzzv", "Previous")

nmap("<leader>fs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], "Find and Replace (In Current Buffer)")

nmap("<leader>fC", [[:let @+ = expand("%:p")<CR>]], "Copy file path (Absolute)")
nmap("<leader>fc", [[:let @+ = expand("%:.")<CR>]], "Copy file path (Relative)")

-- Basic visual mappings
vmap("K", ":m '< -2<CR>gv=gv", "Move selection line up")
vmap("J", ":m '> +1<CR>gv=gv", "Move selection line down")

-- Basic insert mappings
imap("jj", "<ESC>", "Return to normal mode")

-- Plugins
-- Most of the time keymaps for plugins are lazy-loaded from the plugin file itself.

-- Git
nmap("<leader>gg", [[:Neogit<CR>]], "Neogit")
