-- Load guard + user commands.

if vim.g.loaded_which_key then
  return
end
vim.g.loaded_which_key = true

if vim.fn.has("nvim-0.12") ~= 1 then
  vim.notify("which-key requires Neovim 0.12+", vim.log.levels.ERROR)
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

vim.api.nvim_create_user_command("WhichKey", function(opts)
  local prefix = opts.args ~= "" and opts.args or nil
  require("which-key").show(prefix)
end, { nargs = "?", desc = "which-key: open the popup for a prefix" })

vim.api.nvim_create_user_command("WhichKeySearch", function()
  require("which-key").search()
end, { desc = "which-key: fuzzy search bindings" })

vim.api.nvim_create_user_command("WhichKeyWhat", function()
  -- "What did I just press?" — raw recent keystrokes, annotated.
  show(require("which-key").what())
end, { desc = "which-key: show recent raw keystrokes" })
