-- Configuration defaults and merge.

local M = {}

M.defaults = {
  -- ms before the popup appears (Phase 2). Falls back to &timeoutlen when nil.
  delay = nil,
  win = {
    border = "rounded",
    position = "bottom", -- "bottom" | "cursor"
  },
  sort = "key", -- "key" | "desc"
  triggers = "auto", -- "auto" derives prefix roots from registered keys
  -- Built-in shortcut annotations (see presets.lua). Metadata only — never
  -- creates maps. nil/false/{} = none; true = a sensible default set;
  -- "all"; a name like "g"; or a list, e.g. { "g", "z", "windows" }.
  presets = {},
  -- Raw keystroke "panic buffer": diagnoses unregistered/accidental input.
  keylog = {
    enabled = true,
    max = 50, -- raw keystrokes retained
    notify_recording = true, -- warn when macro recording starts (the classic culprit)
    set_showcmd = true, -- show pending operators/counts live in the corner
  },
  search = {},
}

--- Validate a resolved config; raises a clear error on misuse.
--- @param cfg table
--- @return table cfg
function M.validate(cfg)
  local function check(cond, msg)
    if not cond then
      error("which-key.setup: " .. msg, 0)
    end
  end
  check(cfg.delay == nil or type(cfg.delay) == "number", "`delay` must be a number or nil")
  check(type(cfg.sort) == "string", "`sort` must be a string")
  check(type(cfg.triggers) == "string" or vim.islist(cfg.triggers), '`triggers` must be "auto" or a list')
  check(
    cfg.presets == nil
      or type(cfg.presets) == "boolean"
      or type(cfg.presets) == "string"
      or type(cfg.presets) == "table",
    "`presets` must be a boolean, string, or list"
  )
  check(type(cfg.win) == "table", "`win` must be a table")
  check(type(cfg.keylog) == "table", "`keylog` must be a table")
  check(type(cfg.keylog.enabled) == "boolean", "`keylog.enabled` must be a boolean")
  check(type(cfg.keylog.max) == "number" and cfg.keylog.max > 0, "`keylog.max` must be a positive number")
  return cfg
end

--- Deep-merge user opts over defaults, then validate.
--- @param user table|nil
--- @return table
function M.extend(user)
  return M.validate(vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user or {}))
end

return M
