local util = require("lspconfig/util")

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        emmet_language_server = {
          filetypes = {
            "html",

            "css",
            "scss",

            "javascript",
            "typescript",

            "javascriptreact",
            "typescriptreact",

            "svelte",
          },
        },
        eslint = {
          settings = {
            -- helps eslint find the eslintrc when it's placed in a subfolder instead of the cwd root
            workingDirectory = { mode = "auto" },
          },
        },
        gopls = {
          settings = {
            gopls = {
              semanticTokens = true,
              completeUnimported = true,
              usePlaceholders = true,
              analyses = {
                unusedparams = true,
              },
            },
          },
        },
      },
      setup = {
        gopls = function()
          -- workaround for gopls not supporting semantictokensprovider
          -- https://github.com/golang/go/issues/54531#issuecomment-1464982242
          require("snacks").util.lsp.on(function(_, client)
            if client.name == "gopls" then
              if not client.server_capabilities.semanticTokensProvider then
                local semantic = client.config.capabilities.textDocument.semanticTokens

                if semantic ~= nil then
                  client.server_capabilities.semanticTokensProvider = {
                    full = true,
                    legend = {
                      tokenTypes = semantic.tokenTypes,
                      tokenModifiers = semantic.tokenModifiers,
                    },
                    range = true,
                  }
                end
              end
            end
          end)
          -- end workaround
        end,
        eslint = function()
          require("snacks").util.lsp.on(function(_, client)
            if client.name == "eslint" then
              client.server_capabilities.documentFormattingProvider = true
            elseif client.name == "tsserver" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)

          vim.api.nvim_create_autocmd("BufWritePre", {
            callback = function(event)
              if util.get_active_client_by_name(event.buf, "eslint") then
                vim.cmd("LspEslintFixAll")
              end
            end,
          })
        end,
      },
    },
  },
}
