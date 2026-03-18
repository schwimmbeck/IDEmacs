# IDEmacs

Emacs configuration repository for a project-oriented IDE workflow.

This repo is the source of truth for the active Emacs configuration on this
machine. `~/.emacs.d/init.el` is a symlink to this repository's `init.el`.

## Goals

- Keep Emacs usable as a daily IDE for Python-heavy work
- Prefer stable, well-supported packages
- Preserve fast navigation, completion, diagnostics, and project handling
- Support `.ord` files through the separate `syntax_highlighting_ordec` repo

## Active Setup

- Theme: `modus-vivendi`
- Completion: `vertico`, `orderless`, `marginalia`, `consult`, `corfu`, `cape`
- Projects: `projectile`, `treemacs`
- Python IDE features: `lsp-mode`, `lsp-pyright`, `flycheck`, `blacken`
- ORD support: custom `ord-mode` using a local tree-sitter grammar

## Repository Layout

- [init.el](/home/dominik/Work/workspace/IDEmacs/init.el): main Emacs config

## ORD Integration

ORD support is wired from the local shared grammar repository:

- [syntax_highlighting_ordec](/home/dominik/Work/workspace/syntax_highlighting_ordec)
- [tree-sitter-ord](/home/dominik/Work/workspace/syntax_highlighting_ordec/tree-sitter-ord)

The current setup in `init.el`:

- associates `.ord` files with `ord-mode`
- loads the local tree-sitter parser for `ord`
- applies Emacs-specific tree-sitter highlight queries

## Local Machine Notes

The active local file is:

- [init.el](/home/dominik/.emacs.d/init.el)

It should remain a symlink to:

- [init.el](/home/dominik/Work/workspace/IDEmacs/init.el)

## Working Model

When changing Emacs behavior:

1. Edit this repository first.
2. Keep `~/.emacs.d/init.el` as a symlink.
3. Reload Emacs or restart it to test changes.

## Validation

Typical validation commands:

```bash
emacs --batch -Q -l /home/dominik/Work/workspace/IDEmacs/init.el
```

For ORD parser work:

```bash
cd /home/dominik/Work/workspace/syntax_highlighting_ordec/tree-sitter-ord
tree-sitter generate
cc -fPIC -I./src -c src/parser.c src/scanner.c
cc -shared -o libtree-sitter-ord.so parser.o scanner.o
```
