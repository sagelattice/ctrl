---
name: ctrl-extension
description: >
  Choose this skill whenever a user wants to add a new capability to their ctrl
  Emacs configuration — anything Emacs doesn't currently do or have installed.
  This includes adopting a package (vterm, org-roam, etc.), building a custom
  Emacs Lisp extension, or integrating an external tool into Emacs. The defining
  signal is that the user wants something *new* rather than adjusting something
  already present. Trigger on phrasings like "add X", "install X", "I want Emacs
  to do X", "how do I get X in Emacs", "it would be nice to have X", or
  "integrate X into my setup". Skip for configuring existing packages, fixing
  bugs in code already installed, or tasks unrelated to Emacs package adoption.
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

## Emacs Rebuild Assessment

Before running `check.sh`, classify every change made in Phase 3 as either
**reload-only** or **rebuild-required**. The distinction matters because the
wrong assumption leaves the user's environment broken with no clear next step.

### Reload-only (restart Emacs)

Changes that are pure Elisp or managed-package changes:
- Edits to `.el` files only
- Changes to `package.json` / `bun.lock` (bun/npm deps)
- Adding or removing keybindings, commands, defcustoms

The user can pick up these changes by restarting Emacs (or `M-x load-file`).

### Rebuild-required (run `install-emacs.sh` → rebuild Emacs)

Any change that adds a **Homebrew library that Emacs links against at compile
time** requires a full Emacs rebuild from source. Common signals:

- A new `brew install <lib>` was added to `install-emacs.sh` in the
  dependencies section (step 3, before the Emacs build step)
- The extension checks `(image-type-available-p ...)`, `(featurep 'native-compile)`,
  `(treesit-available-p)`, or any other Emacs built-in capability at load time
- The extension emits a `display-warning` directing the user to `install-emacs.sh`
  with a `brew reinstall emacs --build-from-source` instruction

Examples of rebuild-triggering deps: `librsvg` (SVG), `libgccjit` (native comp),
`tree-sitter` (structural parsing), `libgif`, `libjpeg`, `imagemagick`.

### What to tell the user

When a rebuild is required, say so **explicitly** at the end of Phase 3 and
again after Phase 4 passes. Do not leave the user in a broken state without
a clear recovery path. The message should be:

> This change added `<lib>` as a build-time dependency. Your current Emacs
> build does not include it. Run `./install-emacs.sh` — it is idempotent and
> will install the dependency then rebuild Emacs from source automatically.
> Until the rebuild completes, the extension will emit a load-time warning and
> the affected capability will be unavailable.

**Invoke `./install-emacs.sh` on behalf of the user when possible.** The script
is idempotent — safe to run at any time. If you have shell access, run it
rather than just telling the user to run it. This closes the loop and avoids
leaving the environment in a broken state.

The extension's load-time `display-warning` is the in-Emacs signal; this
message is the human signal delivered at the moment the code is written.

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
