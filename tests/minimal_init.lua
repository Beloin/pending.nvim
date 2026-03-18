--- Minimal init for running tests
vim.cmd([[set rtp+=.]])
vim.cmd([[set rtp+=.deps/plenary.nvim]])

-- Disable swap files and backups for tests
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
