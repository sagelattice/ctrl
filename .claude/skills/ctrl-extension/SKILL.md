---
name: ctrl-extension
description: >
  Design and implement custom Emacs Lisp extensions for the ctrl dotfiles repo,
  or adopt a well-maintained existing package when one exists. Use this skill
  whenever the user wants to add a new capability to their Emacs config — whether
  phrased as "I want an extension that...", "add support for X in Emacs", "build
  me a <thing>-mode", "I need Emacs to do X", or "write an extension for Y".
  Always trigger this skill for any Emacs extension or package adoption request,
  even if the user doesn't say "extension" explicitly.
---

# ctrl-extension

Adds new capabilities to the ctrl Emacs dotfiles repo — either by adopting a
well-maintained existing package or by designing and implementing a custom
extension following the repo's architecture.

Before doing anything, read `docs/extension-architecture.md` for the full
structural contract.  The skeleton at `lisp/extensions/skel/skel.el` is the
canonical starting point for every new extension; it satisfies all constraints
enforced by `check.sh`.

## Workflow

```
Phase 1: Discovery   →  adopt existing package, or proceed
Phase 2: Design      →  write spec doc, or skip if spec exists
Phase 3: Implement   →  copy skeleton, fill in logic, wire everything
Phase 4: Validate    →  run check.sh, up to 3 fix attempts
```

Skip phase 2 if `docs/<name>-spec.md` already exists.
Skip to phase 3 if both the spec and skeleton files already exist.

---

## Phase 1: Discovery

Search for existing Emacs packages before writing any code.

### Search

Use `WebSearch` across MELPA, NonGNU ELPA, GNU ELPA, and GitHub:
- `site:melpa.org <feature keywords>`
- `site:github.com emacs <feature keywords> .el`
- `emacs <feature> package melpa`

### Evaluate each candidate

**Activity — both conditions must hold:**
- Last commit within 3 months
- Average gap between recent commits under 1 month

State failures explicitly.  A package that was active two years ago is not active.

**Security:**
Search the GitHub Advisory Database:
- `site:github.com/advisories <package-name>`
- Check the package's own GitHub Security tab

Any advisory is an automatic disqualifier.  Note the advisory ID.

For any package the user adopts, note that Dependabot will provide ongoing
alerting once it is wired into the repo.

**Quality (supporting context, not decisive):**
- Archived or explicitly unmaintained repo
- MELPA-stable (tagged releases) vs MELPA-only (rolling tip)
- Open/closed issues ratio

### Present findings

| Package | Last commit | Cadence | Advisory | Verdict |
|---|---|---|---|---|
| foo.el | 6 weeks ago | ~2 weeks | None | Recommended |
| bar-mode | 16 months ago | ~6 weeks | None | Stale |
| baz | 2 months ago | ~3 weeks | GHSA-xxxx | Advisory |

If a suitable package exists: show the `use-package` stanza, add it to
`init.el`, and stop.

If nothing suitable exists: proceed to Phase 2.

---

## Phase 2: Design

### Interview

Ask only what the context doesn't already answer — at most:

1. Core capability in one sentence
2. External tools or runtimes required
3. Commands to expose and in which major mode(s)
4. Managed package dependencies (npm/bun packages, versions if known)
5. Output format (SVG, PNG, JSON, plain text, etc.)

Show a draft spec and get explicit confirmation before writing any files.

### Write `docs/<name>-spec.md`

Follow the structure of `docs/mermaid-preview-spec.md` exactly.  Every spec
must contain: Goal, Rationale (comparison table), Constraints, Diagram (Mermaid
flowchart of the runtime path), and a numbered Outline covering the same
sections as the architecture doc.

---

## Phase 3: Implementation

### Start from the skeleton

Copy `lisp/extensions/skel/` to `lisp/extensions/<name>/`.  Rename every
occurrence of `skel` to `<name>` — in file names, symbol names, docstrings,
and the `provide` form.  Then replace the STUB sections with real logic.

The skeleton already satisfies every `check.sh` structural requirement.
Work from it rather than writing from scratch to avoid missing any constraint.

### Implement `<name>.el`

Replace the STUB sections in order:

1. File header — update the one-line description and Usage block
2. `defcustom` — add variables for every configurable path, timeout, and format
3. `<name>-install` — replace the stub body with `shell-command` calls that
   install the system runtime (Homebrew) and managed packages (bun/npm)
4. Core private functions (`<name>--` prefix) — block detection, source
   extraction, subprocess invocation, output handling, overlay management
5. Public commands — replace `<name>-run` and add any additional commands
6. Keybindings — uncomment the `with-eval-after-load` block, set the real mode

### Implement `tests/<name>-test.el`

Replace and expand the skel tests.  Tests must:
- Mock all subprocess calls — the external runtime must not be required
- Cover: content/block detection, source extraction, output parsing, error
  handling, and display/overlay logic

### `package.json` (only if bun/npm deps required)

Pin every dependency to an exact version.  Commit `bun.lockb` alongside it —
`check.sh` enforces this pairing.

### Submodules / vendored assets

If the extension needs third-party assets to be vendored:

1. Identify the upstream repo and exact release tag to pin
2. `git submodule add -b <tag> <url> vendor/<asset-name>`
3. Commit the submodule reference
4. Reference only the vendored path from within the `.el` — no network paths
   at runtime

### Wire `install-emacs.sh`

Add a batch Emacs invocation of `M-x <name>-install` in the extension
bootstrapping section of `install-emacs.sh`, following the existing pattern.

---

## Phase 4: Validate

Run `./check.sh`.  It enforces SPDX headers, directory structure, formatting,
byte-compilation, checkdoc, and ERT.

If it fails:
- Read the error precisely
- Make one targeted fix addressing only the reported failure
- Re-run `./check.sh`
- Repeat — maximum **3 attempts total**

After 3 failed attempts, stop and surface the full error output and your
diagnosis to the user.  Do not make speculative changes; one specific fix per
attempt.
