# ctrl

Emacs dotfiles for GNU Emacs 30+ on macOS, with tree-sitter enabled.

## Requirements

- macOS
- GNU Emacs 30+
- Internet access (for first-launch package download)

## Installation

```bash
./install.sh
```

Asserts GNU Emacs 30+ is installed, then delegates all setup to `lisp/bootstrap.el`:
verifies tree-sitter support, creates the config scaffold, runs extension setup, and
compiles tree-sitter grammars. Idempotent — safe to run multiple times.

On first launch, `use-package` installs packages from MELPA.

## Repository Layout

```
ctrl/
├── install.sh      # macOS setup entrypoint
├── check.sh        # Quality checks
├── lisp/           # Emacs Lisp configuration
│   └── extensions/ # Custom extensions
└── docs/           # Design documents
```

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
| Claude skills | Byte-compiles and checkdocs `.el` files under `.claude/skills/` |
| ERT | Runs `bootstrap-test.el`, `check-test.el`, and each extension's paired test suite |

Exits non-zero on any failure. All checks use tools built into Emacs — no external
linters or formatters.

## License

Copyright (C) 2026 Anthony Urena  
Licensed under the GNU General Public License v3.0 or later — see [LICENSE](LICENSE).
