# shortcuts — Neovim keybinding manager

A standalone, **zero-dependency** Lua plugin for Neovim **0.12+** that registers
keybindings, shows available continuations on input, searches bindings, and
provides a raw-keystroke diagnostic ("what did I just press?").

## Scope

The package owns two clearly separate concerns:

- **Registry** (`registry.lua`) — registered/annotated keys, the source of truth
  for the popup and search.
- **Keylog / panic buffer** (`keylog.lua`) — a verbatim ring of the last N raw
  keystrokes via `vim.on_key`, plus a **macro-recording guard** (`RecordingEnter`)
  and `showcmd`. This diagnoses *accidental/unregistered* input — the original
  motivation ("I hit random keys and it went weird"). `on_key` is safe here
  because it does NO segmentation; it just appends raw keys. Surfaced via
  `:ShortcutsWhat`.

There is **no action-history feature**. Recording *intentional, registered*
actions added little value (you already know your own shortcuts) and forced a
fragile rhs-wrapper + key-length filter. Removing it makes `register()`/
`annotate()` simple and side-effect-free; the keylog covers the real need.

## Core decisions

| Area | Choice | Implication |
|---|---|---|
| Registration | Hybrid | `register()` calls `vim.keymap.set`; `annotate()` adds metadata for existing maps |
| UI | Native, zero deps | Float windows via `nvim_open_win`; fuzzy via `vim.fn.matchfuzzypos` |
| Diagnostic | Raw `on_key` ring | Verbatim, bounded, no segmentation; macro-record guard + `showcmd` |
| Search source | Registered + annotated keys only | Deterministic, closed dataset |

## "Show shortcuts on input" mechanism (Phase 2)

Trigger + state-machine (modeled on `mini.clue`), not a typeahead race:

1. Install a keymap on each registered prefix root (`<leader>`, `g`, …).
2. On trigger, start a timer (`delay`, default `&timeoutlen`); read keys with
   `vim.fn.getcharstr()`.
3. Each key descends the registry trie: branch → redraw popup; leaf → execute
   (callback, or `feedkeys(rhs)`); no match → feed keys back.
4. Popup only appears after the timer fires, so fast typists never see it.

## Module layout

```
shortcuts/
├── plugin/shortcuts.lua          -- commands + load guard
├── lua/shortcuts/
│   ├── init.lua                  -- public API: setup/register/annotate/search/what
│   ├── config.lua                -- defaults + merge
│   ├── keys.lua                  -- keycode normalization + trie-key splitting
│   ├── registry.lua              -- the trie: add / get / node_at / list
│   ├── keylog.lua                -- raw keystroke panic buffer + macro guard
│   ├── trigger.lua               -- (Phase 2) trigger maps + getcharstr state machine
│   ├── ui/popup.lua              -- (Phase 2) float window: columns, highlights
│   ├── ui/search.lua             -- (Phase 3) matchfuzzypos picker over registry
│   └── health.lua                -- :checkhealth shortcuts
└── tests/run.lua                 -- zero-dep headless runner (nvim -l tests/run.lua)
```

## Build phases

- **Phase 0 — Scaffold.** ✅ config, `keys.lua`, health, test runner.
- **Phase 1 — Registry.** ✅ trie, `register()`/`annotate()` (metadata only).
- **Phase 1.5 — Keylog.** ✅ raw `on_key` ring, macro-recording guard, `showcmd`,
  `:ShortcutsWhat`.
- **Phase 2 — Popup + triggers.** ✅ trigger keymaps on leader/localleader roots,
  `getcharstr` state machine, float popup (columns + highlights), `:Shortcuts`.
  MVP scope: leader-rooted triggers only by default (no builtin shadowing, no
  replay-recursion). Non-leader roots (`g`, `z`, …) are opt-in via
  `config.triggers`. Deferred to a Phase 2.x: safe replay for builtin-prefix
  roots, counts/registers passthrough, prefix nodes that are *also* a mapping.
- **Phase 3 — Search.** ✅ live `matchfuzzypos` picker over the registry with
  positional highlights; selecting feeds the lhs so the real mapping executes.
  `:ShortcutsSearch` / `require("shortcuts").search()`.
- **Phase 4 — Polish.** ✅ mode-aware search execution (declines gracefully for
  visual/insert maps fired from the wrong mode), config validation (fail fast on
  bad `setup`), `:help shortcuts` + README.
  Still deferred: buffer-local map tracking, safe replay for non-leader
  (`g`/`z`) triggers, keylog "effect correlation", perf pass.

## Public API

```lua
require("shortcuts").setup({ delay = 200 })

require("shortcuts").register({
  { "<leader>f", group = "Find" },
  { "<leader>ff", function() end, desc = "Find files" },
  { "<leader>fg", ":Grep<cr>",    desc = "Live grep" },
})

require("shortcuts").annotate({ gd = "Go to definition" })  -- metadata for an existing map

require("shortcuts").search()     -- Phase 3
require("shortcuts").what()       -- recent raw keystrokes (:ShortcutsWhat)
```

## Known limitations (by design)

- Search covers only registered/annotated keys, not built-in motions.
- The keylog is a verbatim ring; it shows *what* was pressed, not a full semantic
  decode of every builtin (common surprise keys are annotated, the rest are raw).
- Buffer-local map annotation lands in Phase 4.
