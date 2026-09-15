# IDEmacs

Emacs configuration for a project-oriented IDE workflow, with first-class
support for Python and for the ORD language used by
[ORDeC](https://github.com/tub-msc/ordec).

ORD support is self-contained: the `ord-mode` package is bundled in this
repository (`lisp/ord-mode.el`), and semantic features come from ORDeC's
own language server `ordec-lsp`. The former companion repository
`syntax_highlighting_ordec` is retired; its editor support moved into the
ORDeC repository (`support/editors/`), which covers Sublime Text, VS Code,
JetBrains IDEs, Neovim, and Helix — the Emacs side lives here.

![ORD highlighting in Emacs: ordec's diffpair.ord example in ord-mode with
a running ordec-lsp session](./screenshots/ord-mode-diffpair.png)

## What This Repository Provides

- a modern Emacs setup with completion, search, project navigation, and LSP
- Python support based on `lsp-mode`, `lsp-pyright`, `flycheck`, and `blacken`
- `.ord` support via the bundled `ord-mode` plus the `ordec-lsp` language
  server (diagnostics, completion, navigation, rename, semantic tokens,
  inlay hints)
- an Emacs configuration that can act as the source of truth for `~/.emacs.d`

## Main Components

- Completion: `vertico`, `orderless`, `marginalia`, `consult`, `corfu`, `cape`
- Projects and sidebar: `projectile`, `treemacs`
- Python editing: built-in Python mode, `lsp-mode`, `lsp-pyright`,
  `flycheck`, `blacken`
- ORD editing: bundled `ord-mode` (font-lock layer over Python mode) with
  `ordec-lsp` for everything semantic
- Theme: `modus-vivendi`

## Repository Layout

- [init.el](./init.el): main Emacs config
- [lisp/ord-mode.el](./lisp/ord-mode.el): major mode for `.ord` files

## Setup

### 1. Clone The Repository

```bash
git clone git@github.com:schwimmbeck/IDEmacs.git
cd IDEmacs
```

### 2. Use It As Your Emacs Init

If you want this repository to be your live Emacs config, replace your local
`init.el` with a symlink:

```bash
mv ~/.emacs.d/init.el ~/.emacs.d/init.el.backup
ln -s /absolute/path/to/IDEmacs/init.el ~/.emacs.d/init.el
```

If you do not want to use a symlink, copy `init.el` **and** the `lisp/`
directory (`init.el` looks for `lisp/ord-mode.el` next to itself):

```bash
cp /absolute/path/to/IDEmacs/init.el ~/.emacs.d/init.el
cp -r /absolute/path/to/IDEmacs/lisp ~/.emacs.d/lisp
```

### 3. Start Emacs

The first launch may install missing packages from GNU ELPA / MELPA Stable.

## ORD Setup

Syntax support needs no setup: `.ord` files open in the bundled `ord-mode`
automatically.

Semantic features come from `ordec-lsp`, a stdio language server that ships
with the `ordec` Python package. Install it in the environment of your
ORDeC checkout (see `docs/guides/editor_support.rst` in the ORDeC
repository for details):

```bash
cd /path/to/ordec
.venv/bin/python3 -m pip install -e .
```

When an `.ord` buffer opens, `init.el` looks for the `ordec-lsp` executable
in this order:

1. `.venv/bin/ordec-lsp` inside the current project
2. `.venv/bin/ordec-lsp` inside a local ORDeC checkout — `ORDEC_DIR` if
   set, otherwise a sibling `ordec/` checkout next to IDEmacs
3. `ordec-lsp` on `PATH`

Example sibling layout that works with no configuration:

```text
/path/to/dev/
  IDEmacs/
  ordec/
    .venv/
```

## How The ORD Integration Works

ORD is a superset of Python, and the bundled `ord-mode` follows the design
of ORDeC's other editor packages: it derives from `python-mode` and
maintains only the ORD delta as a regex-based font-lock layer, like the
Sublime Text and VS Code packages do. The layer covers cell and viewgen
declarations, node statements, path/net declarations, the `--` and `!`
operators, SI-suffixed numbers, and `$param` access.

Everything semantic — ORD-aware diagnostics, completion, navigation,
rename across the ORD import graph, hover, semantic token highlighting,
and inferred-type inlay hints — comes from `ordec-lsp`, which `init.el`
registers as an `lsp-mode` client for `ord-mode` buffers (Python buffers
keep using Pyright). Semantic tokens and inlay hints are enabled, so
highlighting depth matches what tree-sitter provides in other editors;
ORDeC's tree-sitter grammar itself (`support/editors/tree-sitter-ord/`)
targets Neovim and Helix and is not needed here.

Python-only tooling is switched off in ORD buffers: `blacken` and the
Python syntax checkers would flag valid ORD constructs, so `ordec-lsp`
owns formatting-free editing and diagnostics there.

## Validation

Tested against GNU Emacs 30.2. Check that the init file loads:

```bash
emacs --batch -Q -l /absolute/path/to/IDEmacs/init.el
```

Check that ORD support is wired up:

```bash
emacs --batch -Q -l /absolute/path/to/IDEmacs/init.el \
  --eval '(princ (format "ord-mode=%S lsp-cmd=%s\n"
                         (fboundp (quote ord-mode))
                         (my/ordec-lsp-command)))'
```

The `ord-mode` package can also be checked on its own, without the full
init:

```bash
emacs --batch -Q -L /absolute/path/to/IDEmacs/lisp \
  -f batch-byte-compile /absolute/path/to/IDEmacs/lisp/ord-mode.el
```

## Notes For External Users

- The config no longer depends on any sibling syntax repository; only the
  optional ORDeC checkout (for `ordec-lsp`) is looked up via `ORDEC_DIR`
  or as a sibling `ordec/` directory.
- If your ORDeC venv predates a move of the checkout, entry points such as
  `ordec-lsp` carry stale interpreter paths; re-run the editable install
  shown above to regenerate them.
- If you want a fully portable setup, the next step would be to publish
  `ord-mode` as its own package — or to contribute it upstream as
  `support/editors/emacs/` in ORDeC alongside the other editor packages.
