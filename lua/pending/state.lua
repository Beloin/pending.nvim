--- Per-buffer state registry for pending.nvim
local M = {}

local ns_id = vim.api.nvim_create_namespace("pending_nvim")

--- @type table<number, table>
local buffers = {}

--- Get the shared namespace id.
--- @return number
function M.ns_id()
  return ns_id
end

--- Get state for a buffer.
--- @param buf number
--- @return table|nil
function M.get(buf)
  return buffers[buf]
end

--- Set state for a buffer.
--- @param buf number
--- @param data table
function M.set(buf, data)
  buffers[buf] = data
end

--- Remove state for a buffer.
--- @param buf number
function M.remove(buf)
  buffers[buf] = nil
end

return M
