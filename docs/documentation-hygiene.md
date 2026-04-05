# Documentation Hygiene

Rules for keeping documentation and code in sync across this repository.

---

## Drift is a bug

When code or design changes, update every document that reflects it in the same
commit. A stale doc is as broken as a failing test.

## Self-documenting files are the source of truth

When a file describes itself (e.g. the `check.sh` header, `.el` docstrings),
other documents reference it — they never copy its content. Copies invite
divergence.

## Specs drive implementation, not the reverse

Files in `docs/<name>-spec.md` are the source of truth for an extension's
design. The `.el` must conform to the spec. When a bug or live session reveals
a design flaw — not just an implementation detail — fix the spec first, then
correct the code to match. The spec is never frozen.

## One location per fact

If the same fact appears in two places, one of them will eventually be wrong.
Identify the canonical home and make the other a reference.
