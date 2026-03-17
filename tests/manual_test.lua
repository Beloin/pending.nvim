--- Manual test script for pending.nvim
--- Run this in Neovim to interactively test the plugin
---
--- Usage:
---   1. Open Neovim with: nvim -u tests/minimal_init.lua
---   2. Run: :source tests/manual_test.lua
---   3. Follow the on-screen instructions

local pending = require("pending")

-- Setup the plugin
pending.setup({
  keymaps = {
    accept = "<leader>pa",
    reject = "<leader>pr",
  },
})

--- Helper to print section headers
local function section(title)
  vim.notify(string.rep("=", 60), vim.log.levels.INFO)
  vim.notify("  " .. title, vim.log.levels.INFO)
  vim.notify(string.rep("=", 60), vim.log.levels.INFO)
end

--- Helper to print instructions
local function instruct(text)
  vim.notify("📝 " .. text, vim.log.levels.INFO)
end

--- Helper to print status
local function status(text)
  vim.notify("✓ " .. text, vim.log.levels.INFO)
end

--- Helper to print a command example
local function example(cmd)
  vim.notify("  → " .. cmd, vim.log.levels.WARN)
end

-- Test 1: Simple single-hunk accept
local function test_simple_accept()
  section("TEST 1: Simple Accept")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "function greet(name)",
    "  print('Hello, ' .. name)",
    "end",
  })

  instruct("Created a buffer with a function that prints 'Hello'")
  instruct("Now proposing to change the greeting to 'Hi'...")

  pending.create(buf, {
    {
      lnum = 2,
      old_lines = { "  print('Hello, ' .. name)" },
      new_lines = { "  print('Hi, ' .. name)" },
    },
  }, {
    on_accept = function()
      status("You accepted the hunk!")
    end,
  })

  instruct("You should see strikethrough on line 2 and a virtual line with the proposal below it")
  instruct("Position your cursor on line 2 and press <leader>pa to accept the change")
  example("Try: <leader>pa")
  instruct("After accepting, the buffer will be updated and this test completes")
end

-- Test 2: Multiple hunks with mixed operations
local function test_multiple_hunks()
  section("TEST 2: Multiple Hunks (Add, Delete, Modify)")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "import foo",
    "import bar",
    "import baz",
    "",
    "def main():",
    "  print('old message')",
    "  x = 42",
    "  return x",
  })

  instruct("Created a Python-like buffer with imports and a function")
  instruct("Proposing 3 changes:")
  instruct("  1. Remove 'import bar' (line 2)")
  instruct("  2. Change 'old message' to 'new message' (line 6)")
  instruct("  3. Add a comment after the function")

  pending.create(buf, {
    -- Delete line 2
    { lnum = 2, old_lines = { "import bar" }, new_lines = {} },
    -- Modify line 6
    { lnum = 6, old_lines = { "  print('old message')" }, new_lines = { "  print('new message')" } },
    -- Add a line after line 7
    { lnum = 8, old_lines = {}, new_lines = { "  # result is stored in x" } },
  }, {
    on_accept = function(_, h)
      vim.notify("  ✓ Accepted hunk " .. h.id, vim.log.levels.INFO)
    end,
    on_reject = function(_, h)
      vim.notify("  ✗ Rejected hunk " .. h.id, vim.log.levels.INFO)
    end,
    on_done = function()
      status("All hunks resolved!")
    end,
  })

  instruct("Try accepting some hunks and rejecting others:")
  example("<leader>pa  (accept)")
  example("<leader>pr  (reject)")
  instruct("Or use the commands: :PendingAcceptAll or :PendingRejectAll")
end

-- Test 3: Save guard test
local function test_save_guard()
  section("TEST 3: Save Guard (Prevents saving with pending hunks)")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_name(buf, "/tmp/pending_test.txt")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "This file has pending changes",
  })

  instruct("Created a buffer that will be protected by save guard")
  instruct("Attaching a pending hunk...")

  pending.create(buf, {
    { lnum = 1, old_lines = { "This file has pending changes" }, new_lines = { "This file has been updated" } },
  })

  instruct("Try to save this buffer now:")
  example(":w")
  instruct("You should see an error: 'Buffer has unresolved pending changes'")
  instruct("Accept or reject the pending hunk to allow saving:")
  example(":PendingAccept")
  example(":w")
