--- pending.nvim user commands bootstrap

if vim.g.loaded_pending_nvim then
  return
end
vim.g.loaded_pending_nvim = true

vim.api.nvim_create_user_command("PendingAccept", function()
  require("pending").accept(vim.api.nvim_get_current_buf())
end, { desc = "Accept pending hunk under cursor" })

vim.api.nvim_create_user_command("PendingReject", function()
  require("pending").reject(vim.api.nvim_get_current_buf())
end, { desc = "Reject pending hunk under cursor" })

vim.api.nvim_create_user_command("PendingAcceptAll", function()
  require("pending").accept_all(vim.api.nvim_get_current_buf())
end, { desc = "Accept all pending hunks in buffer" })

vim.api.nvim_create_user_command("PendingRejectAll", function()
  require("pending").reject_all(vim.api.nvim_get_current_buf())
end, { desc = "Reject all pending hunks in buffer" })

vim.api.nvim_create_user_command("PendingClear", function()
  require("pending").clear(vim.api.nvim_get_current_buf())
end, { desc = "Remove all pending hunks without applying" })
