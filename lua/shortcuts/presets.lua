-- Curated annotations for Neovim's *built-in* shortcuts.
--
-- These are metadata only: enabling a preset calls annotate() (never
-- vim.keymap.set), so the live built-in mappings are untouched. The payoff is
-- that `:ShortcutsSearch` and `:Shortcuts <prefix>` turn into a browsable,
-- fuzzy-searchable reference of native shortcuts you already have.
--
-- Each set lists { "<lhs>", "description" } pairs and the prefix root(s) those
-- shortcuts hang off, so the popup/search can group them.

local M = {}

-- The g-prefix: jumps, case operators, formatting, display-line motions, …
local g = {
  root = { "g" },
  items = {
    { "gg", "Go to first line" },
    { "gd", "Go to local declaration" },
    { "gD", "Go to global declaration" },
    { "gi", "Insert at last insert position" },
    { "gI", "Insert at column 1" },
    { "gj", "Down (display line)" },
    { "gk", "Up (display line)" },
    { "g0", "Start of display line" },
    { "g$", "End of display line" },
    { "g^", "First non-blank of display line" },
    { "gm", "Middle of screen line" },
    { "gM", "Middle of text line" },
    { "g_", "Last non-blank of line" },
    { "ge", "Backward to end of word" },
    { "gE", "Backward to end of WORD" },
    { "gn", "Select next search match" },
    { "gN", "Select previous search match" },
    { "gp", "Paste, cursor after" },
    { "gP", "Paste before, cursor after" },
    { "gu", "Lowercase {motion}" },
    { "gU", "Uppercase {motion}" },
    { "g~", "Swap case {motion}" },
    { "gq", "Format {motion}" },
    { "gw", "Format {motion}, keep cursor" },
    { "gv", "Reselect last visual selection" },
    { "gJ", "Join lines (no space)" },
    { "gf", "Edit file under cursor" },
    { "gF", "Edit file under cursor at line" },
    { "ga", "Show char code (:ascii)" },
    { "g8", "Show UTF-8 bytes of char" },
    { "g;", "Go to older change" },
    { "g,", "Go to newer change" },
    { "g&", "Repeat last :s on all lines" },
    { "gt", "Next tab" },
    { "gT", "Previous tab" },
    { "g<C-g>", "Cursor/word/line counts" },
  },
}

-- The z-prefix: folds, scroll positioning, spelling.
local z = {
  root = { "z" },
  items = {
    -- folds
    { "zf", "Create fold {motion}" },
    { "zd", "Delete fold" },
    { "zD", "Delete folds recursively" },
    { "zE", "Eliminate all folds" },
    { "zo", "Open fold" },
    { "zO", "Open folds recursively" },
    { "zc", "Close fold" },
    { "zC", "Close folds recursively" },
    { "za", "Toggle fold" },
    { "zA", "Toggle folds recursively" },
    { "zr", "Open one fold level (all)" },
    { "zR", "Open all folds" },
    { "zm", "Close one fold level (all)" },
    { "zM", "Close all folds" },
    { "zv", "View cursor line (open folds)" },
    { "zx", "Update folds, view cursor" },
    -- scroll positioning
    { "zz", "Center cursor line" },
    { "zt", "Cursor line to top" },
    { "zb", "Cursor line to bottom" },
    { "z<CR>", "Top + first non-blank" },
    { "z.", "Center + first non-blank" },
    { "z-", "Bottom + first non-blank" },
    -- horizontal scroll
    { "zh", "Scroll left" },
    { "zl", "Scroll right" },
    { "zH", "Scroll half screen left" },
    { "zL", "Scroll half screen right" },
    { "zs", "Scroll to start of line" },
    { "ze", "Scroll to end of line" },
    -- spelling
    { "zg", "Add word to spellfile (good)" },
    { "zw", "Mark word as wrong" },
    { "zug", "Undo zg for word" },
    { "zuw", "Undo zw for word" },
    { "z=", "Spelling suggestions" },
  },
}

-- Neovim 0.11 built-in LSP defaults: the gr-prefix family plus gO. These are
-- mapped automatically when a language server attaches (see :h lsp-defaults),
-- so most users have them without ever setting them.
local lsp = {
  root = { "g" },
  items = {
    { "grn", "LSP rename" },
    { "gra", "LSP code action" },
    { "grr", "LSP references" },
    { "gri", "LSP implementation" },
    { "grt", "LSP type definition" },
    { "grx", "Run codelens" },
    { "gO", "LSP document symbols" },
  },
}

