-- Keycode normalization and trie-key splitting.
--
-- "Normalize" turns a human lhs (e.g. "<leader>ff", "<C-w>h") into the raw
-- byte string Neovim actually uses, so two spellings of the same mapping
-- compare equal. "Split" breaks that byte string into individual keystrokes
-- for the registry trie.

local M = {}

--- Replace <leader>/<localleader> then translate termcodes to raw bytes.
--- @param lhs string human-readable left-hand side
--- @return string raw byte string
function M.normalize(lhs)
  local leader = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  -- Function replacements avoid Lua gsub magic-char issues in the replacement.
  local s = lhs:gsub("<[lL]eader>", function() return leader end)
  s = s:gsub("<[lL]ocalleader>", function() return localleader end)
  return vim.api.nvim_replace_termcodes(s, true, true, true)
end

--- Split a normalized byte string into individual keystrokes.
--- K_SPECIAL (0x80) introduces a 3-byte special key; everything else is a
--- single UTF-8 character.
--- @param normalized string output of M.normalize
--- @return string[] list of per-keystroke byte chunks
function M.split(normalized)
  local keys = {}
  local i, n = 1, #normalized
  while i <= n do
    local b = normalized:byte(i)
    if b == 0x80 then
      keys[#keys + 1] = normalized:sub(i, i + 2)
      i = i + 3
    else
      local len = 1
      if b >= 0xF0 then
        len = 4
      elseif b >= 0xE0 then
        len = 3
      elseif b >= 0xC0 then
        len = 2
      end
      keys[#keys + 1] = normalized:sub(i, i + len - 1)
      i = i + len
    end
  end
  return keys
end

return M
