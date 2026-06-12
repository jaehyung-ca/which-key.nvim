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
  -- "all"; a name like "g"; or a list, e.g. { "g", "lsp", "z", "windows" }.
  presets = "all",
  -- Raw keystroke "panic buffer": diagnoses unregistered/accidental input.
  keylog = {
    enabled = true,
    max = 50, -- raw keystrokes retained
    notify_recording = true, -- warn when macro recording starts (the classic culprit)
    set_showcmd = true, -- show pending operators/counts live in the corner
  },
  search = {
    -- Float size. A value <= 1 is a fraction of the editor; > 1 is absolute
    -- cells. `height` is a maximum — the window shrinks to fit fewer results.
    -- Width fits the content between `min_width` and `max_width`.
    height = 0.7,
    min_width = 80,
    max_width = 0.9,
  },
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
  check(type(cfg.search) == "table", "`search` must be a table")
  for _, k in ipairs({ "height", "min_width", "max_width" }) do
    check(
      cfg.search[k] == nil or (type(cfg.search[k]) == "number" and cfg.search[k] > 0),
      "`search." .. k .. "` must be a positive number"
    )
  end
  return cfg
end

--- Deep-merge user opts over defaults, then validate.
--- @param user table|nil
--- @return table
function M.extend(user)
  return M.validate(vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user or {}))
end

return M
