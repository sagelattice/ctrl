# ctrl

Emacs dotfiles for GNU Emacs 30+ on macOS, with native compilation and tree-sitter enabled.

## Requirements

- macOS
- Internet access
- sudo rights (for Xcode Command Line Tools only)

## Installation

```bash
./install-emacs.sh
```

Installs Xcode CLT, Homebrew, `libgccjit`, and `tree-sitter`; builds GNU Emacs 30 from
the official Homebrew formula; compiles tree-sitter grammars; and symlinks this repo into
`~/.config/emacs/`. Idempotent — safe to run multiple times.

On first launch, `use-package` installs packages from MELPA. This requires internet access
and takes about 30 seconds.

## Repository Layout

```
ctrl/
├── early-init.el        # Pre-GUI: GC tuning, native comp flags, UI suppression
├── init.el              # Main config: packages, editing, Clojure/CIDER, Elisp dev
├── install-emacs.sh     # Hermetic macOS installer
├── check.sh             # Structural and quality checks for extensions
├── lisp/extensions/     # Custom extensions (each in its own subdirectory)
├── docs/                # Internal design documents
└── vendor/              # Third-party assets as pinned git submodules
```

Files are symlinked into `~/.config/emacs/` by `install-emacs.sh`. Never edit files at
their symlink destinations — always edit the source here.

## Custom Extensions

Each extension lives under `lisp/extensions/<name>/` and owns its full install and
dependency story in a single `.el` file. The bootstrap command `M-x <name>-install` is
idempotent. See [`docs/extension-architecture.md`](docs/extension-architecture.md) for the
full specification.

## Checks

```bash
./check.sh
```

Enforces structural and quality norms across all extensions:

| Step | What it does |
|---|---|
| SPDX | Inserts license and copyright headers into source files if absent |
| Structure | Enforces directory layout, required files, and code conventions |
| Format | Rewrites indentation in place via `indent-region` |
| Byte-compile | Catches undefined variables, wrong-arity calls, syntax errors |
| Checkdoc | Validates docstring presence and style |
| ERT | Runs each extension's paired test suite |

Exits non-zero on any failure. All checks use tools built into Emacs — no external
linters or formatters.

## License

Copyright (C) 2026 Anthony Urena  
Licensed under the GNU General Public License v3.0 or later — see [LICENSE](LICENSE).
