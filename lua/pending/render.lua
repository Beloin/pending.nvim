--- Extmark / virtual-text rendering for pending.nvim
local state = require("pending.state")

local M = {}

--- Setup default highlight groups (only if not already defined by user).
--- @param config table plugin configuration
function M.setup_highlights(config)
  local hl = config.highlights or {}
  vim.api.nvim_set_hl(0, "PendingAdd", { link = hl.add or "DiffAdd", default = true })
  vim.api.nvim_set_hl(0, "PendingDelete", { link = hl.delete or "DiffDelete", default = true })
  vim.api.nvim_set_hl(0, "PendingChange", { link = hl.change or "DiffChange", default = true })
end

--- Render all pending hunks in a buffer.
--- @param buf number
--- @param hunks table[]
--- @param ns number namespace id
--- @param config table plugin configuration
function M.render_hunks(buf, hunks, ns, config)
  local show_labels = config.virtual_text ~= false

  for _, h in ipairs(hunks) do
    if h.state ~= "pending" then
      goto continue
    end

    local lnum_0 = h.lnum - 1 -- 0-based
    local has_old = #h.old_lines > 0
    local has_new = #h.new_lines > 0
    local is_change = has_old and has_new
    local is_delete = has_old and not has_new
    -- local is_add = not has_old and has_new -- pure addition

    local extmark_ids = {}

    if has_old then
      -- Place strikethrough on old lines
      local hl_group = is_change and "PendingChange" or "PendingDelete"
      for i = 0, #h.old_lines - 1 do
        local line_idx = lnum_0 + i
        -- Ensure line exists in buffer
        local line_count = vim.api.nvim_buf_line_count(buf)
        if line_idx < line_count then
          local eid = vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
            end_row = line_idx + 1,
            hl_group = hl_group,
            hl_eol = true,
            priority = 1000,
          })
          table.insert(extmark_ids, eid)
        end
      end
    end

    if has_new then
      -- Build virtual lines for proposed text
      local virt_lines = {}
      local hl_group = is_change and "PendingChange" or "PendingAdd"
      for _, line in ipairs(h.new_lines) do
        local prefix = show_labels and "+ " or ""
        table.insert(virt_lines, { { prefix .. line, hl_group } })
      end

      -- Place virt_lines after the last old line (or at lnum if pure addition)
      local anchor_line = has_old and (lnum_0 + #h.old_lines - 1) or math.max(lnum_0 - 1, 0)
      local line_count = vim.api.nvim_buf_line_count(buf)
      anchor_line = math.min(anchor_line, line_count - 1)

      local eid = vim.api.nvim_buf_set_extmark(buf, ns, anchor_line, 0, {
        virt_lines = virt_lines,
        virt_lines_above = not has_old,
        priority = 1000,
      })
      table.insert(extmark_ids, eid)
    end

    -- Store the primary extmark (first one) for position tracking
    h.extmark_ids = extmark_ids

    ::continue::
  end
end

--- Clear extmarks for a single hunk.
--- @param buf number
--- @param hunk table
--- @param ns number
function M.clear_hunk(buf, hunk, ns)
  if hunk.extmark_ids then
    for _, eid in ipairs(hunk.extmark_ids) do
      pcall(vim.api.nvim_buf_del_extmark, buf, ns, eid)
    end
    hunk.extmark_ids = {}
  end
end

--- Clear all extmarks in the pending namespace for a buffer.
--- @param buf number
function M.clear_all(buf)
  local ns = state.ns_id()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

return M
