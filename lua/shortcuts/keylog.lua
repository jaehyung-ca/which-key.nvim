-- Raw keystroke "panic buffer" — the diagnostic for *unregistered* input.
--
-- This passively records the last N raw keystrokes via vim.on_key. It does NO
-- segmentation or execution — just a verbatim ring — so it's safe despite using
-- on_key. Plus a macro-recording guard, the single most common cause of "I
-- pressed something and it went weird".

local M = {}

-- Annotations for builtin keys that commonly cause surprise.
local BUILTIN_NOTES = {
  ["q"] = "macro record/stop",
  ["R"] = "enter Replace mode",
  ["<C-a>"] = "increment number",
  ["<C-x>"] = "decrement number",
  ["d"] = "operator: delete",
  ["c"] = "operator: change",
  ["y"] = "operator: yank",
  ["="] = "operator: reindent",
  ["<"] = "operator: dedent",
  [">"] = "operator: indent",
  ["."] = "repeat last change",
  ["u"] = "undo",
  ["<C-r>"] = "redo",
  ["<C-w>"] = "window prefix",
}

M.cfg = { enabled = true, max = 50, notify_recording = true, set_showcmd = true }
M._ring = {}
M._ns = nil
M._on = false

--- Low-level append (also the unit-test entry point).
--- @param rawkey string raw bytes from on_key
function M._capture(rawkey)
  if rawkey == nil or rawkey == "" then
    return
  end
  local r = M._ring
  r[#r + 1] = {
    t = os.time(),
    mode = vim.fn.mode(),
    key = vim.fn.keytrans(rawkey),
    rec = vim.fn.reg_recording(),
  }
  local overflow = #r - (M.cfg.max or 50)
  for _ = 1, overflow do
    table.remove(r, 1)
  end
end

--- Insert a synthetic marker line (e.g. recording start/stop).
function M._mark(note)
  M._ring[#M._ring + 1] = { t = os.time(), note = note }
  local overflow = #M._ring - (M.cfg.max or 50)
  for _ = 1, overflow do
    table.remove(M._ring, 1)
  end
end

function M.enable()
  if M._on then
    return
  end
  M._ns = M._ns or vim.api.nvim_create_namespace("shortcuts-keylog")
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= "") and typed or key
    M._capture(k)
  end, M._ns)
  M._on = true
end

function M.disable()
  if M._ns then
    vim.on_key(nil, M._ns)
  end
  M._on = false
end

function M.clear()
  M._ring = {}
end

--- @param cfg table|nil keylog sub-config
function M.setup(cfg)
  if cfg then
    M.cfg = cfg
  end
  M._ring = {}

  if M.cfg.set_showcmd then
    vim.o.showcmd = true
  end

  local group = vim.api.nvim_create_augroup("shortcuts-keylog", { clear = true })
  if M.cfg.notify_recording then
    vim.api.nvim_create_autocmd("RecordingEnter", {
      group = group,
      callback = function()
        local reg = vim.fn.reg_recording()
        M._mark("▶ started recording macro @" .. reg)
        vim.notify("▶ recording macro @" .. reg .. " — press q to stop", vim.log.levels.WARN)
      end,
    })
    vim.api.nvim_create_autocmd("RecordingLeave", {
      group = group,
      callback = function()
        M._mark("■ stopped recording macro @" .. vim.fn.reg_recording())
      end,
    })
  end

  if M.cfg.enabled then
    M.enable()
  else
    M.disable()
  end
end

--- Best-effort annotation for one captured key.
--- @return string|nil
function M.annotate(entry)
  return BUILTIN_NOTES[entry.key]
end

--- Render the ring to display lines for :ShortcutsWhat.
--- @return string[]
function M.render()
  if #M._ring == 0 then
    return { "(no keystrokes captured)" }
  end
  local lines = {}
  for _, e in ipairs(M._ring) do
    local stamp = os.date("%H:%M:%S", e.t)
    if e.note then
      lines[#lines + 1] = ("%s  %s"):format(stamp, e.note)
    else
      local note = M.annotate(e)
      local tail = note or (e.rec ~= "" and ("captured into @" .. e.rec) or "")
      lines[#lines + 1] = ("%s  %-3s %-12s %s"):format(stamp, e.mode, e.key, tail)
    end
  end
  return lines
end

return M
