-- Floating popup that lists the continuations available from a trie node.
--
-- Display-only: opened with enter=false so it never steals focus. The trigger
-- state machine keeps reading input from the main loop while this is visible,
-- so we must vim.cmd("redraw") after every change to actually paint it.

local M = {}

local ns = vim.api.nvim_create_namespace("which-key-popup")
M._win = nil
M._buf = nil
M._border = "rounded"

local function ensure_hl()
  local set = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
  set("WhichKeyKey", { link = "Special" })
  set("WhichKeyDesc", { link = "Normal" })
  set("WhichKeyGroup", { link = "Function" })
  set("WhichKeySeparator", { link = "Comment" })
end

--- @param win_cfg table|nil the `win` config sub-table
function M.setup(win_cfg)
  if win_cfg and win_cfg.border then
    M._border = win_cfg.border
  end
end

--- Children of `node` as display items, sorted by key.
--- @return table[] { keydisp, desc, is_group }
function M.contents(node)
  local items = {}
  for rawkey, child in pairs(node.children) do
    local is_group = next(child.children) ~= nil
    local desc
    if is_group then
      desc = "+" .. (child.group or "")
    else
      desc = child.mapping and child.mapping.desc or ""
    end
    items[#items + 1] = { keydisp = vim.fn.keytrans(rawkey), desc = desc, is_group = is_group }
  end
  table.sort(items, function(a, b)
    local la, lb = a.keydisp:lower(), b.keydisp:lower()
    if la == lb then
      return a.keydisp < b.keydisp
    end
    return la < lb
  end)
  return items
end

local SEP = " → "
local GAP = 2

local function rpad(s, w)
  return s .. string.rep(" ", w - vim.fn.strdisplaywidth(s))
end
local function lpad(s, w)
  return string.rep(" ", w - vim.fn.strdisplaywidth(s)) .. s
end

--- Pure layout: turn items into lines + highlight marks. Exposed for tests.
--- @return string[] lines, table[] marks {row,col,end_col,hl}, integer width
function M._layout(items)
  local key_w, desc_w = 0, 0
  for _, it in ipairs(items) do
    key_w = math.max(key_w, vim.fn.strdisplaywidth(it.keydisp))
    desc_w = math.max(desc_w, vim.fn.strdisplaywidth(it.desc))
  end
  local cell = key_w + #SEP + desc_w
  local avail = math.min(vim.o.columns - 2, 100)
  local cols = math.max(1, math.floor((avail + GAP) / (cell + GAP)))
  cols = math.min(cols, #items)
  local rows = math.ceil(#items / cols)

  local lines, marks, width = {}, {}, 0
  for r = 0, rows - 1 do
    local parts = {}
    local col = 0
    for c = 0, cols - 1 do
      local it = items[r * cols + c + 1]
      if it then
        local key = lpad(it.keydisp, key_w)
        local desc = rpad(it.desc, desc_w)
        local kbytes = #key
        marks[#marks + 1] = { row = r, col = col, end_col = col + kbytes, hl = "WhichKeyKey" }
        marks[#marks + 1] = { row = r, col = col + kbytes, end_col = col + kbytes + #SEP, hl = "WhichKeySeparator" }
        marks[#marks + 1] = {
          row = r,
          col = col + kbytes + #SEP,
          end_col = col + kbytes + #SEP + #desc,
          hl = it.is_group and "WhichKeyGroup" or "WhichKeyDesc",
        }
        local text = key .. SEP .. desc
        parts[#parts + 1] = text .. string.rep(" ", GAP)
        col = col + #text + GAP
      end
    end
    local line = table.concat(parts):gsub("%s+$", "")
    lines[#lines + 1] = line
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return lines, marks, width
end

--- Open/refresh the popup for the children of `node`.
function M.open(node)
  local items = M.contents(node)
  if #items == 0 then
    M.close()
    return
  end
  ensure_hl()
  local lines, marks, width = M._layout(items)

  if not (M._buf and vim.api.nvim_buf_is_valid(M._buf)) then
    M._buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M._buf].bufhidden = "wipe"
  end
  vim.bo[M._buf].modifiable = true
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.bo[M._buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M._buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    -- Trailing padding is stripped from each line (see _layout), so a mark on
    -- the last cell can reach past the line end. Clamp to the real byte length.
    local len = #(lines[m.row + 1] or "")
    local col = math.min(m.col, len)
    local end_col = math.min(m.end_col, len)
    if end_col > col then
      vim.api.nvim_buf_set_extmark(M._buf, ns, m.row, col, { end_col = end_col, hl_group = m.hl })
    end
  end

  local height = #lines
  local bordered = M._border ~= "none" and M._border ~= ""
  local cfg = {
    relative = "editor",
    anchor = "SW",
    row = vim.o.lines - vim.o.cmdheight - (bordered and 1 or 0),
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = M._border,
    zindex = 200,
    noautocmd = true,
  }
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    cfg.noautocmd = nil
    vim.api.nvim_win_set_config(M._win, cfg)
  else
    M._win = vim.api.nvim_open_win(M._buf, false, cfg)
    vim.wo[M._win].winblend = 0
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

return M
