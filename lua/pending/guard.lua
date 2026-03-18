--- BufWritePre save-guard for pending.nvim
local state = require("pending.state")

local M = {}

local augroup = vim.api.nvim_create_augroup("PendingGuard", { clear = true })

--- Attach a save guard to a buffer. Prevents writing while hunks are pending.
--- @param buf number
function M.attach(buf)
  local buf_state = state.get(buf)
  if not buf_state then
    return
  end

  local id = vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    buffer = buf,
    callback = function()
      local s = state.get(buf)
      if s then
        for _, h in ipairs(s.hunks) do
          if h.state == "pending" then
            vim.notify(
              "[pending.nvim] Buffer has unresolved pending changes. Resolve or clear them before saving.",
              vim.log.levels.ERROR
            )
            return true -- abort the write
          end
        end
      end
    end,
  })

  buf_state.guard_autocmd_id = id
end

--- Detach the save guard from a buffer.
--- @param buf number
function M.detach(buf)
  local buf_state = state.get(buf)
  if buf_state and buf_state.guard_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, buf_state.guard_autocmd_id)
    buf_state.guard_autocmd_id = nil
  end
end

return M
