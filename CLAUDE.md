# ctrl — Emacs Dotfiles

Emacs configuration targeting GNU Emacs 30+ on macOS, with tree-sitter enabled.

## Source of Truth

This repository is the canonical source of truth for all dotfiles. Files live here and are symlinked out to their expected system locations by `install.sh`. Never edit files at their symlink destinations — always edit the source here.

## Repository Layout

```
ctrl/
├── install.sh              # Setup entrypoint: assert Emacs 30+ present, run bootstrap.el
├── check.sh                # Locate Emacs and delegate to lisp/check.el
└── lisp/
    ├── early-init.el       # Pre-GUI: GC tuning, UI suppression
    ├── init.el             # Main config: packages, editing, Clojure/CIDER, Elisp dev
    ├── grammars.el         # Canonical tree-sitter grammar source list
    ├── bootstrap.el        # Headless config scaffold + extension bootstrap (batch)
    ├── bootstrap-test.el   # ERT tests for bootstrap.el
    ├── check.el            # Headless quality checks: SPDX, structure, format, ERT (batch)
    ├── check-test.el       # ERT tests for check.el
    └── extensions/         # Custom .el extensions (auto-loaded on startup)
        └── <name>/
            ├── <name>.el
            └── tests/
                └── <name>-test.el
```

`install.sh` symlinks these files into `user-emacs-directory` — do not edit them there directly. Edit the source files here; the symlinks keep the live config in sync.

Expected live config layout (XDG default):

```
~/.config/emacs/
├── early-init.el        → symlink to lisp/early-init.el
├── init.el              → symlink to lisp/init.el
├── lisp/                → symlink to lisp/ (entire directory)
│   └── extensions/      # custom .el files (add new features here)
├── backups/             # version-controlled backups (gitignored)
├── auto-saves/          # autosave files (gitignored)
└── custom.el            # M-x customize output (gitignored)
```

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

Grammars are compiled by `bootstrap.el` during setup. To install one manually:

```
M-x treesit-install-language-grammar RET <language> RET
```

Mode remapping is active for: python, javascript, json, css, bash/sh.

## Adding Custom Extensions

Extensions follow the architecture defined in `docs/extension-architecture.md`. Key points:

- Each extension lives in its own subdirectory under `lisp/extensions/<name>/`
- The `.el` file owns all logic including bootstrap (`M-x <name>-install`)
- Paired ERT tests live in `tests/<name>-test.el` within the extension directory
- Run `./check.sh` to validate all extensions (check logic lives in `lisp/check.el`)

## Conventions

- Lexical binding is enabled in all files (`;;; -*- lexical-binding: t; -*-`)
- Backup and autosave files go to `~/.config/emacs/backups/` and `auto-saves/` — never in project dirs
- `custom.el` is gitignored; `M-x customize` output stays separate from hand-written config
- GC threshold: raised to `most-positive-fixnum` during startup, restored to 16MB after

@docs/documentation-hygiene.md

## Running Checks and Tests

```bash
./check.sh
```

This is the single entry point for all quality checks and unit tests. Run it after every change. It covers: SPDX header insertion, structural validation, formatting, byte-compilation, checkdoc, and ERT tests for all extensions plus `bootstrap.el` and `check.el`. Exits non-zero on any failure.

## Naming Conventions

- Follow standard Elisp convention: prefix all symbols with the file/package name, using a single dash for public symbols and double dash for private ones (`bootstrap--lisp-dir`, `check--run-spdx`).  Shared modules use the project name as prefix: `ctrl-log--ok`, not `log--ok`.

## Development Process

- System-level prerequisites (Xcode CLT, Homebrew, tree-sitter, Emacs itself) are documented requirements.  `bootstrap.el` asserts they are present; `install.sh` asserts Emacs is present.  Neither installs them.
- Shell is for asserting Emacs is present and invoking `bootstrap.el`.  Everything beyond that — config scaffold, extension setup, grammar compilation — belongs in Emacs Lisp.  Resist the pull to reach for shell when Elisp will do.
- All configuration setup must go through `install.sh` → `bootstrap.el`.  Never apply configuration changes with ad-hoc shell commands — the script is the deterministic, idempotent record of system state.
- Each dependency has exactly one canonical location.  System prerequisites are documented in the Installation section and asserted in `bootstrap.el`.  Extension runtime dependencies (external binaries, language runtimes) are asserted in `M-x <name>-install`.  Elisp package dependencies are declared via `use-package` or `Package-Requires` and installed by Emacs on first launch.
- Extensions that require Emacs built-in capabilities must assert those requirements as `display-warning` calls at load time — not inside the install function.  The install function only installs what it owns.
- When a coding error causes `./check.sh` to fail, or a bug surfaces in a live session, record it in `docs/elisp-pitfalls.md` (general Elisp) or `docs/elisp-extension-pitfalls.md` (extension-specific) so it is not reproduced in future extensions.