end

-- Test 4: Undo warning
local function test_undo_warning()
  section("TEST 4: Undo Awareness")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "line1",
    "line2",
    "line3",
  })

  instruct("Created a buffer with pending hunks")

  pending.create(buf, {
    { lnum = 1, old_lines = { "line1" }, new_lines = { "LINE1" } },
  })

  instruct("Now if you modify the buffer and undo:")
  example(":normal ichanged<Esc>")
  example(":undo")
  instruct("You'll see a warning that undo was detected with pending hunks")
end

-- Test 5: API demo
local function test_api_demo()
  section("TEST 5: API Demo")

  vim.notify("Demonstrating the pending.nvim public API:", vim.log.levels.INFO)
  vim.notify("", vim.log.levels.INFO)

  vim.notify("pending.setup(opts)      → Initialize plugin with options", vim.log.levels.INFO)
  vim.notify("pending.create(buf, hunks, opts) → Attach hunks to buffer", vim.log.levels.INFO)
  vim.notify("pending.accept(buf)      → Accept hunk under cursor", vim.log.levels.INFO)
  vim.notify("pending.reject(buf)      → Reject hunk under cursor", vim.log.levels.INFO)
  vim.notify("pending.accept_all(buf)  → Accept all pending hunks", vim.log.levels.INFO)
  vim.notify("pending.reject_all(buf)  → Reject all pending hunks", vim.log.levels.INFO)
  vim.notify("pending.has_pending(buf) → Check if buffer has unresolved hunks", vim.log.levels.INFO)
  vim.notify("pending.clear(buf)       → Remove all hunks without applying", vim.log.levels.INFO)

  vim.notify("", vim.log.levels.INFO)
  vim.notify("Hunk format:", vim.log.levels.INFO)
  vim.notify("  { lnum = 1, old_lines = {...}, new_lines = {...} }", vim.log.levels.INFO)

  vim.notify("", vim.log.levels.INFO)
  vim.notify("Callbacks (in create options):", vim.log.levels.INFO)
  vim.notify("  on_accept(buf, hunk)  → Called when a hunk is accepted", vim.log.levels.INFO)
  vim.notify("  on_reject(buf, hunk)  → Called when a hunk is rejected", vim.log.levels.INFO)
  vim.notify("  on_done(buf)          → Called when all hunks are resolved", vim.log.levels.INFO)
end

-- Main menu
local function show_menu()
  section("pending.nvim Manual Test Suite")

  vim.notify("", vim.log.levels.INFO)
  vim.notify("Choose a test to run:", vim.log.levels.INFO)
  vim.notify("", vim.log.levels.INFO)
  vim.notify("  1. :call TestPendingSimpleAccept()", vim.log.levels.WARN)
  vim.notify("  2. :call TestPendingMultipleHunks()", vim.log.levels.WARN)
  vim.notify("  3. :call TestPendingSaveGuard()", vim.log.levels.WARN)
  vim.notify("  4. :call TestPendingUndoWarning()", vim.log.levels.WARN)
  vim.notify("  5. :call TestPendingApiDemo()", vim.log.levels.WARN)
  vim.notify("", vim.log.levels.INFO)
end

-- Register test functions as user commands
vim.api.nvim_create_user_command("TestPendingSimpleAccept", test_simple_accept, {})
vim.api.nvim_create_user_command("TestPendingMultipleHunks", test_multiple_hunks, {})
vim.api.nvim_create_user_command("TestPendingSaveGuard", test_save_guard, {})
vim.api.nvim_create_user_command("TestPendingUndoWarning", test_undo_warning, {})
vim.api.nvim_create_user_command("TestPendingApiDemo", test_api_demo, {})

-- Show menu on load
show_menu()

vim.notify("", vim.log.levels.INFO)
instruct("Start with: :TestPendingSimpleAccept")
