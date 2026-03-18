--- pending.nvim API Examples and Usage Guide
---
--- This file demonstrates how to use pending.nvim in various scenarios.
--- Copy snippets into your config or use them as reference.

-- ============================================================================
-- 1. BASIC SETUP
-- ============================================================================

local pending = require("pending")

-- Initialize the plugin with default settings
pending.setup()

-- Or customize the setup
pending.setup({
  -- Highlight colors (can be any highlight group)
  highlights = {
    add = "DiffAdd",      -- color for additions
    delete = "DiffDelete", -- color for deletions
    change = "DiffChange", -- color for changes
  },
  -- Show labels on virtual lines ("+ proposed", "- original")
  virtual_text = true,
  -- Default keymaps (set to false to disable)
  keymaps = {
    accept = "<leader>pa",  -- Accept hunk under cursor
    reject = "<leader>pr",  -- Reject hunk under cursor
  },
})

-- ============================================================================
-- 2. BASIC USAGE: Attaching hunks to a buffer
-- ============================================================================

--- Example: Suggest a simple text change
local function example_simple_change()
  local buf = 0 -- current buffer

  -- Define hunks (proposed changes)
  local hunks = {
    {
      lnum = 5,  -- 1-based line number where the change starts
      old_lines = { "function old_name()" }, -- original lines
      new_lines = { "function new_name()" }, -- proposed lines
    },
  }

  -- Attach hunks to the buffer
  pending.create(buf, hunks)
end

--- Example: Multiple suggestions in one buffer
local function example_multiple_hunks()
  local buf = 0

  pending.create(buf, {
    -- Change line 10
    {
      lnum = 10,
      old_lines = { "  x = 5" },
      new_lines = { "  x = 10" },
    },
    -- Add lines after line 20
    {
      lnum = 21,
      old_lines = {},
      new_lines = { "  -- New comment", "  y = 20" },
    },
    -- Delete lines 30-31
    {
      lnum = 30,
      old_lines = { "  old_var = 1", "  old_var = 2" },
      new_lines = {},
    },
  })
end

-- ============================================================================
-- 3. CALLBACKS: Responding to user actions
-- ============================================================================

--- Example: Listen to accept/reject events
local function example_with_callbacks()
  local buf = 0

  pending.create(buf, {
    { lnum = 5, old_lines = { "old" }, new_lines = { "new" } },
  }, {
    on_accept = function(buffer, hunk)
      print("User accepted hunk #" .. hunk.id)
      -- You could: log metrics, trigger follow-up actions, etc.
    end,

    on_reject = function(buffer, hunk)
      print("User rejected hunk #" .. hunk.id)
      -- You could: analyze why the suggestion was rejected, track stats, etc.
    end,

    on_done = function(buffer)
      print("All hunks in buffer " .. buffer .. " are now resolved!")
      -- You could: save the buffer, refresh LSP, notify parent tool, etc.
    end,
  })
end

-- ============================================================================
-- 4. INTEGRATION WITH LSP / TOOLS
-- ============================================================================

--- Example: LSP client suggesting auto-fixes
local function example_lsp_integration()
  -- When LSP server provides code actions with text edits:
  local buf = 0
  local diagnostic_name = "unused_variable"

  -- Convert LSP text edits to pending hunks
  local hunks = {
    {
      lnum = 42,
      old_lines = { "  unused_var = 5" },
      new_lines = {}, -- Delete the unused variable
    },
  }

  pending.create(buf, hunks, {
    on_done = function()
      -- Notify the LSP server that the code action was applied
      vim.notify("Fixed: " .. diagnostic_name, vim.log.levels.INFO)
    end,
  })
end

--- Example: Refactoring tool suggesting changes
local function example_refactor_tool()
  local buf = 0

  pending.create(buf, {
    {
      lnum = 1,
      old_lines = { "def old_function():" },
      new_lines = { "def refactored_function():" },
    },
    {
      lnum = 5,
      old_lines = { "  return 2 * x" },
      new_lines = { "  return x * 2  # Consistent with function order" },
    },
  }, {
    on_done = function()
      -- After refactoring is applied, run tests or format
      vim.cmd("silent !pytest")
    end,
  })
end

-- ============================================================================
-- 5. CHECKING STATE
-- ============================================================================

--- Example: Query buffer state
local function example_check_state()
  local buf = 0

  -- Create some hunks
  pending.create(buf, {
    { lnum = 1, old_lines = { "a" }, new_lines = { "A" } },
    { lnum = 3, old_lines = { "c" }, new_lines = { "C" } },
  })

  -- Check if buffer has pending hunks
  if pending.has_pending(buf) then
    print("Buffer has unresolved changes")
  else
    print("All changes resolved")
  end

  -- You could use this in statusline:
  -- if pending.has_pending(0) then
  --   return "⏳ pending"
  -- end
end

-- ============================================================================
-- 6. PROGRAMMATIC ACCEPT/REJECT
-- ============================================================================

--- Example: Accept/reject all hunks programmatically
local function example_programmatic()
  local buf = 0

  pending.create(buf, {
    { lnum = 1, old_lines = { "old1" }, new_lines = { "new1" } },
    { lnum = 2, old_lines = { "old2" }, new_lines = { "new2" } },
  })

  -- Accept all hunks at once
  pending.accept_all(buf)

  -- Or reject all
  -- pending.reject_all(buf)

  -- Or clear without applying anything
  -- pending.clear(buf)
end

