-- Public API: setup / register / annotate (+ stubs for later phases).

local config = require("which-key.config")
local keylog = require("which-key.keylog")
local popup = require("which-key.ui.popup")
local presets = require("which-key.presets")
local trigger = require("which-key.trigger")
local Registry = require("which-key.registry")

local M = {}

M._state = { config = nil, registry = nil }

-- Lazy init so register()/annotate() work before an explicit setup() call.
local function ensure()
  if not M._state.config then
    M._state.config = config.extend(nil)
  end
  if not M._state.registry then
    M._state.registry = Registry.new()
  end
  return M._state
end

--- @param opts table|nil
function M.setup(opts)
  M._state.config = config.extend(opts)
  M._state.registry = M._state.registry or Registry.new()
  -- Annotate built-in shortcuts (metadata only; does not create maps).
  M.annotate(presets.annotations(presets.resolve(M._state.config.presets)))
  keylog.setup(M._state.config.keylog)
  popup.setup(M._state.config.win)
  trigger.setup(M._state.config)
  return M
end

-- Keymap option keys we forward to vim.keymap.set.
local OPT_KEYS = { "silent", "noremap", "nowait", "expr", "buffer", "remap", "script" }

local function build_opts(item)
  local o = {}
  for _, k in ipairs(OPT_KEYS) do
    if item[k] ~= nil then
      o[k] = item[k]
    end
  end
  if o.noremap == nil and o.remap == nil then
    o.noremap = true
  end
  o.desc = item.desc or item.group
  return o
end

local function as_modes(mode)
  if type(mode) == "table" then
    return mode
  end
  return { mode or "n" }
end

-- Accept a single spec ({ "<lhs>", rhs, ... }) or a list of them.
local function as_list(spec)
  if type(spec[1]) == "string" then
    return { spec }
  end
  return spec
end

--- Register keybindings (creates the maps and records them in the registry).
--- Each item: { "<lhs>" [, rhs], desc=, mode=, group=, <keymap opts> }
--- A group node omits rhs and sets `group = "Label"`.
function M.register(spec)
  local st = ensure()
  for _, item in ipairs(as_list(spec)) do
    local lhs = item[1]
    local rhs = item[2]
    for _, mode in ipairs(as_modes(item.mode)) do
      if item.group ~= nil and rhs == nil then
        st.registry:add_group(mode, lhs, item.group)
      else
        vim.keymap.set(mode, lhs, rhs, build_opts(item))
        st.registry:add(mode, lhs, {
          rhs = rhs,
          desc = item.desc,
          group = item.group,
          remap = item.remap == true,
        })
      end
    end
  end
  trigger.refresh()
  return M
end

-- Normalize annotate() input to a list of { lhs, desc, mode }.
local function annotate_list(spec)
  local out = {}
  if vim.islist(spec) then
    for _, item in ipairs(spec) do
      out[#out + 1] = { lhs = item[1] or item.lhs, desc = item[2] or item.desc, mode = item.mode or "n" }
    end
  else
    for lhs, desc in pairs(spec) do
      out[#out + 1] = { lhs = lhs, desc = desc, mode = "n" }
    end
  end
  return out
end

--- Attach metadata to existing maps so they appear in the popup and search.
--- Registry-only and side-effect-free (does not touch the live mapping).
--- Forms: { gd = "Go to definition" } or { { "gd", "Go to definition", mode = "n" } }
function M.annotate(spec)
  local st = ensure()
  for _, a in ipairs(annotate_list(spec)) do
    st.registry:add(a.mode, a.lhs, { desc = a.desc })
  end
  trigger.refresh()
  return M
end

--- @return table the active registry (for UI/tests)
function M.registry()
  return ensure().registry
end

--- @return table resolved config
function M.config()
  return ensure().config
end

--- Open the popup for a prefix (default: leader). Powers :WhichKey.
--- @param prefix string|nil
--- @param mode string|nil
function M.show(prefix, mode)
  ensure()
  trigger.open(mode or "n", prefix or (vim.g.mapleader or "\\"))
end

--- Recent raw keystrokes (the panic buffer), rendered for display.
--- @return string[]
function M.what()
  return keylog.render()
end

--- Open the live fuzzy search picker over all registered/annotated bindings.
function M.search()
  ensure()
  require("which-key.ui.search").open()
end

return M
