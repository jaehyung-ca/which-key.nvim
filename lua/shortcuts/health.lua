-- :checkhealth shortcuts

local M = {}

function M.check()
  local h = vim.health
  h.start("shortcuts")

  if vim.fn.has("nvim-0.12") == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error("Neovim 0.12+ required")
  end

  if vim.g.mapleader then
    h.ok("mapleader is set")
  else
    h.warn("mapleader is not set; <leader> maps resolve to '\\'")
  end

  local wk = require("shortcuts")
  if wk._state.config then
    h.ok("setup() has run")
  else
    h.info("setup() not called yet (defaults in effect)")
  end

  local n = #wk.registry():list()
  h.info(("%d registered/annotated mapping(s)"):format(n))

  local keylog = require("shortcuts.keylog")
  if keylog._on then
    h.ok(("keylog active (%d keystroke(s) buffered)"):format(#keylog._ring))
  else
    h.info("keylog inactive (enable via setup{ keylog = { enabled = true } })")
  end

  local trigger = require("shortcuts.trigger")
  local n = 0
  for _, byrole in pairs(trigger._installed) do
    for _ in pairs(byrole) do
      n = n + 1
    end
  end
  h.info(("%d popup trigger(s) installed"):format(n))
end

return M
