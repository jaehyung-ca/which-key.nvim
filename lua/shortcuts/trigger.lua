-- Trigger keymaps + the getcharstr state machine that drives the popup.
--
-- A "trigger" is a keymap installed on a prefix *root* (default: leader /
-- localleader). When pressed it hands control to a blocking input loop that
-- walks the registry trie keystroke-by-keystroke: descend → execute leaf →
-- or fall through. getcharstr() reads raw bytes whose encoding matches the
-- trie's split keys exactly, so lookups are a direct table index.
--
-- Scope: leader-rooted triggers only by default. Leader is not a builtin
-- command, so there is no shadowing/replay-recursion to handle. Non-leader
-- roots (g, z, …) can be allow-listed via config.triggers but are opt-in.

local keys = require("shortcuts.keys")
local popup = require("shortcuts.ui.popup")

local M = {}

local ESC = "\27"

M._cfg = nil
M._delay = 0
M._allowed = {} -- set of raw root keys we may trigger on
M._installed = {} -- _installed[mode][rawkey] = true
M._active = false

local function first_raw(lhs)
  return keys.split(keys.normalize(lhs))[1]
end

--- @param config table resolved plugin config
function M.setup(config)
  M._cfg = config
  M._delay = config.delay or vim.o.timeoutlen
  M._allowed = {}
  M._installed = {}

  M._allowed[vim.g.mapleader or "\\"] = true
  M._allowed[vim.g.maplocalleader or "\\"] = true
  if type(config.triggers) == "table" then
    for _, t in ipairs(config.triggers) do
      local raw = first_raw(type(t) == "table" and t[1] or t)
      if raw then
        M._allowed[raw] = true
      end
    end
  end
  M.refresh()
end

local function install(mode, rawkey)
  M._installed[mode] = M._installed[mode] or {}
  if M._installed[mode][rawkey] then
    return
  end
  M._installed[mode][rawkey] = true
  vim.keymap.set(mode, rawkey, function()
    M.run(mode, rawkey)
  end, { silent = true, nowait = true, desc = "shortcuts trigger" })
end

--- (Re)install triggers for every allow-listed root present in the registry.
function M.refresh()
  if not M._cfg then
    return -- setup() hasn't run; it will install everything itself
  end
  local reg = require("shortcuts").registry()
  for mode, root in pairs(reg.tries) do
    for rawkey in pairs(root.children) do
      if M._allowed[rawkey] then
        install(mode, rawkey)
      end
    end
  end
end

local function feed(raw, remap)
  vim.api.nvim_feedkeys(raw, remap and "m" or "n", false)
end

local function execute(mapping, seq)
  local rhs = mapping.rhs
  if type(rhs) == "function" then
    rhs()
  elseif type(rhs) == "string" then
    feed(vim.api.nvim_replace_termcodes(rhs, true, true, true), mapping.remap)
  else
    -- Annotated-only leaf (no executable rhs). Rare under leader; replay raw.
    feed(seq, false)
  end
end

-- Block up to `ms` for input to become available WITHOUT consuming it, so a
-- fast typist (keys already in typeahead) skips the popup entirely.
local function key_pending(ms)
  if ms <= 0 then
    return vim.fn.getchar(1) ~= 0
  end
  local waited, step = 0, 10
  while waited < ms do
    if vim.fn.getchar(1) ~= 0 then
      return true
    end
    vim.cmd("sleep " .. step .. "m")
    waited = waited + step
  end
  return vim.fn.getchar(1) ~= 0
end

-- The state machine. Assumes M._active is held by the caller.
local function loop(node, seq)
  local shown = false
  while true do
    if not node then
      return -- fell off the trie; nothing to do
    end
    -- Pure leaf → execute and stop.
    if node.mapping and not next(node.children) then
      popup.close()
      return execute(node.mapping, seq)
    end
    -- Prefix node → show the menu (after delay) and read the next key.
    if not shown and not key_pending(M._delay) then
      popup.open(node)
      shown = true
    end
    local c = vim.fn.getcharstr()
    if c == "" or c == ESC then
      return
    end
    local child = node.children[c]
    if not child then
      return -- unknown continuation: cancel (swallow the stray key)
    end
    node, seq = child, seq .. c
    if shown then
      popup.open(node) -- repaint next level immediately (no extra delay)
    end
  end
end

local function drive(node, seq)
  if M._active then
    feed(seq, false) -- re-entrancy guard: don't swallow
    return
  end
  M._active = true
  local ok, err = pcall(loop, node, seq)
  popup.close()
  M._active = false
  if not ok then
    vim.notify("shortcuts: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Entry point from a trigger keymap (root key already consumed).
function M.run(mode, root_rawkey)
  local root = require("shortcuts").registry().tries[mode]
  local node = root and root.children[root_rawkey]
  drive(node, root_rawkey)
end

--- Open the menu for an arbitrary prefix (used by :Shortcuts).
function M.open(mode, prefix)
  local node = require("shortcuts").registry():node_at(mode, prefix)
  if not node then
    vim.notify("shortcuts: no bindings under " .. prefix, vim.log.levels.INFO)
    return
  end
  drive(node, keys.normalize(prefix))
end

return M