--- Example: Accept only specific hunks
local function example_selective_accept()
  local buf = 0

  pending.create(buf, {
    { lnum = 1, old_lines = { "old1" }, new_lines = { "new1" } },
    { lnum = 3, old_lines = { "old3" }, new_lines = { "new3" } },
  }, {
    on_accept = function(_, hunk)
      -- Only accept hunks with certain properties
      if hunk.id == 1 then
        print("Accepted important hunk")
      end
    end,
  })

  -- Move cursor to first hunk and accept it
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  pending.accept(buf)

  -- Move cursor to second hunk and reject it
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  pending.reject(buf)
end

-- ============================================================================
-- 7. CUSTOM KEYMAPS
-- ============================================================================

--- Example: Define custom keymaps for pending hunks
local function example_custom_keymaps()
  -- Setup without default keymaps
  pending.setup({ keymaps = false })

  -- Define your own keymaps
  vim.keymap.set("n", "<C-y>", function()
    pending.accept(0)
  end, { desc = "Accept pending hunk" })

  vim.keymap.set("n", "<C-n>", function()
    pending.reject(0)
  end, { desc = "Reject pending hunk" })

  vim.keymap.set("n", "<leader>pa", function()
    pending.accept_all(0)
  end, { desc = "Accept all pending hunks" })

  vim.keymap.set("n", "<leader>pr", function()
    pending.reject_all(0)
  end, { desc = "Reject all pending hunks" })
end

-- ============================================================================
-- 8. USER COMMANDS
-- ============================================================================

--- Example: Using the built-in user commands
local function example_user_commands()
  -- These commands are automatically registered:

  -- :PendingAccept        - Accept hunk under cursor
  -- :PendingReject        - Reject hunk under cursor
  -- :PendingAcceptAll     - Accept all pending hunks
  -- :PendingRejectAll     - Reject all pending hunks
  -- :PendingClear         - Remove all hunks without applying

  -- You can call them from mappings:
  vim.keymap.set("n", "<leader>pa", ":PendingAccept<CR>", { silent = true })
  vim.keymap.set("n", "<leader>pr", ":PendingReject<CR>", { silent = true })

  -- Or use them in your plugin logic
  -- vim.cmd("PendingAcceptAll")
end

-- ============================================================================
-- 9. ADVANCED: Multiple independent change sets
-- ============================================================================

--- Example: Managing multiple independent suggestion sources
local function example_multiple_sources()
  local buf = 0

  -- Source 1: LSP auto-fixes
  local lsp_hunks = {
    { lnum = 10, old_lines = { "unused = 5" }, new_lines = {} },
  }

  -- Source 2: Formatter suggestions
  local formatter_hunks = {
    { lnum = 20, old_lines = { "x=1" }, new_lines = { "x = 1" } },
  }

  -- Merge them
  local all_hunks = {}
  for _, h in ipairs(lsp_hunks) do
    table.insert(all_hunks, h)
  end
  for _, h in ipairs(formatter_hunks) do
    table.insert(all_hunks, h)
  end

  pending.create(buf, all_hunks)
end

-- ============================================================================
-- 10. PRACTICAL EXAMPLE: Integrate with a hypothetical tool
-- ============================================================================

--- Example: Plugin integration pattern
local MyTool = {}

--- Suggest changes from external tool
function MyTool.suggest_changes(buf, suggestions)
  -- Convert tool format to pending.nvim format
  local hunks = {}
  for _, suggestion in ipairs(suggestions) do
    table.insert(hunks, {
      lnum = suggestion.line,
      old_lines = vim.split(suggestion.old_text, "\n"),
      new_lines = vim.split(suggestion.new_text, "\n"),
    })
  end

  -- Attach to buffer
  pending.create(buf, hunks, {
    on_done = function()
      -- Notify the external tool that changes were applied
      MyTool.notify_changes_applied(buf)
    end,
  })
end

function MyTool.notify_changes_applied(buf)
  print("[MyTool] Changes applied to buffer " .. buf)
end

-- Usage:
-- MyTool.suggest_changes(0, {
--   { line = 5, old_text = "old", new_text = "new" },
--   { line = 10, old_text = "foo()", new_text = "bar()" },
-- })

-- ============================================================================
-- 11. STATUSLINE INTEGRATION
-- ============================================================================

--- Example: Show pending status in statusline
local function example_statusline()
  -- For lualine
  local function pending_status()
    if pending.has_pending(0) then
      return "🔄 pending"
    end
    return ""
  end

  -- Add to your lualine config:
  -- {
  --   function() return pending_status() end,
  --   cond = function() return pending.has_pending(0) end,
  --   color = { fg = "#ff9e64" }
  -- }

  -- Or for native statusline:
  vim.opt.statusline:append("%{v:lua.require('pending').has_pending(0) ? '🔄pending' : ''}")
end

-- ============================================================================
-- SUMMARY
-- ============================================================================
--
-- pending.nvim provides a clean API for managing inline pending changes:
--
--   pending.setup(opts)          -- Initialize plugin
--   pending.create(buf, hunks, opts)  -- Attach hunks
--   pending.accept(buf)          -- Accept hunk at cursor
--   pending.reject(buf)          -- Reject hunk at cursor
--   pending.accept_all(buf)      -- Accept all hunks
--   pending.reject_all(buf)      -- Reject all hunks
--   pending.has_pending(buf)     -- Check if buffer has pending hunks
--   pending.clear(buf)           -- Remove all hunks
--
-- Key features:
--   ✓ Hunk-level accept/reject
--   ✓ Lazy rendering with extmarks
--   ✓ Save guard (prevents saving with pending hunks)
--   ✓ Undo awareness (warns if buffer is undone)
--   ✓ Customizable highlights
--   ✓ User commands
--   ✓ Callbacks (on_accept, on_reject, on_done)
--   ✓ Works with any buffer (LSP, tools, formatters, etc.)
