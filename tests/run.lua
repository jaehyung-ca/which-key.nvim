-- Zero-dependency test runner. Run from the repo root:
--   nvim -l tests/run.lua
-- Exits non-zero on failure.

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local passed, failed = 0, 0

local function eq(a, b, msg)
  if vim.deep_equal(a, b) then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(("  FAIL: %s\n    expected %s\n    got      %s\n"):format(
      msg or "values equal", vim.inspect(b), vim.inspect(a)))
  end
end

local function ok(cond, msg)
  eq(cond and true or false, true, msg)
end

local function section(name)
  io.write("# " .. name .. "\n")
end

local keys = require("which-key.keys")
local Registry = require("which-key.registry")
local wk = require("which-key")

local function reset()
  wk._state.registry = Registry.new()
end

------------------------------------------------------------------- keys
section("keys")
eq(#keys.split(keys.normalize("<leader>ff")), 3, "leader + ff splits into 3 keys")
eq(#keys.split(keys.normalize("<C-w>h")), 2, "<C-w>h splits into 2 keys")
eq(keys.normalize("<leader>x"), keys.normalize("\\x"), "default leader is backslash")

------------------------------------------------------------------ registry
section("registry")
do
  local r = Registry.new()
  r:add("n", "<leader>ff", { desc = "Find files" })
  r:add("n", "<leader>fg", { desc = "Grep" })
  r:add_group("n", "<leader>f", "Find")
  eq(r:get("n", "<leader>ff").desc, "Find files", "get returns mapping")
  eq(r:get("n", "<leader>fx"), nil, "missing key returns nil")
  local node = r:node_at("n", "<leader>f")
  ok(node ~= nil, "node_at finds the group node")
  eq(node.group, "Find", "group node carries its label")
  eq(#r:list(), 2, "list returns both leaf mappings")
end

------------------------------------------------------------- register()
section("register")
do
  reset()
  _G.__ran = false
  wk.register({ { "<leader>tt", function() _G.__ran = true end, desc = "Test" } })
  eq(wk.registry():get("n", "<leader>tt").desc, "Test", "registered in registry")

  local target = keys.normalize("<leader>tt")
  local cb
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if keys.normalize(m.lhs) == target then
      cb = m.callback
    end
  end
  ok(cb ~= nil, "keymap created with a callback")
  cb()
  ok(_G.__ran, "rhs runs unwrapped (no recording side effects)")
end

------------------------------------------------------------- annotate()
section("annotate")
do
  reset()
  wk.annotate({ gX = "External action" })
  eq(wk.registry():get("n", "gX").desc, "External action", "annotated into registry")
  -- annotate is registry-only: it must NOT create or alter a live mapping.
  local target = keys.normalize("gX")
  local found = false
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if keys.normalize(m.lhs) == target then
      found = true
    end
  end
  ok(not found, "annotate does not touch the live keymap")
end

-------------------------------------------------------------- keylog
section("keylog")
do
  local keylog = require("which-key.keylog")
  -- enabled=false so no real on_key hook is installed during tests.
  keylog.setup({ enabled = false, max = 3, notify_recording = false, set_showcmd = false })
  keylog._capture("a")
  keylog._capture("b")
  eq(#keylog._ring, 2, "captures raw keystrokes")
  keylog._capture("c")
  keylog._capture("d") -- overflows cap of 3
  eq(#keylog._ring, 3, "raw ring respects max")
  eq(keylog._ring[1].key, "b", "oldest raw keystroke evicted first")

  eq(keylog.annotate({ key = "q" }), "macro record/stop", "annotates the macro key")
  eq(keylog.annotate({ key = "j" }), nil, "plain motions get no note")

  keylog._mark("▶ started recording macro @a")
  ok(#keylog.render() >= 1, "render produces lines including markers")
  keylog.clear()
  eq(keylog._ring, {}, "clear empties the ring")
end

-------------------------------------------------------------- popup
section("popup")
do
  local popup = require("which-key.ui.popup")
  local root = Registry.new()
  root:add("n", "<leader>ff", { desc = "Find files" })
  root:add("n", "<leader>fg", { desc = "Live grep" })
  root:add_group("n", "<leader>f", "Find")
  local fnode = root:node_at("n", "<leader>f")

  local items = popup.contents(fnode)
  eq(#items, 2, "contents lists both leaves under the prefix")
  eq(items[1].keydisp, "f", "first continuation key is 'f'")
  eq(items[1].desc, "Find files", "leaf desc carried through")

  -- a group child renders with a '+' prefix
  root:add("n", "<leader>gx", { desc = "x" })
  root:add_group("n", "<leader>g", "Git")
  local lnode = root:node_at("n", "<leader>")
  local citems = popup.contents(lnode)
  local git
  for _, it in ipairs(citems) do
    if it.keydisp == "g" then
      git = it
    end
  end
  ok(git ~= nil and git.is_group, "group node flagged as group")
  eq(git.desc, "+Git", "group desc uses + prefix")

  local lines, marks = popup._layout(items)
  ok(#lines >= 1, "layout produces at least one line")
  ok(#marks >= 3, "layout emits key/sep/desc highlight marks")

  -- Regression: uneven desc widths pack into multiple columns; trailing padding
  -- is stripped per line, so open() must clamp marks or set_extmark errors with
  -- "Invalid 'end_col': out of range".
  local wide = Registry.new()
  for i, d in ipairs({ "x", "a much longer description", "mid", "y", "z" }) do
    wide:add("n", "<leader>" .. string.char(96 + i), { desc = d })
  end
  local wnode = wide:node_at("n", "<leader>")
  ok(pcall(popup.open, wnode), "open() does not crash on uneven, padded rows")
  popup.close()
end

------------------------------------------------------------- triggers
section("triggers")
do
  local trigger = require("which-key.trigger")
  reset()
  wk.setup({ delay = 0 })
  wk.register({ { "<leader>tt", function() end, desc = "Test" } })
  local leader = vim.g.mapleader or "\\"
  ok(trigger._installed["n"] and trigger._installed["n"][leader],
    "leader trigger installed once something is registered under it")
  ok(not (trigger._installed["n"] and trigger._installed["n"]["g"]),
    "non-leader root 'g' is NOT triggered by default")
end

-------------------------------------------------------------- search
section("search")
do
  local search = require("which-key.ui.search")
  reset()
  wk.setup({ delay = 0 })
  wk.register({
    { "<leader>ff", function() end, desc = "Find files" },
    { "<leader>fg", function() end, desc = "Live grep" },
    { "<leader>bd", function() end, desc = "Delete buffer" },
  })

  local items = search.items()
  eq(#items, 3, "items() lists every registered mapping")
  local has_desc = false
  for _, it in ipairs(items) do
    if it.text:find("Find files", 1, true) then
      has_desc = true
    end
  end
  ok(has_desc, "searchable text includes the desc")

  local all = search.filter(items, "")
  eq(#all, 3, "empty query returns everything")

  local hits = search.filter(items, "grep")
  ok(#hits >= 1, "fuzzy query returns matches")
  eq(hits[1].item.desc, "Live grep", "best match is the grep entry")
  ok(#hits[1].pos > 0, "matched positions reported for highlighting")

  local files = search.filter(items, "find")
  eq(files[1].item.lhs, "<leader>ff", "matching by description finds the right lhs")
end

--------------------------------------------------------- search exec
section("search-exec")
do
  local search = require("which-key.ui.search")
  ok(search._can_feed("n", "n"), "normal map fires from normal mode")
  ok(not search._can_feed("n", "v"), "normal map does not fire from visual mode")
  ok(search._can_feed("v", "V"), "visual map fires from linewise visual")
  ok(not search._can_feed("v", "n"), "visual map does not fire from normal mode")
  ok(search._can_feed("i", "i"), "insert map fires from insert mode")
end

-------------------------------------------------------------- config
section("config")
do
  local config = require("which-key.config")
  ok(pcall(config.extend, {}), "default config validates")
  ok(pcall(config.extend, { delay = 300, triggers = { "g" } }), "valid overrides pass")
  ok(not pcall(config.extend, { delay = "soon" }), "non-number delay rejected")
  ok(not pcall(config.extend, { keylog = { enabled = "yes", max = 50 } }), "non-boolean keylog.enabled rejected")
  ok(not pcall(config.extend, { keylog = { enabled = true, max = -1 } }), "non-positive keylog.max rejected")
end

------------------------------------------------------------- presets
section("presets")
do
  local presets = require("which-key.presets")

  -- resolve() normalizes the many accepted spellings.
  eq(presets.resolve(nil), {}, "nil resolves to no presets")
  eq(presets.resolve(false), {}, "false resolves to no presets")
  eq(presets.resolve({}), {}, "empty list resolves to no presets")
  eq(presets.resolve(true), presets.default, "true resolves to the default set")
  eq(presets.resolve("all"), presets.all, "'all' resolves to every set")
  eq(presets.resolve("g"), { "g" }, "a single name resolves to a one-element list")
  eq(presets.resolve({ "g", "g", "z" }), { "g", "z" }, "duplicates are dropped")
  ok(not pcall(presets.resolve, "nope"), "unknown preset name is rejected")

  -- annotations()/roots() reflect the chosen sets.
  local ann = presets.annotations({ "g" })
  ok(#ann > 0, "g preset yields annotations")
  eq(ann[1].mode, "n", "annotations default to normal mode")
  eq(presets.roots({ "windows" }), { "<C-w>" }, "windows preset roots on <C-w>")
  eq(presets.roots({ "brackets" }), { "[", "]" }, "brackets preset roots on [ and ]")

  -- setup({ presets = ... }) annotates the built-ins into the registry,
  -- and they are searchable — without creating any live keymap.
  reset()
  wk.setup({ delay = 0, presets = { "g" } })
  eq(wk.registry():get("n", "gd").desc, "Go to local declaration", "preset annotated into registry")
  local before = vim.fn.maparg("gd", "n")
  ok(before == "" or before == nil, "annotating gd did not create a live mapping")
  local hits = require("which-key.ui.search").filter(require("which-key.ui.search").items(), "declaration")
  ok(#hits >= 1, "preset annotations are fuzzy-searchable")

  -- default setup ships no presets (opt-in).
  reset()
  wk.setup({ delay = 0 })
  eq(wk.registry():get("n", "gd"), nil, "no presets enabled by default")
end

----------------------------------------------------------------- summary
io.write(("\n%d passed, %d failed\n"):format(passed, failed))
if failed > 0 then
  os.exit(1)
end
