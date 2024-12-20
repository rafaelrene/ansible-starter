return {
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = {
      flavor = "macchiato",
      transparent_background = true, -- disables setting the background color.
      show_end_of_buffer = true, -- shows the '~' characters after the end of buffers
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
