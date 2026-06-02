local M = {}

local directions = {
  h = "L",
  j = "D",
  k = "U",
  l = "R",
  p = "l",
}

function M.navigate(direction)
  local current = vim.api.nvim_get_current_win()

  if direction ~= "p" then
    vim.cmd("wincmd " .. direction)
  end

  if direction == "p" or current == vim.api.nvim_get_current_win() then
    if not vim.env.TMUX_PANE then
      return
    end

    vim.system({ "tmux", "select-pane", "-t", vim.env.TMUX_PANE, "-" .. directions[direction] }, { detach = true })
  end
end

return M
