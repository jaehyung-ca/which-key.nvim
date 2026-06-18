-- The registry: a per-mode trie of registered/annotated keys.
--
-- Each node:
--   children : { [rawkey] = node }
--   group    : string|nil   -- description for a prefix (group) node
--   mapping  : table|nil    -- present when a full mapping ends at this node
--
-- A mapping carries display + metadata, not execution logic (the keymap itself
-- handles execution; the registry is the source of truth for search and the UI).

local keys = require("shortcuts.keys")

local Registry = {}
Registry.__index = Registry

local function new_node()
  return { children = {} }
end

function Registry.new()
  return setmetatable({ tries = {} }, Registry)
end

function Registry:_root(mode)
  local root = self.tries[mode]
  if not root then
    root = new_node()
    self.tries[mode] = root
  end
  return root
end

--- Walk to (creating) the node for a normalized lhs.
function Registry:_node(mode, lhs)
  local node = self:_root(mode)
  for _, k in ipairs(keys.split(keys.normalize(lhs))) do
    node.children[k] = node.children[k] or new_node()
    node = node.children[k]
  end
  return node
end

--- Add a full mapping.
--- @param mode string
--- @param lhs string
--- @param mapping table { desc?, rhs?, group?, recorded? }
function Registry:add(mode, lhs, mapping)
  local node = self:_node(mode, lhs)
  mapping = mapping or {}
  mapping.lhs = lhs
  mapping.mode = mode
  node.mapping = mapping
  return node
end

--- Add/label a group (prefix) node.
function Registry:add_group(mode, lhs, desc)
  local node = self:_node(mode, lhs)
  node.group = desc
  return node
end

--- Look up the mapping registered exactly at lhs.
--- @return table|nil
function Registry:get(mode, lhs)
  local root = self.tries[mode]
  if not root then
    return nil
  end
  local node = root
  for _, k in ipairs(keys.split(keys.normalize(lhs))) do
    node = node.children[k]
    if not node then
      return nil
    end
  end
  return node.mapping
end

--- Node reached by following a (possibly partial) prefix. Used by the popup to
--- enumerate continuations. Returns nil if the prefix leaves the trie.
--- @return table|nil node
function Registry:node_at(mode, prefix)
  local root = self.tries[mode]
  if not root then
    return nil
  end
  local node = root
  for _, k in ipairs(keys.split(keys.normalize(prefix))) do
    node = node.children[k]
    if not node then
      return nil
    end
  end
  return node
end

--- Flat list of every registered mapping across all modes.
--- @return table[] each { mode, lhs, desc, group, ... }
function Registry:list()
  local out = {}
  local function walk(node)
    if node.mapping then
      out[#out + 1] = node.mapping
    end
    for _, child in pairs(node.children) do
      walk(child)
    end
  end
  for _, root in pairs(self.tries) do
    walk(root)
  end
  return out
end

return Registry
