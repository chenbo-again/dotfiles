-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.exrc = true
vim.opt.spelllang:append("cjk")
vim.g.autoformat = false

if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  vim.g.clipboard = vim.env.TMUX and "tmux" or "osc52"
end
vim.opt.clipboard = "unnamedplus"
