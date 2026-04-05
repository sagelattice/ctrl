# ctrl — Emacs Dotfiles

Emacs configuration targeting GNU Emacs 30+ on macOS, with tree-sitter enabled.

## Source of Truth

This repository is the canonical source of truth for all dotfiles. Files live here and are symlinked out to their expected system locations by `install-emacs.sh`. Never edit files at their symlink destinations — always edit the source here.

Third-party assets (e.g. vendored JavaScript libraries) are managed as **git submodules** pinned to a specific release tag, committed under `vendor/`. The install script initialises submodules and references their contents directly — no build toolchain or runtime downloads required.

## Repository Layout

```
ctrl/
├── early-init.el           # Pre-GUI: GC tuning, UI suppression
├── init.el                 # Main config: packages, editing, Clojure/CIDER, Elisp dev
├── install-emacs.sh        # Hermetic macOS installer (Homebrew + Emacs 30)
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

Idempotent. Installs Xcode CLT, Homebrew, `tree-sitter`, and the Emacs 30 Homebrew formula (pre-built bottle), compiles tree-sitter grammars, creates the config scaffold, and symlinks this repo into `~/.config/emacs/`.

**Note:** Native compilation (`libgccjit`) is not available with the standard Homebrew `emacs` formula. The formula does not declare `libgccjit` as a dependency, so Homebrew's sandboxed build environment never links against it regardless of whether it is installed on the system. Native compilation requires either `emacs-plus` (third-party tap) or a manual build from source.

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

## Development Process

- Shell is for installing Emacs itself (Homebrew, build toolchain, tree-sitter grammars).  Everything beyond that — extension discovery, loading, configuration — belongs in Emacs Lisp.  Resist the pull to reach for shell when Elisp will do.
- All system configuration (symlinks, directory scaffold, extension bootstrap) must go through `install-emacs.sh`.  Never apply configuration changes with ad-hoc shell commands — the script is the deterministic, idempotent record of system state.
- Each dependency has exactly one canonical installation site.  Emacs build dependencies (tree-sitter, etc.) are installed in `install-emacs.sh`.  Extension runtime dependencies (language runtimes, managed packages) are installed in that extension's `M-x <name>-install`.  Never install the same dependency in two places.
- Extensions that require Emacs built-in capabilities must assert those requirements as `display-warning` calls at load time — not inside the install function.  The install function only installs what it owns.
- When a coding error causes `./check.sh` to fail, record it in the "Emacs Lisp Pitfalls" section below so it is not reproduced in future extensions.

## Emacs Lisp Pitfalls (check.sh enforced)

Two classes of error reliably surface during `check.sh` and must be avoided:

**Byte-compile: free variable warnings for mode maps**

`with-eval-after-load` defers execution but does not suppress byte-compilation of
the body. Referencing a mode map symbol directly (e.g. `markdown-mode-map`) causes
a free-variable warning because the compiler has not loaded the package. Use
`(symbol-value 'markdown-mode-map)` instead:

```elisp
;; Wrong — free variable warning at compile time:
(with-eval-after-load 'markdown-mode
  (define-key markdown-mode-map ...))

;; Correct:
(with-eval-after-load 'markdown-mode
  (define-key (symbol-value 'markdown-mode-map) ...))
```

**Checkdoc: message strings must start with a capital letter**

`checkdoc` enforces that strings passed to `message`, `user-error`, `error`, and
similar functions begin with a capital letter. Prefixes like `"my-pkg: something"`
fail; use `"My-pkg: something"` or restructure the message.

**Extension-relative paths must be captured at load time**

`load-file-name` is only non-nil during the `load` call itself.  Inside function
bodies — called interactively or via `--eval` after loading — it is nil.  Any
path relative to the extension directory must be captured at the top level using
a `defconst`, evaluated while the file is being loaded:

```elisp
;; Wrong — load-file-name is nil when the function is later called:
(defun my-ext-install ()
  (let ((dir (file-name-directory (or load-file-name buffer-file-name ""))))
    (shell-command (format "cd %s && bun install" dir))))

;; Correct — capture the directory once, at load time:
(defconst my-ext--dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Directory containing my-ext.el.")

(defun my-ext-install ()
  (shell-command (format "cd %s && bun install"
                         (shell-quote-argument my-ext--dir))))
```
