-- Live fuzzy picker over the registry (matchfuzzypos).
--
-- Same blocking-input model as the popup: a float opened enter=false while we
-- read the query with getcharstr() and re-filter on every key. Selecting an
-- entry feeds its lhs back with remap, so the existing keymap/trigger machinery
-- executes it — search doesn't duplicate execution semantics.

local keys = require("which-key.keys")

local M = {}

local ns = vim.api.nvim_create_namespace("which-key-search")
M._win = nil
M._buf = nil

local ESC = "\27"
local CR = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
local BS = vim.api.nvim_replace_termcodes("<BS>", true, true, true)
local C_N = vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
local C_P = vim.api.nvim_replace_termcodes("<C-p>", true, true, true)
local DOWN = vim.api.nvim_replace_termcodes("<Down>", true, true, true)
local UP = vim.api.nvim_replace_termcodes("<Up>", true, true, true)

local function ensure_hl()
  vim.api.nvim_set_hl(0, "WhichKeySearchMatch", { link = "IncSearch", default = true })
  vim.api.nvim_set_hl(0, "WhichKeySearchSel", { link = "Visual", default = true })
  vim.api.nvim_set_hl(0, "WhichKeySearchPrompt", { link = "Question", default = true })
end

--- Build searchable items from the registry.
--- @return table[] { lhs, desc, mode, mapping, text }
function M.items()
  local list = require("which-key").registry():list()
  local lhs_w = 0
  for _, m in ipairs(list) do
    lhs_w = math.max(lhs_w, #m.lhs)
  end
  lhs_w = math.min(lhs_w, 24)
  local items = {}
  for _, m in ipairs(list) do
    items[#items + 1] = {
      lhs = m.lhs,
      desc = m.desc or "",
      mode = m.mode,
      mapping = m,
      text = string.format("%-" .. lhs_w .. "s  %s", m.lhs, m.desc or ""),
    }
  end
  return items
end

--- Filter items by query. Returns { item, pos } where pos are matched byte
--- offsets into item.text (empty for an empty query → show everything).
function M.filter(items, query)
  if query == "" then
    local out = {}
    for _, it in ipairs(items) do
      out[#out + 1] = { item = it, pos = {} }
    end
    return out
  end
  -- Pass only stringy fields to matchfuzzypos (never the rhs funcref).
  local probe = {}
  for i, it in ipairs(items) do
    probe[i] = { text = it.text, idx = i }
  end
  local res = vim.fn.matchfuzzypos(probe, query, { key = "text" })
  local matched, positions = res[1], res[2]
  local out = {}
  for i, d in ipairs(matched) do
    out[#out + 1] = { item = items[math.floor(d.idx)], pos = positions[i] or {} }
  end
  return out
end

local function render(query, filtered, sel)
  ensure_hl()
  local lines = { "> " .. query }
  for _, f in ipairs(filtered) do
    lines[#lines + 1] = "  " .. f.item.text
  end

  if not (M._buf and vim.api.nvim_buf_is_valid(M._buf)) then
    M._buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M._buf].bufhidden = "wipe"
  end
  vim.bo[M._buf].modifiable = true
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.bo[M._buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(M._buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(M._buf, ns, 0, 0, { end_col = 1, hl_group = "WhichKeySearchPrompt" })
  if #filtered > 0 then
    vim.api.nvim_buf_set_extmark(M._buf, ns, sel, 0, { line_hl_group = "WhichKeySearchSel" })
    for i, f in ipairs(filtered) do
      for _, p in ipairs(f.pos) do
        vim.api.nvim_buf_set_extmark(M._buf, ns, i, 2 + p, { end_col = 2 + p + 1, hl_group = "WhichKeySearchMatch" })
      end
    end
  end

  local height = math.min(#lines, 15)
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.max(40, math.min(width + 2, vim.o.columns - 4))
  local cfg = {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " which-key search ",
    zindex = 200,
  }
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.api.nvim_win_set_config(M._win, cfg)
  else
    M._win = vim.api.nvim_open_win(M._buf, false, cfg)
  end
  vim.cmd("redraw")
end

function M.close()
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.api.nvim_win_close(M._win, true)
  end
  M._win = nil
  vim.cmd("redraw")
end

-- Can a mapping of `map_mode` be fired by feeding keys while in `cur` mode?
-- Normal-mode maps always; otherwise the current mode must match the family.
function M._can_feed(map_mode, cur)
  if map_mode == "n" or map_mode == "" then
    return cur == "n"
  end
  if map_mode == "v" or map_mode == "x" or map_mode == "s" then
    return cur == "v" or cur == "V" or cur == "\22" or cur == "s" or cur == "S"
  end
  if map_mode == "i" then
    return cur == "i"
  end
  return map_mode == cur
end

-- Feed the chosen lhs so its real mapping/trigger executes it.
local function execute(item)
  if not M._can_feed(item.mode, vim.fn.mode()) then
    vim.notify(
      ('which-key: "%s" is a %s-mode mapping — invoke it from that mode'):format(item.lhs, item.mode),
      vim.log.levels.WARN
    )
    return
  end
  vim.api.nvim_feedkeys(keys.normalize(item.lhs), "m", false)
end

function M.open()
  local items = M.items()
  if #items == 0 then
    vim.notify("which-key: nothing registered to search", vim.log.levels.INFO)
    return
  end

  local query, sel = "", 1
  local filtered = M.filter(items, query)
  render(query, filtered, sel)

  local chosen
  while true do
    local c = vim.fn.getcharstr()
    if c == ESC then
      break
    elseif c == CR then
      chosen = filtered[sel] and filtered[sel].item
      break
    elseif c == BS or c == "\8" or c == "\127" then
      local n = vim.fn.strchars(query)
      if n > 0 then
        query = vim.fn.strcharpart(query, 0, n - 1)
        filtered = M.filter(items, query)
        sel = 1
      end
    elseif c == C_N or c == DOWN then
      sel = math.min(sel + 1, #filtered)
    elseif c == C_P or c == UP then
      sel = math.max(sel - 1, 1)
    elseif c:byte(1) ~= 0x80 and c:byte(1) >= 0x20 and c:byte(1) ~= 0x7f then
      query = query .. c
      filtered = M.filter(items, query)
      sel = 1
    end
    sel = math.max(1, math.min(sel, math.max(#filtered, 1)))
    render(query, filtered, sel)
  end

  M.close()
  if chosen then
    execute(chosen)
  end
end

return M