-- Window management under <C-w>.
local windows = {
  root = { "<C-w>" },
  items = {
    { "<C-w>s", "Split horizontally" },
    { "<C-w>v", "Split vertically" },
    { "<C-w>n", "New window" },
    { "<C-w>q", "Quit window" },
    { "<C-w>c", "Close window" },
    { "<C-w>o", "Close other windows" },
    { "<C-w>d", "Show diagnostics under cursor" },
    { "<C-w>w", "Cycle to next window" },
    { "<C-w>W", "Cycle to previous window" },
    { "<C-w>p", "Go to previous window" },
    { "<C-w>h", "Go to window left" },
    { "<C-w>j", "Go to window below" },
    { "<C-w>k", "Go to window above" },
    { "<C-w>l", "Go to window right" },
    { "<C-w>t", "Go to top-left window" },
    { "<C-w>b", "Go to bottom-right window" },
    { "<C-w>H", "Move window far left" },
    { "<C-w>J", "Move window to bottom" },
    { "<C-w>K", "Move window to top" },
    { "<C-w>L", "Move window far right" },
    { "<C-w>T", "Move window to new tab" },
    { "<C-w>r", "Rotate windows" },
    { "<C-w>x", "Exchange with next window" },
    { "<C-w>=", "Equalize window sizes" },
    { "<C-w>_", "Maximize height" },
    { "<C-w>|", "Maximize width" },
    { "<C-w>+", "Increase height" },
    { "<C-w>-", "Decrease height" },
    { "<C-w>>", "Increase width" },
    { "<C-w><", "Decrease width" },
  },
}

-- Unmatched-paren / section / diff / spell motions under [ and ].
local brackets = {
  root = { "[", "]" },
  items = {
    { "[[", "Previous section" },
    { "]]", "Next section" },
    { "[]", "Previous section end" },
    { "][", "Next section end" },
    { "[{", "Previous unmatched {" },
    { "]}", "Next unmatched }" },
    { "[(", "Previous unmatched (" },
    { "])", "Next unmatched )" },
    { "[m", "Previous method start" },
    { "]m", "Next method start" },
    { "[M", "Previous method end" },
    { "]M", "Next method end" },
    { "[c", "Previous diff change" },
    { "]c", "Next diff change" },
    { "[d", "Previous diagnostic" },
    { "]d", "Next diagnostic" },
    { "[s", "Previous misspelled word" },
    { "]s", "Next misspelled word" },
    { "[z", "Start of open fold" },
    { "]z", "End of open fold" },
    { "[p", "Paste before, adjust indent" },
    { "]p", "Paste after, adjust indent" },
  },
}

M.sets = { g = g, lsp = lsp, z = z, windows = windows, brackets = brackets }

-- Sensible default when `presets = true`.
M.default = { "g", "lsp", "z", "windows" }

-- All available set names.
M.all = { "g", "lsp", "z", "windows", "brackets" }

--- Resolve the `presets` config value to a clean list of known set names.
--- Accepts: nil/false/{} (none), true (M.default), "all", a single name, or a list.
--- @param spec any
--- @return string[]
function M.resolve(spec)
  if spec == nil or spec == false then
    return {}
  end
  if spec == true then
    return vim.deepcopy(M.default)
  end
  if spec == "all" then
    return vim.deepcopy(M.all)
  end
  if type(spec) == "string" then
    spec = { spec }
  end
  local out, seen = {}, {}
  for _, name in ipairs(spec) do
    if M.sets[name] and not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    elseif not M.sets[name] then
      error("shortcuts.setup: unknown preset '" .. tostring(name) .. "'", 0)
    end
  end
  return out
end

--- Flat annotate() list for the resolved sets.
--- @param names string[] output of M.resolve
--- @return table[] each { lhs, desc, mode = "n" }
function M.annotations(names)
  local out = {}
  for _, name in ipairs(names) do
    for _, pair in ipairs(M.sets[name].items) do
      out[#out + 1] = { lhs = pair[1], desc = pair[2], mode = "n" }
    end
  end
  return out
end

--- Prefix roots for the resolved sets (e.g. {"g","z","<C-w>"}); deduped.
--- @param names string[] output of M.resolve
--- @return string[]
function M.roots(names)
  local out, seen = {}, {}
  for _, name in ipairs(names) do
    for _, root in ipairs(M.sets[name].root) do
      if not seen[root] then
        seen[root] = true
        out[#out + 1] = root
      end
    end
  end
  return out
end

return M
