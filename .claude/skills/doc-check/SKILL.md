---
name: doc-check
description: Lightweight documentation consistency check for the ctrl Emacs dotfiles repo. Run this automatically after editing any .md file, check.sh, install.sh, or any .el file. Scoped to changed files only — does not read the full codebase. Use /doc-audit for a comprehensive sweep.
---

# doc-check

Verify consistency between what was just changed and any documentation that references it.
Fast and scoped — no full codebase reads, no interview, fix inline.

## Process

1. **Identify changed files** in the current session.

2. **Run the discovery script** from the repo root:

   ```bash
   emacs --batch \
     -l .claude/skills/doc-check/doc-check.el \
     -f doc-check-run \
     -- <changed-files...>
   ```

   The script searches all `.md` files (excluding `.claude/`) for each filename and
   prints exact file:line references.

3. **Read those locations** and check for drift: stale descriptions, duplicate facts,
   broken references, claims that contradict the current implementation.

4. **Fix immediately.** If a fix requires a human decision (spec vs code disagrees on
   design intent), surface it in one sentence and ask.

No preamble. No summary of what you read. Just fixes and decisions.
