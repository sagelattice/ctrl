# Extension Reference Architecture

## Goal

Define a self-contained structure for each custom Emacs extension in this repository.
Each extension owns its full dependency and bootstrap story within its `.el` file,
making it portable and decoupled from the parent project by design — not as a secondary
workflow, but as a natural consequence of where logic lives.

---

## Rationale

| Approach | Single source of truth | Portable by default |
|---|---|---|
| Bootstrap in `install.sh` | No — logic split across shell and Elisp | No — shell script must travel with `.el` |
| Bootstrap in `.el` | Yes — one file owns everything | Yes — `.el` alone is sufficient |

Emacs Lisp is a general-purpose language capable of invoking shell commands. There is no
reason to maintain a separate shell script. The `.el` file is the sole artifact required
to install, configure, and operate an extension.

---

## Constraints

- Each extension lives in its own subdirectory under `lisp/extensions/`
- All bootstrap logic lives in the `.el`; no shell scripts are authored per extension
- The `.el` must not reference any path outside its own directory
- `M-x <name>-install` is the single bootstrap command; it is idempotent
- Runtime dependency checks on load are non-fatal; missing deps surface as warnings
  directing the user to `M-x <name>-install`
- On command invocation with deps absent, a user-facing error directs the user to
  `M-x <name>-install`
- All `.el` files use lexical binding (`;;; -*- lexical-binding: t; -*-`)
- Each extension ends with `(provide 'extension-name)`
- Each extension has a paired ERT test file under `tests/`

---

## Diagram

```mermaid
flowchart TD
    A([bootstrap.el]) --> B[M-x name-install\nfor each extension]
    B --> C[Assert system runtimes present]
    C --> D[Install managed package deps\nvia shell-command]
    D --> E([Extension ready])
```

---

## Outline

### 1. Directory Layout

Each extension is a subdirectory of `lisp/extensions/`. Required files:

```
lisp/extensions/<name>/
├── <name>.el            # the extension; owns all logic including bootstrap
└── tests/
    └── <name>-test.el   # ERT tests
```

Optional files, present only when the extension has managed package dependencies:

```
    ├── package.json     # pinned dependency versions
    └── bun.lock         # committed lockfile for reproducible installs
```

The parent repo keeps internal design documents in `docs/<name>-spec.md`. That file
is not part of the extension.

### 2. Dependency Declaration

Each spec includes a `## Dependencies` section listing:

- **System runtimes** — tools installed at the OS level (e.g. Bun via Homebrew);
  prerequisites asserted by `M-x <name>-install`, not installed by it
- **Managed packages** — versioned dependencies declared in `package.json`, installed
  via `shell-command` inside `M-x <name>-install`; lockfile committed for reproducibility
- **Emacs packages** — declared via `Package-Requires` in the `.el` header

### 3. Bootstrap

`bootstrap.el` calls `M-x <name>-install` for each extension via batch Emacs.
`M-x <name>-install` asserts system runtimes are present and installs managed
package dependencies via `shell-command`. That is the entire install story.

### 4. Runtime Dependency Checks

The `.el` performs two levels of checking:

- **On load** — verify all runtime dependencies are present and emit a
  `display-warning` for each category of missing dependency. Never signal an
  error at load time. Two classes of dependency must be checked:
  - **External binaries** — verify required executables are on `exec-path`
    (e.g. `bun`, `mmdc`). Direct the user to `M-x <name>-install`.
  - **Emacs built-in capabilities** — verify any required Emacs feature is
    compiled in (e.g. `(image-type-available-p 'svg)`, `(featurep 'native-compile)`).
    These are prerequisites of the extension; direct the user to the specific
    Homebrew formula or build option required.
- **On command invocation** — re-check immediately before executing. Signal a
  user-facing error directing the user to `M-x <name>-install` if deps are absent.

### 5. Configuration

Each extension exposes a `defcustom` group named after the extension. At minimum:

- Paths to any required external binaries (default: resolved from `exec-path`)
- Any timeout or output format options relevant to the extension

Defaults must work without manual configuration after running `M-x <name>-install`.

### 6. Linting and Formatting

All quality checks use tools built into Emacs. No third-party linters or formatters
are introduced as dependencies. `check.sh` at the repo root enforces all checks and
exits non-zero on any failure — suitable for CI.

```bash
./check.sh
```

See `lisp/check.el` for the full list of checks it runs.

### 7. Testing

ERT tests live in `tests/<name>-test.el`. Tests cover block detection, output
parsing, error handling, and display logic. Subprocess calls are mocked; tests must
not require the external runtime to be present. Run the suite with:

```bash
emacs --batch -l <name>.el -l tests/<name>-test.el -f ert-run-tests-batch-and-exit
```
