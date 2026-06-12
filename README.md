# which-key

A standalone, **zero-dependency** keybinding manager for **Neovim 0.12+**, written in Lua. It:

- **registers** shortcuts (wrapping `vim.keymap.set`) and tracks their metadata;
- **shows a popup** of available continuations when you start a key sequence;
- provides a **live fuzzy search** over all known bindings;
- keeps a raw-keystroke **"panic buffer"** to diagnose accidental input — *"what did I just press that went weird?"* — including a **macro-recording guard**.

## Requirements

- Neovim **0.12** or newer.
- No external plugins.

## Install

### lazy.nvim

```lua
{
  "jaehyung/which-key.nvim",
  event = "VeryLazy",          -- load before you first reach for a mapping
  opts = {                     -- passed straight to require("which-key").setup()
    delay = 200,               -- ms before the popup appears
  },
}
```

`opts` makes lazy.nvim call `setup()` for you. If you prefer to call it yourself, drop `opts` and use a `config` function:

```lua
{
  "jaehyung/which-key.nvim",
  event = "VeryLazy",
  config = function()
    local wk = require("which-key")
    wk.setup({ delay = 200 })
    wk.register({
      { "<leader>f",  group = "Find" },
      { "<leader>ff", function() vim.cmd("buffers") end, desc = "Buffers" },
    })
  end,
}
```

### Native (built-in packages, no plugin manager)

Neovim loads anything under a `pack/*/start/` directory automatically (`:help packages`). Clone the repo there:

```sh
git clone https://github.com/jaehyung/which-key.nvim \
  "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/pack/plugins/start/which-key"
```

Then in your `init.lua`:

```lua
require("which-key").setup({ delay = 200 })
```

Generate the help tags once so `:help which-key` works:

```vim
:helptags ALL
```

### Manual / local checkout

If the code already lives on disk (e.g. `~/src/which-key`), just add it to your `runtimepath` and call `setup()`:

```lua
vim.opt.runtimepath:append("~/src/which-key")
require("which-key").setup({ delay = 200 })
```

## Usage

```lua
local wk = require("which-key")
wk.setup({ delay = 200 })

wk.register({
  { "<leader>f",  group = "Find" },
  { "<leader>ff", function() vim.cmd("buffers") end, desc = "Buffers" },
  { "<leader>fg", ":Grep<cr>", desc = "Live grep" },
})

-- label maps created elsewhere (metadata only, doesn't touch the map)
wk.annotate({ gd = "Go to definition" })
```

Press `<leader>` and pause → the popup appears. Keep typing to descend; a complete binding runs. Fast typists never see it — the popup only shows after `delay` ms of hesitation.

## Commands

| Command | Description |
|---|---|
| `:WhichKey [prefix]` | Open the popup for a prefix (default leader) |
| `:WhichKeySearch` | Live fuzzy search over all bindings |
| `:WhichKeyWhat` | Show recent raw keystrokes (the panic buffer) |

## Why a separate "panic buffer"?

The action a key triggers and the *raw key you pressed* are different problems. Reviewing registered actions tells you about shortcuts you set up on purpose; it can't explain a stray keypress, because that key was never registered. So which-key records every keystroke verbatim via `vim.on_key` (no interpretation, just a bounded ring) and warns the instant `q` starts a macro recording — the most common "it suddenly went weird" cause.

## Configuration

Defaults (see `:help which-key-config`):

```lua
require("which-key").setup({
  delay = nil,          -- ms before popup; nil falls back to &timeoutlen
  win = { border = "rounded", position = "bottom" },
  sort = "key",
  triggers = "auto",    -- "auto" = leader/localleader; or a list, e.g. { "g", "z" }
  presets = {},         -- annotate built-in shortcuts; see "Built-in presets"
  keylog = {
    enabled = true,
    max = 50,                -- raw keystrokes retained
    notify_recording = true, -- warn when a macro recording starts
    set_showcmd = true,      -- show pending operators/counts in the corner
  },
  search = {                 -- :WhichKeySearch float size
    height = 0.7,            -- max rows: fraction of the editor (<=1) or absolute (>1)
    min_width = 80,          -- floor on width, in columns
    max_width = 0.9,         -- width cap: fraction (<=1) or absolute (>1)
  },
})
```

The search float is sized to the editor by default and scrolls to keep the
selected entry visible. Numbers `<= 1` are read as a fraction of the editor,
`> 1` as absolute cells; `height` is a ceiling (the window shrinks to fit a
short result list), and the width fits the content between `min_width` and
`max_width`. For a compact, fixed picker:

```lua
require("which-key").setup({
  search = { height = 12, min_width = 50, max_width = 80 },
})
```

### Built-in presets

Out of the box which-key only knows the bindings *you* register. The `presets`
option ships curated **annotations for Neovim's built-in shortcuts** so they
become a browsable, fuzzy-searchable reference — without you writing them out.

```lua
require("which-key").setup({
  presets = { "g", "z", "windows" },  -- annotate built-in shortcuts
})
```

| Value | Meaning |
|---|---|
| `{}` / `false` | none (default) |
| `true` | a sensible default set: `g`, `z`, `windows` |
| `"all"` | every set below |
| `{ "g", "z", "windows", "brackets" }` | pick exactly the sets you want |

| Set | Covers |
|---|---|
| `g` | `gg`, `gd`, `gi`, `gu`/`gU`, `gq`, `gv`, display-line motions, change list, … |
| `z` | folds (`zf`/`zo`/`zR`/`zM`…), scroll positioning (`zz`/`zt`/`zb`), spelling (`zg`/`z=`) |
| `windows` | window management under `<C-w>` (`s`, `v`, `h/j/k/l`, `=`, `H/J/K/L`, …) |
| `brackets` | `[`/`]` motions: unmatched parens, sections, methods, diffs, spell |

Browse or search them:

```vim
:WhichKey g        " menu of built-in g-shortcuts
:WhichKey z        " menu of built-in z-shortcuts
:WhichKeySearch    " fuzzy-search every known binding, built-ins included
```

Presets are **metadata only** — they call `annotate()`, never `vim.keymap.set`,
so your native shortcuts are untouched. They do **not** auto-open a popup when
you press `g`/`z`: those prefixes are real built-in commands, and installing a
live trigger on them is deferred (`:help which-key-limitations`). Use the
commands above to surface them on demand, or — if you accept the caveat that
some plugin-mapped g-commands (e.g. `gx`) may not replay — opt a prefix in
explicitly with `triggers = { "g", "z" }`.

Highlight groups (all overridable, see `:help which-key-highlights`):
`WhichKeyKey`, `WhichKeyDesc`, `WhichKeyGroup`, `WhichKeySeparator`,
`WhichKeySearchMatch`, `WhichKeySearchSel`, `WhichKeySearchPrompt`.

## Status

Implemented: registry, `register`/`annotate`, leader popup + triggers, fuzzy search, keylog + macro guard, `:help` docs.

Deferred (see `:help which-key-limitations`): buffer-local map tracking; safe replay for non-leader (`g`/`z`) triggers; visual/insert-mode execution from search.

## Tests

Zero-dependency headless runner:

```sh
nvim -l tests/run.lua
```
