return {
  {
    "mrcjkb/haskell-tools.nvim",
    version = "^3", -- Recommended
    ft = { "haskell", "lhaskell", "cabal", "cabalproject" },
    config = function()
      local ht = require("haskell-tools")
      local bufnr = vim.api.nvim_get_current_buf()

      -- haskell-language-server relies heavily on codeLenses,
      -- so auto-refresh (see advanced configuration) is enabled by default
      vim.keymap.set("n", "<space>ca", vim.lsp.codelens.run, { desc = "Run code lenses" })
      -- Hoogle search for the type signature of the definition under the cursor
      vim.keymap.set("n", "<space>hs", ht.hoogle.hoogle_signature, { desc = "Search for hoogle signature" })
      -- Evaluate all code snippets
      vim.keymap.set("n", "<space>ea", ht.lsp.buf_eval_all, { desc = "Evaluate all code snippets" })
      -- Toggle a GHCi repl for the current package
      vim.keymap.set("n", "<leader>rr", ht.repl.toggle, { desc = "GHCi: Package" })
      -- Toggle a GHCi repl for the current buffer
      vim.keymap.set("n", "<leader>rf", function()
        ht.repl.toggle(vim.api.nvim_buf_get_name(0))
      end, { desc = "GHCi: Buffer", noremap = true, silent = true, buffer = bufnr })
      vim.keymap.set("n", "<leader>rq", ht.repl.quit, { desc = "GHCi: Quit" })

      return {}
    end,
  },
  {
    "mrcjkb/haskell-snippets.nvim",
    ft = { "haskell", "lhaskell", "cabal", "cabalproject" },
  },
}
