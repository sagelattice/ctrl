#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Anthony Urena
# install.sh — Hermetic macOS installer (Homebrew + Emacs 30)
#
# Installs GNU Emacs from the official Homebrew core formula (unpatched GNU
# source). Native compilation and tree-sitter are enabled by default in the
# Homebrew formula when the required libraries are present.
#
# Installs:
#   - Xcode Command Line Tools (if absent)
#   - Homebrew (if absent)
#   - tree-sitter
#   - GNU Emacs 30 (official Homebrew formula, pre-built bottle)
#   - Config scaffold, symlinks, extensions, and grammars (via lisp/bootstrap.el)
#
# Idempotent: safe to run multiple times.
# Requires: macOS, internet access, sudo rights (for Xcode CLT only).

set -euo pipefail

# ── Pinned versions ────────────────────────────────────────────────────────────
EMACS_MIN_VERSION="30.0"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${CYAN}▶${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
die()     { echo -e "${RED}✗ ERROR:${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──${RESET}"; }

# ── Platform guard ─────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

EMACS_BIN="${HOMEBREW_PREFIX}/bin/emacs"

# ── 1. Xcode Command Line Tools ────────────────────────────────────────────────
section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  ok "Already installed at $(xcode-select -p)"
else
  log "Triggering Xcode CLT installer — complete the GUI prompt, then press Enter here."
  xcode-select --install 2>/dev/null || true
  read -r -p "Press Enter once the Xcode CLT installation is complete..."
  xcode-select -p &>/dev/null || die "Xcode CLT still not detected. Re-run after installation."
  ok "Xcode CLT installed"
fi

# ── 2. Homebrew ────────────────────────────────────────────────────────────────
section "Homebrew"

if command -v brew &>/dev/null; then
  ok "Already installed ($(brew --version | head -1))"
else
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installed"
fi

eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

# ── 3. Dependencies ───────────────────────────────────────────────────────────
section "Dependencies (tree-sitter)"

# tree-sitter: required for structural parsing (Emacs links against libtree-sitter).
# Declared as a dependency in the Homebrew emacs formula.
for dep in tree-sitter; do
  if brew list --formula 2>/dev/null | grep -q "^${dep}$"; then
    ok "${dep} already installed"
  else
    log "Installing ${dep}..."
    brew install "${dep}"
    ok "${dep} installed"
  fi
done

# ── 4. GNU Emacs (official Homebrew formula) ───────────────────────────────────
section "GNU Emacs (official Homebrew formula)"

# The Homebrew core `emacs` formula installs from a pre-built bottle signed by
# Homebrew CI.  tree-sitter is a declared formula dependency and is included in
# the bottle.  No build-from-source step is required or performed.

needs_install=false

if brew list --formula 2>/dev/null | grep -q "^emacs$"; then
  if [[ -x "$EMACS_BIN" ]]; then
    installed_ver=$("$EMACS_BIN" --version 2>/dev/null \
                    | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ "$(printf '%s\n' "$EMACS_MIN_VERSION" "$installed_ver" \
             | sort -V | head -1)" == "$EMACS_MIN_VERSION" ]]; then
      ok "Emacs ${installed_ver} already installed"
    else
      warn "Emacs ${installed_ver} is below minimum ${EMACS_MIN_VERSION} — upgrading"
      needs_install=true
    fi
  else
    needs_install=true
  fi
else
  needs_install=true
fi

if [[ "$needs_install" == true ]]; then
  log "Installing GNU Emacs from official Homebrew formula..."
  brew install emacs
  ok "Emacs installed"
fi

# ── 5. Bootstrap (Elisp) ──────────────────────────────────────────────────────
section "Bootstrap (Elisp)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$EMACS_BIN" --batch -l "${SCRIPT_DIR}/lisp/bootstrap.el" -f bootstrap-run

# ── 6. Shell PATH ─────────────────────────────────────────────────────────────
section "Shell PATH"

shell_has_brew=false
for rc in "${HOME}/.zprofile" "${HOME}/.bash_profile" "${HOME}/.profile"; do
  if [[ -f "$rc" ]] && grep -q "brew shellenv" "$rc"; then
    ok "Homebrew shellenv found in ${rc}"
    shell_has_brew=true
    break
  fi
done

if [[ "$shell_has_brew" == false ]]; then
  warn "Homebrew is not in your shell profile."
  warn "Add the following to ~/.zprofile (zsh) or ~/.bash_profile (bash):"
  echo ""
  echo "    eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\""
  echo ""
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Complete"

INSTALLED_VER=$("$EMACS_BIN" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo ""
printf "  %-18s %s\n" "Emacs version:"  "${INSTALLED_VER}"
printf "  %-18s %s\n" "Emacs binary:"   "${EMACS_BIN}"
printf "  %-18s %s\n" "Config dir:"     "${HOME}/.config/emacs"
printf "  %-18s %s\n" "Extensions:"     "${HOME}/.config/emacs/lisp/extensions/"
echo ""
echo -e "${GREEN}Run:${RESET}  emacs"
echo ""
echo "On first launch, use-package will install packages from MELPA."
echo "This requires internet access and takes about 30 seconds."
