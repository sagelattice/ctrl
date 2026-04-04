# ctrl — Emacs Dotfiles

Emacs configuration targeting GNU Emacs 30+ on macOS, with native compilation and tree-sitter enabled.

## Source of Truth

This repository is the canonical source of truth for all dotfiles. Files live here and are symlinked out to their expected system locations by `install-emacs.sh`. Never edit files at their symlink destinations — always edit the source here.

Third-party assets (e.g. vendored JavaScript libraries) are managed as **git submodules** pinned to a specific release tag, committed under `vendor/`. The install script initialises submodules and references their contents directly — no build toolchain or runtime downloads required.

## Repository Layout

```
ctrl/
├── early-init.el           # Pre-GUI: GC tuning, native comp flags, UI suppression
├── init.el                 # Main config: packages, editing, Clojure/CIDER, Elisp dev
├── install-emacs.sh        # Hermetic macOS installer (Homebrew + Emacs 30 from source)
├── lisp/extensions/        # Custom .el extensions (auto-loaded on startup)
│   └── tests/
└── vendor/                 # Git submodules for third-party assets
```

`install-emacs.sh` symlinks these files into `~/.config/emacs/` — do not edit them there directly. Edit the source files here; the symlinks keep the live config in sync.

Expected live config layout:

```
~/.config/emacs/
├── early-init.el        → symlink to this repo
├── init.el              → symlink to this repo
├── lisp/extensions/     → custom .el files (add new features here)
│   └── tests/
├── backups/             # version-controlled backups (gitignored)
├── auto-saves/          # autosave files (gitignored)
└── custom.el            # M-x customize output (gitignored)
```

## Installation

```bash
./install-emacs.sh
```

Idempotent. Installs Xcode CLT, Homebrew, `libgccjit`, `tree-sitter`, builds Emacs 30 from source, compiles tree-sitter grammars, creates the config scaffold, and symlinks this repo into `~/.config/emacs/`.

## Package Stack

| Layer | Package | Purpose |
|---|---|---|
| Package manager | `use-package` | Declarative package config |
| Completion UI | `vertico` + `orderless` + `marginalia` | Minibuffer completion |
| In-buffer completion | `corfu` | Popup completion |
| Git | `magit` (`C-x g`) | Git UI |
| Structural editing | `paredit` | Balanced parens for Lisps |
| Visual | `rainbow-delimiters` | Paren depth coloring |
| Clojure | `clojure-mode` + `cider` | Clojure/ClojureScript dev |
| Elisp dev | `highlight-defined` + `eros` | Symbol highlighting, inline eval |
| Syntax checking | `flycheck` | On-the-fly linting |
| Keybinding help | `which-key` | Show key completions after prefix |

Archives: GNU ELPA (priority 10) > NonGNU ELPA (8) > MELPA (5).

## Tree-Sitter Grammars

Configured languages: clojure, python, javascript, typescript, tsx, json, css, bash, toml, yaml, markdown.

Grammars are compiled by `install-emacs.sh`. To install one manually:

```
M-x treesit-install-language-grammar RET <language> RET
```

Mode remapping is active for: python, javascript, json, css, bash/sh.

## Key Bindings

| Key | Command |
|---|---|
| `C-x g` | `magit-status` |
| `C-c C-k` | Load buffer (Clojure and Elisp) |
| `C-c C-e` | Eval expression before point (CIDER) |
| `C-c C-z` | Switch to REPL (CIDER) |
| `C-c C-d d` | Show documentation (CIDER) |
| `C-c M-j` | Jack-in / start REPL (CIDER) |

## Adding Custom Extensions

Extensions follow the architecture defined in `docs/extension-architecture.md`. Key points:

- Each extension lives in its own subdirectory under `lisp/extensions/<name>/`
- The `.el` file owns all logic including bootstrap (`M-x <name>-install`)
- Paired ERT tests live in `tests/<name>-test.el` within the extension directory
- Run `./check.sh` to auto-format, byte-compile, checkdoc, and run tests across all extensions

## Conventions

- Lexical binding is enabled in all files (`;;; -*- lexical-binding: t; -*-`)
- Backup and autosave files go to `~/.config/emacs/backups/` and `auto-saves/` — never in project dirs
- `custom.el` is gitignored; `M-x customize` output stays separate from hand-written config
- GC threshold: raised to `most-positive-fixnum` during startup, restored to 16MB after
- Native comp optimization level: 2 (balance of speed and compile time)
