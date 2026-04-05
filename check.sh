#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Anthony Urena
#
# check.sh — Locate Emacs and delegate all check logic to lisp/check.el
#
# Exits non-zero if any check fails.
# Idempotent: safe to run multiple times.

set -euo pipefail

# ── Locate Emacs ───────────────────────────────────────────────────────────────
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi
EMACS_BIN="${HOMEBREW_PREFIX}/bin/emacs"
[[ -x "$EMACS_BIN" ]] || EMACS_BIN="$(command -v emacs 2>/dev/null)" \
  || { echo "ERROR: emacs not found on PATH" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$EMACS_BIN" --batch -l "${SCRIPT_DIR}/lisp/check.el" -f check-run
exit $?
