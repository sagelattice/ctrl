#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Anthony Urena
# install.sh — Setup entrypoint: assert Emacs 30+ present, run bootstrap.el
#
# Asserts that GNU Emacs 30+ is installed, then delegates all setup to
# lisp/bootstrap.el, which verifies prerequisites, creates the config scaffold,
# runs extension setup, and compiles tree-sitter grammars.
#
# Idempotent: safe to run multiple times.
# Requires: macOS

set -euo pipefail

# ── Pinned versions ────────────────────────────────────────────────────────────
EMACS_MIN_VERSION="30.0"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'

ok()  { echo -e "${GREEN}✓${RESET} $*"; }
die() { echo -e "${RED}✗ ERROR:${RESET} $*" >&2; exit 1; }

# ── Platform guard ─────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

EMACS_BIN="${HOMEBREW_PREFIX}/bin/emacs"

# ── Assert Emacs 30+ ───────────────────────────────────────────────────────────
[[ -x "$EMACS_BIN" ]] \
  || die "Emacs not found at ${EMACS_BIN} — install with: brew install emacs"

installed_ver=$("$EMACS_BIN" --version 2>/dev/null \
                | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)

[[ "$(printf '%s\n' "$EMACS_MIN_VERSION" "$installed_ver" \
     | sort -V | head -1)" == "$EMACS_MIN_VERSION" ]] \
  || die "Emacs ${installed_ver} is below minimum ${EMACS_MIN_VERSION} — upgrade with: brew install emacs"

ok "Emacs ${installed_ver}"

# ── Bootstrap ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$EMACS_BIN" --batch -l "${SCRIPT_DIR}/lisp/bootstrap.el" -f bootstrap-run
