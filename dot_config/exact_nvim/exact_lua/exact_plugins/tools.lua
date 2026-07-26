return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local clangd = vim.fn.expand("~/.local/bin/clangd")
      if vim.fn.executable(clangd) ~= 1 then
        return
      end

      -- Prefer the standalone clangd installed by fetch-tools.sh. Without it,
      -- LazyVim may install and manage clangd through Mason normally.
      opts.servers.clangd = vim.tbl_deep_extend("force", opts.servers.clangd or {}, {
        mason = false,
        cmd = {
          clangd,
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders=true",
          "--fallback-style=llvm",
        },
        keys = {
          { "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
        },
        root_markers = {
          "compile_commands.json",
          "compile_flags.txt",
          "configure.ac",
          "Makefile",
          "configure.in",
          "config.h.in",
          "meson.build",
          "meson_options.txt",
          "build.ninja",
          ".git",
        },
        before_init = function(params)
          -- Neovim uses LSP 3.17 positionEncodings; omit clangd's deprecated extension.
          params.capabilities.offsetEncoding = nil
        end,
        init_options = {
          usePlaceholders = true,
          completeUnimported = true,
          clangdFileStatus = true,
        },
      })
    end,
  },
}
