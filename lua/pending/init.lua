--- pending.nvim — Public API
--- Manages pending inline changes (suggested text hunks) in any buffer.

local state = require("pending.state")
local hunk_mod = require("pending.hunk")
local render = require("pending.render")
local guard = require("pending.guard")

local M = {}

local config = {
  highlights = {
    add = "DiffAdd",
    delete = "DiffDelete",
    change = "DiffChange",
  },
  virtual_text = true,
  keymaps = {
    accept = "<leader>pa",
    reject = "<leader>pr",
  },
}

local render_augroup = vim.api.nvim_create_augroup("PendingRender", { clear = true })
local undo_augroup = vim.api.nvim_create_augroup("PendingUndo", { clear = true })

--- Merge user options with defaults (shallow one-level merge).
local function merge_config(opts)
  if not opts then
    return
  end
  for key, val in pairs(opts) do
    if type(val) == "table" and type(config[key]) == "table" then
      for k, v in pairs(val) do
        config[key][k] = v
      end
    else
      config[key] = val
    end
  end
end

--- Check if all hunks in a buffer are resolved, and fire on_done if so.
--- @param buf number
local function check_done(buf)
  local buf_state = state.get(buf)
  if not buf_state then
    return
  end

  for _, h in ipairs(buf_state.hunks) do
    if h.state == "pending" then
      return
    end
  end

  -- All resolved
  guard.detach(buf)

  -- Remove undo autocmds
  if buf_state.undo_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, buf_state.undo_autocmd_id)
  end

  if buf_state.opts and buf_state.opts.on_done then
    buf_state.opts.on_done(buf)
  end

  state.remove(buf)
end

--- Setup the plugin with optional configuration.
--- @param opts table|nil
function M.setup(opts)
  merge_config(opts)
  render.setup_highlights(config)

  -- Setup keymaps
  if config.keymaps then
    if config.keymaps.accept then
      vim.keymap.set("n", config.keymaps.accept, function()
        M.accept(vim.api.nvim_get_current_buf())
      end, { desc = "Accept pending hunk under cursor" })
    end
    if config.keymaps.reject then
      vim.keymap.set("n", config.keymaps.reject, function()
        M.reject(vim.api.nvim_get_current_buf())
      end, { desc = "Reject pending hunk under cursor" })
    end
  end
end

--- Attach a set of hunks to a buffer.
--- @param buf number buffer handle (0 for current)
--- @param hunks table[] list of { lnum, old_lines, new_lines }
--- @param opts table|nil { on_accept, on_reject, on_done }
function M.create(buf, hunks, opts)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  opts = opts or {}

  -- Normalize hunks
  local normalized = {}
  for i, h in ipairs(hunks) do
    table.insert(normalized, hunk_mod.new(i, h.lnum, h.old_lines, h.new_lines))
  end

  -- Sort hunks by lnum (top to bottom)
  table.sort(normalized, function(a, b)
    return a.lnum < b.lnum
  end)

  local buf_state = {
    hunks = normalized,
    opts = opts,
    rendered = false,
    guard_autocmd_id = nil,
    undo_autocmd_id = nil,
    undo_warned = false,
  }

  state.set(buf, buf_state)

  -- Attach save guard
  guard.attach(buf)

  -- Lazy render: set up autocmd that renders on first BufEnter/CursorMoved
  local render_id
  render_id = vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
    group = render_augroup,
    buffer = buf,
    callback = function()
      local s = state.get(buf)
      if s and not s.rendered then
        render.render_hunks(buf, s.hunks, state.ns_id(), config)
        s.rendered = true
      end
      -- Remove this autocmd after first render
      if render_id then
        pcall(vim.api.nvim_del_autocmd, render_id)
      end
    end,
  })

  -- Undo awareness: warn once if user undoes inside a pending-active buffer
  local undo_seq = vim.fn.undotree().seq_cur
  local undo_id
  undo_id = vim.api.nvim_create_autocmd("TextChanged", {
    group = undo_augroup,
    buffer = buf,
    callback = function()
      local s = state.get(buf)
      if not s or s.undo_warned then
        return
      end
      local current_seq = vim.fn.undotree().seq_cur
      if current_seq < undo_seq then
        vim.notify(
          "[pending.nvim] Undo detected in buffer with pending changes. Some hunks may be out of sync.",
          vim.log.levels.WARN
        )
        s.undo_warned = true
      end
      undo_seq = current_seq
    end,
  })
  buf_state.undo_autocmd_id = undo_id
end

--- Accept the hunk under the cursor.
--- @param buf number buffer handle (0 for current)
function M.accept(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    vim.notify("[pending.nvim] No pending changes in this buffer.", vim.log.levels.INFO)
    return
  end

  local h = hunk_mod.find_at_cursor(buf, buf_state.hunks)
  if not h then
    vim.notify("[pending.nvim] No pending hunk under cursor.", vim.log.levels.INFO)
    return
  end

  hunk_mod.accept(buf, h)

  if buf_state.opts and buf_state.opts.on_accept then
    buf_state.opts.on_accept(buf, h)
  end

  check_done(buf)
end

--- Reject the hunk under the cursor.
--- @param buf number buffer handle (0 for current)
function M.reject(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    vim.notify("[pending.nvim] No pending changes in this buffer.", vim.log.levels.INFO)
    return
  end

  local h = hunk_mod.find_at_cursor(buf, buf_state.hunks)
  if not h then
    vim.notify("[pending.nvim] No pending hunk under cursor.", vim.log.levels.INFO)
    return
  end

  hunk_mod.reject(buf, h)

  if buf_state.opts and buf_state.opts.on_reject then
    buf_state.opts.on_reject(buf, h)
  end

  check_done(buf)
end

--- Accept all remaining hunks in a buffer (top to bottom).
--- @param buf number buffer handle (0 for current)
function M.accept_all(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    return
  end

  -- Process top-to-bottom so offset adjustments are straightforward
  for _, h in ipairs(buf_state.hunks) do
    if h.state == "pending" then
      hunk_mod.accept(buf, h)
      if buf_state.opts and buf_state.opts.on_accept then
        buf_state.opts.on_accept(buf, h)
      end
    end
  end

  check_done(buf)
end

--- Reject all remaining hunks in a buffer.
--- @param buf number buffer handle (0 for current)
function M.reject_all(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    return
  end

  for _, h in ipairs(buf_state.hunks) do
    if h.state == "pending" then
      hunk_mod.reject(buf, h)
      if buf_state.opts and buf_state.opts.on_reject then
        buf_state.opts.on_reject(buf, h)
      end
    end
  end

  check_done(buf)
end

--- Check if a buffer has any unresolved pending hunks.
--- @param buf number buffer handle (0 for current)
--- @return boolean
function M.has_pending(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    return false
  end

  for _, h in ipairs(buf_state.hunks) do
    if h.state == "pending" then
      return true
    end
  end

  return false
end

--- Remove all hunks from a buffer without applying them.
--- @param buf number buffer handle (0 for current)
function M.clear(buf)
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end

  local buf_state = state.get(buf)
  if not buf_state then
    return
  end

  render.clear_all(buf)
  guard.detach(buf)

  if buf_state.undo_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, buf_state.undo_autocmd_id)
  end

  state.remove(buf)
end

return M
