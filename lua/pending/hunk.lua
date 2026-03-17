--- Hunk data structure and apply/reject logic for pending.nvim
local state = require("pending.state")

local M = {}

--- Create a new hunk record.
--- @param id number unique per buffer
--- @param lnum number 1-based start line (original)
--- @param old_lines string[] original text lines
--- @param new_lines string[] proposed text lines
--- @return table hunk record
function M.new(id, lnum, old_lines, new_lines)
  return {
    id = id,
    lnum = lnum,
    old_lines = old_lines or {},
    new_lines = new_lines or {},
    extmark_ids = {},
    state = "pending",
  }
end

--- Get the current line position of a hunk using its primary extmark.
--- Falls back to hunk.lnum if no extmark is set.
--- @param buf number
--- @param hunk table
--- @return number 1-based line number
function M.get_lnum(buf, hunk)
  local ns = state.ns_id()
  if hunk.extmark_ids and hunk.extmark_ids[1] then
    local ok, pos = pcall(vim.api.nvim_buf_get_extmark_by_id, buf, ns, hunk.extmark_ids[1], {})
    if ok and pos and pos[1] then
      return pos[1] + 1 -- convert 0-based to 1-based
    end
  end
  return hunk.lnum
end

--- Accept a hunk: replace old_lines with new_lines in the buffer.
--- @param buf number
--- @param hunk table
function M.accept(buf, hunk)
  local ns = state.ns_id()
  local lnum = M.get_lnum(buf, hunk)
  local start_0 = lnum - 1
  local end_0 = start_0 + #hunk.old_lines

  -- Replace old lines with new lines
  vim.api.nvim_buf_set_lines(buf, start_0, end_0, false, hunk.new_lines)

  -- Clear extmarks for this hunk
  M.clear_extmarks(buf, hunk, ns)

  hunk.state = "accepted"
end

--- Reject a hunk: remove visual indicators, leave buffer text as-is.
--- @param buf number
--- @param hunk table
function M.reject(buf, hunk)
  local ns = state.ns_id()
  M.clear_extmarks(buf, hunk, ns)
  hunk.state = "rejected"
end

--- Clear all extmarks belonging to a hunk.
--- @param buf number
--- @param hunk table
--- @param ns number namespace id
function M.clear_extmarks(buf, hunk, ns)
  if hunk.extmark_ids then
    for _, eid in ipairs(hunk.extmark_ids) do
      pcall(vim.api.nvim_buf_del_extmark, buf, ns, eid)
    end
    hunk.extmark_ids = {}
  end
end

--- Find the pending hunk under the cursor.
--- @param buf number
--- @param hunks table[] list of hunk records
--- @return table|nil the hunk, or nil if none found
function M.find_at_cursor(buf, hunks)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
  for _, h in ipairs(hunks) do
    if h.state == "pending" then
      local lnum = M.get_lnum(buf, h)
      local span = math.max(#h.old_lines, 1)
      if cursor_line >= lnum and cursor_line < lnum + span then
        return h
      end
    end
  end
  return nil
end

return M
