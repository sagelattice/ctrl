---
name: doc-check
description: Lightweight documentation consistency check for the ctrl Emacs dotfiles repo. Run this automatically after editing any .md file, check.sh, install.sh, or any .el file. Scoped to changed files only — does not read the full codebase. Use /doc-audit for a comprehensive sweep.
---

# doc-check

Verify consistency between what was just changed and the files most likely to assert
the same facts. Fast and scoped — no full codebase reads, no interview, fix inline.

## Cross-check map

When a file changes, read only its counterparts:

| Changed | Read |
|---|---|
| `CLAUDE.md` | Imported `docs/` files; filesystem vs any layout diagrams |
| `docs/documentation-hygiene.md` | `CLAUDE.md` import line |
| `docs/extension-architecture.md` | `check.sh` header; `lisp/extensions/skel/skel.el` |
| `docs/<name>-spec.md` | `lisp/extensions/<name>/<name>.el` docstrings and behaviour |
| `docs/elisp-pitfalls.md` | `lisp/CLAUDE.md` import |
| `docs/elisp-testing-pitfalls.md` | `lisp/CLAUDE.md` import |
| `docs/elisp-extension-pitfalls.md` | `lisp/extensions/CLAUDE.md` import |
| `check.sh` | Its own header comment vs actual steps in the script body |
| `install.sh` | Its own header comment vs actual steps; `CLAUDE.md` Installation section |
| `lisp/init.el` | Layout comment at top vs actual loader logic |
| `lisp/extensions/<name>/<name>.el` | `docs/<name>-spec.md`; docstrings vs implementation |
| `lisp/CLAUDE.md` | `docs/elisp-pitfalls.md` exists and is current |
| `lisp/extensions/CLAUDE.md` | Both imported docs exist and are current |

## Process

1. Identify which files changed in the current session.
2. For each changed file, read only the counterparts listed above.
3. Check for: stale layout diagrams, duplicate facts, broken references, docstrings
   that contradict implementation, spec/code divergence.
4. Fix any inconsistency immediately and state what was changed.
5. If a fix requires a human decision (e.g. spec vs code disagrees on design intent),
   surface it in one sentence and ask.

No preamble. No summary of what you read. Just fixes and decisions.
