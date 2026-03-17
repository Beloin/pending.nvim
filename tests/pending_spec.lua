--- Tests for pending.nvim
local pending = require("pending")
local state = require("pending.state")

--- Helper: create a scratch buffer with given lines.
local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Make it the current buffer in a window so cursor operations work
  vim.api.nvim_set_current_buf(buf)
  return buf
end

--- Helper: get all lines from a buffer.
local function get_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("pending.nvim", function()
  before_each(function()
    -- Ensure clean state
    pending.setup({ keymaps = false })
  end)

  describe("create + has_pending", function()
    it("should attach hunks and report pending", function()
      local buf = make_buf({ "line1", "line2", "line3" })
      pending.create(buf, {
        { lnum = 2, old_lines = { "line2" }, new_lines = { "modified2" } },
      })

      assert.is_true(pending.has_pending(buf))
    end)

    it("should return false for buffer with no hunks", function()
      local buf = make_buf({ "line1" })
      assert.is_false(pending.has_pending(buf))
    end)
  end)

  describe("accept", function()
    it("should apply new_lines and mark hunk as accepted", function()
      local buf = make_buf({ "line1", "line2", "line3" })
      pending.create(buf, {
        { lnum = 2, old_lines = { "line2" }, new_lines = { "modified2" } },
      })

      -- Trigger render so extmarks are placed
      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      -- Position cursor on the hunk
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      pending.accept(buf)

      local lines = get_lines(buf)
      assert.are.same({ "line1", "modified2", "line3" }, lines)
      assert.is_false(pending.has_pending(buf))
    end)

    it("should handle multi-line replacement", function()
      local buf = make_buf({ "a", "b", "c", "d" })
      pending.create(buf, {
        { lnum = 2, old_lines = { "b", "c" }, new_lines = { "x", "y", "z" } },
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      pending.accept(buf)

      local lines = get_lines(buf)
      assert.are.same({ "a", "x", "y", "z", "d" }, lines)
    end)
  end)

  describe("reject", function()
    it("should leave buffer unchanged and mark hunk as rejected", function()
      local buf = make_buf({ "line1", "line2", "line3" })
      pending.create(buf, {
        { lnum = 2, old_lines = { "line2" }, new_lines = { "modified2" } },
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      pending.reject(buf)

      local lines = get_lines(buf)
      assert.are.same({ "line1", "line2", "line3" }, lines)
      assert.is_false(pending.has_pending(buf))
    end)
  end)

  describe("accept_all", function()
    it("should accept all pending hunks", function()
      local buf = make_buf({ "a", "b", "c", "d" })
      pending.create(buf, {
        { lnum = 1, old_lines = { "a" }, new_lines = { "A" } },
        { lnum = 3, old_lines = { "c" }, new_lines = { "C" } },
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      pending.accept_all(buf)

      local lines = get_lines(buf)
      assert.are.same({ "A", "b", "C", "d" }, lines)
      assert.is_false(pending.has_pending(buf))
    end)
  end)

  describe("reject_all", function()
    it("should reject all pending hunks without changing buffer", function()
      local buf = make_buf({ "a", "b", "c" })
      pending.create(buf, {
        { lnum = 1, old_lines = { "a" }, new_lines = { "X" } },
        { lnum = 3, old_lines = { "c" }, new_lines = { "Z" } },
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      pending.reject_all(buf)

      local lines = get_lines(buf)
      assert.are.same({ "a", "b", "c" }, lines)
      assert.is_false(pending.has_pending(buf))
    end)
  end)

  describe("on_done callback", function()
    it("should fire when all hunks are resolved", function()
      local done_called = false
      local buf = make_buf({ "line1", "line2" })
      pending.create(buf, {
        { lnum = 1, old_lines = { "line1" }, new_lines = { "new1" } },
      }, {
        on_done = function()
          done_called = true
        end,
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      pending.accept(buf)

      assert.is_true(done_called)
    end)
  end)

  describe("clear", function()
    it("should remove all hunks and report no pending", function()
      local buf = make_buf({ "line1", "line2" })
      pending.create(buf, {
        { lnum = 1, old_lines = { "line1" }, new_lines = { "new1" } },
      })

      assert.is_true(pending.has_pending(buf))

      pending.clear(buf)

      assert.is_false(pending.has_pending(buf))
    end)
  end)

  describe("offset tracking", function()
    it("should correctly accept hunks that change line count", function()
      local buf = make_buf({ "a", "b", "c", "d", "e" })
      pending.create(buf, {
        { lnum = 2, old_lines = { "b" }, new_lines = { "b1", "b2" } },
        { lnum = 4, old_lines = { "d" }, new_lines = { "D" } },
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      pending.accept_all(buf)

      local lines = get_lines(buf)
      assert.are.same({ "a", "b1", "b2", "c", "D", "e" }, lines)
    end)
  end)

  describe("callbacks", function()
    it("should fire on_accept and on_reject callbacks", function()
      local accepted = {}
      local rejected = {}
      local buf = make_buf({ "a", "b", "c" })

      pending.create(buf, {
        { lnum = 1, old_lines = { "a" }, new_lines = { "A" } },
        { lnum = 3, old_lines = { "c" }, new_lines = { "C" } },
      }, {
        on_accept = function(_, h)
          table.insert(accepted, h.id)
        end,
        on_reject = function(_, h)
          table.insert(rejected, h.id)
        end,
      })

      local s = state.get(buf)
      local render_mod = require("pending.render")
      render_mod.render_hunks(buf, s.hunks, state.ns_id(), { virtual_text = true })
      s.rendered = true

      -- Accept first hunk
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      pending.accept(buf)

      -- Reject second hunk
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      pending.reject(buf)

      assert.are.same({ 1 }, accepted)
      assert.are.same({ 2 }, rejected)
    end)
  end)
end)
