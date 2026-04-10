---
name: doc-audit
description: Audit the ctrl Emacs dotfiles repository for documentation drift. Use this skill when something feels out of sync, after a significant implementation phase, or before committing a batch of changes. Triggers on phrases like "audit the docs", "check for drift", "is everything in sync", or "review the documentation".
---

# Documentation Audit

Systematically cross-reference all documentation against the codebase and surface
drift for human decision, one finding at a time.

## What to check

### 1. Filesystem layouts
Every directory tree diagram in any `.md` file — verify each listed path exists and
flag unlisted paths that should be documented.

### 2. Duplicate facts
The same fact stated in more than one place. Identify the canonical location; the
copy should become a reference per `docs/documentation-hygiene.md`.

### 3. Broken references
Every filename, path, and cross-reference in `.md` files — does the target exist?

### 4. Script headers vs reality
For self-documenting scripts (`check.sh`, `install.sh`): compare the header's
stated steps/installs against what the code actually does. The script header is the
source of truth; other docs must reference it, not copy it.

### 5. Docstrings vs implementation
For `.el` files: check that interactive command docstrings match what the function
actually does — output format, behaviour, side effects.

### 6. Spec vs implementation
For each `docs/<name>-spec.md`, check `lisp/extensions/<name>/<name>.el` against the
spec's stated constraints and behaviour. Flag deviations for human decision: is the
spec stale, or is the code wrong?

## Process

**Step 1 — Read everything first.** Build a complete picture before reporting
anything. Do not surface findings piecemeal as you read.

Always read:
- `CLAUDE.md`, `lisp/CLAUDE.md`, `lisp/extensions/CLAUDE.md`
- All files under `docs/`
- `check.sh`, `install.sh`
- `lisp/init.el`
- All `SKILL.md` files under `.claude/skills/`

For each extension found under `lisp/extensions/`:
- `<name>/<name>.el`
- `docs/<name>-spec.md` (if present)

**Step 2 — Present findings one at a time.** For each finding, show:
- What the documentation says
- What the code or filesystem actually shows
- Which should be the source of truth

Ask the user to decide before moving on.

**Step 3 — Fix on confirmation.** Apply the edit immediately when the user confirms.
Do not batch fixes.

**Step 4 — Propose pitfall entries last.** If a finding reveals a recurring class of
error not already in `docs/elisp-pitfalls.md` or `docs/elisp-extension-pitfalls.md`,
propose adding it after all findings are resolved.
