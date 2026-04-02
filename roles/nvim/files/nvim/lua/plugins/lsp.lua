local util = require("lspconfig/util")

local eslint_root = util.root_pattern(
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.json",
  ".eslintrc.yaml",
  ".eslintrc.yml"
)

local function get_eslint_root(fname)
  return eslint_root(fname) or vim.fs.dirname(vim.fs.find(".git", { path = fname, upward = true })[1])
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        oxfmt = { require_cwd = true },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsserver = {
          enable = false,
        },
        ts_ls = {
          enable = false,
        },
        vtsls = {
          settings = {
            typescript = {
              preferGoToSourceDefinition = true,
            },
            javascript = {
              preferGoToSourceDefinition = true,
            },
          },
        },
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
        eslint = function(_, opts)
          vim.lsp.config(
            "eslint",
            vim.tbl_deep_extend("force", opts, {
              root_dir = function(bufnr, on_dir)
                local fname = vim.api.nvim_buf_get_name(bufnr)
                local root = get_eslint_root(fname)

                if root then
                  on_dir(root)
                end
              end,
            })
          )
          vim.lsp.enable("eslint")

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

          return true
        end,
      },
    },
  },
}
