-- Load guard + user commands.

if vim.g.loaded_shortcuts then
  return
end
vim.g.loaded_shortcuts = true

if vim.fn.has("nvim-0.12") ~= 1 then
  vim.notify("shortcuts requires Neovim 0.12+", vim.log.levels.ERROR)
  return
end

-- Minimal scratch viewer (rich viewers arrive in later phases).
local function show(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.cmd.tabnew()
  vim.api.nvim_win_set_buf(0, buf)
end

vim.api.nvim_create_user_command("Shortcuts", function(opts)
  local prefix = opts.args ~= "" and opts.args or nil
  require("shortcuts").show(prefix)
end, { nargs = "?", desc = "shortcuts: open the popup for a prefix" })

vim.api.nvim_create_user_command("ShortcutsSearch", function()
  require("shortcuts").search()
end, { desc = "shortcuts: fuzzy search bindings" })

vim.api.nvim_create_user_command("ShortcutsWhat", function()
  -- "What did I just press?" — raw recent keystrokes, annotated.
  show(require("shortcuts").what())
end, { desc = "shortcuts: show recent raw keystrokes" })
