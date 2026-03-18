# IDEmacs

Emacs configuration for a project-oriented IDE workflow, with first-class
support for Python and local support for the ORD language used by ORDeC.

This repository is intended to be usable by external users, but it currently
assumes a local development workflow where custom ORD language support is
developed side-by-side in a separate repository:

- `syntax_highlighting_ordec`

## What This Repository Provides

- a modern Emacs setup with completion, search, project navigation, and LSP
- Python support based on `lsp-mode`, `lsp-pyright`, `flycheck`, and `blacken`
- local `.ord` support using a custom tree-sitter grammar
- an Emacs configuration that can act as the source of truth for `~/.emacs.d`

## Main Components

- Completion: `vertico`, `orderless`, `marginalia`, `consult`, `corfu`, `cape`
- Projects and sidebar: `projectile`, `treemacs`
- Python editing: built-in Python mode / `python-ts-mode`, `lsp-mode`,
  `lsp-pyright`, `flycheck`, `blacken`
- Theme: `modus-vivendi`
- ORD editing: local `ord-mode` package with optional tree-sitter support

## Repository Layout

- [init.el](/home/dominik/Work/workspace/IDEmacs/init.el): main Emacs config

## Setup

### 1. Clone The Repository

```bash
git clone <your-remote-url> IDEmacs
cd IDEmacs
```

### 2. Use It As Your Emacs Init

If you want this repository to be your live Emacs config, replace your local
`init.el` with a symlink:

```bash
mv ~/.emacs.d/init.el ~/.emacs.d/init.el.backup
ln -s /absolute/path/to/IDEmacs/init.el ~/.emacs.d/init.el
```

If you do not want to use a symlink, you can copy the file instead:

```bash
cp /absolute/path/to/IDEmacs/init.el ~/.emacs.d/init.el
```

### 3. Start Emacs

The first launch may install missing packages from GNU ELPA / MELPA Stable.

## ORD Setup

ORD support is not built into Emacs. This config expects a sibling checkout of
the language-support repository:

- [syntax_highlighting_ordec](/home/dominik/Work/workspace/syntax_highlighting_ordec)

The current `init.el` looks for:

- `emacs/ord-mode.el`
- `tree-sitter-ord`
- `vendor/tree-sitter-python`

inside that repository.

### Required Local Layout

Example:

```text
~/Work/workspace/
  IDEmacs/
  syntax_highlighting_ordec/
    emacs/
      ord-mode.el
    tree-sitter-ord/
    vendor/
      tree-sitter-python/
```

### Building The Grammars

ORD:

```bash
cd /path/to/syntax_highlighting_ordec/tree-sitter-ord
tree-sitter generate
cc -fPIC -I./src -c src/parser.c src/scanner.c
cc -shared -o libtree-sitter-ord.so parser.o scanner.o
```

Python:

```bash
cd /path/to/syntax_highlighting_ordec/vendor/tree-sitter-python
tree-sitter generate
cc -fPIC -I./src -c src/parser.c src/scanner.c
cc -shared -o libtree-sitter-python.so parser.o scanner.o
```

After that, restart Emacs or reload the init file.

If those grammars are not built yet, the setup still starts cleanly. In that
case `.ord` files open in `ord-mode` with Python editing behavior plus a small
regex-based ORD keyword layer, but without tree-sitter-driven highlighting.

## How The ORD Integration Works

The current setup uses:

- `ord-mode` from `syntax_highlighting_ordec/emacs/ord-mode.el`
- `python-mode` as the always-available base mode
- the local Python tree-sitter grammar for Python highlighting
- the local ORD tree-sitter grammar for ORD-specific syntax
- Emacs-specific queries from `syntax_highlighting_ordec/tree-sitter-ord`

This approach keeps Python highlighting and editor behavior close to the
built-in Emacs experience while layering ORD-specific syntax on top. When the
grammars are missing, the package falls back to plain Python-based editing
instead of failing during startup.

## Validation

Check that the init file loads:

```bash
emacs --batch -Q -l /absolute/path/to/IDEmacs/init.el
```

Check that Emacs can see both grammars:

```bash
emacs --batch -Q -l /absolute/path/to/IDEmacs/init.el \
  --eval '(princ (format "python=%S ord=%S\n"
                         (treesit-language-available-p (quote python))
                         (treesit-language-available-p (quote ord))))'
```

## Notes For External Users

- The config is optimized for local development, but ORD support now lives in a
  separate `ord-mode.el` file instead of being embedded in `init.el`.
- The current setup still assumes local paths rather than a published Emacs
  package.
- If you want a portable/public setup, the next step would be to publish the
  Emacs integration as its own package and let `init.el` only load it.
