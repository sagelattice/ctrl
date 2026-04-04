#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Anthony Urena
# install.sh — Hermetic Emacs installation for macOS
#
# Installs GNU Emacs from the official Homebrew core formula (unpatched GNU
# source). Native compilation and tree-sitter are enabled by default in the
# Homebrew formula when the required libraries are present.
#
# Installs:
#   - Xcode Command Line Tools (if absent)
#   - Homebrew (if absent)
#   - libgccjit + tree-sitter libraries
#   - GNU Emacs 30 (official Homebrew formula, built from source)
#   - Emacs.app symlink in /Applications
#   - Config scaffold at ~/.config/emacs/
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

# ── 3. Native compilation dependencies ────────────────────────────────────────
section "Dependencies (libgccjit, tree-sitter)"

# libgccjit: required for native compilation (Emacs → GCC JIT backend)
# tree-sitter: required for structural parsing (Emacs links against libtree-sitter)
for dep in gcc libgccjit tree-sitter; do
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

# The Homebrew core `emacs` formula builds directly from GNU source tarballs
# from ftp.gnu.org. No third-party taps or patches are involved.
#
# Native compilation and tree-sitter are automatically enabled by the formula
# when libgccjit and tree-sitter are present on the system — which is why we
# install those dependencies first.

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
  log "Installing GNU Emacs from official Homebrew formula (builds from source)..."
  log "This takes 10–20 minutes."
  # LIBRARY_PATH ensures configure finds libgccjit on Apple Silicon where
  # Homebrew libs are outside the default system search path.
  export LIBRARY_PATH="${HOMEBREW_PREFIX}/lib:${LIBRARY_PATH:-}"
  # --build-from-source compiles against our freshly installed libgccjit and
  # tree-sitter rather than using a pre-built bottle that may lack them.
  brew install emacs --build-from-source
  ok "Emacs installed"
fi

# ── 5. Verify build features ──────────────────────────────────────────────────
section "Feature verification"

EMACS_FEATURES=$("$EMACS_BIN" --batch --eval \
  "(princ (format \"%s %s\"
    (if (featurep 'native-compile) \"native-compile:YES\" \"native-compile:NO\")
    (if (treesit-available-p)      \"tree-sitter:YES\"    \"tree-sitter:NO\")))" \
  2>/dev/null)

if echo "$EMACS_FEATURES" | grep -q "native-compile:YES"; then
  ok "Native compilation: active"
else
  warn "Native compilation: NOT active — reinstalling from source with LIBRARY_PATH set..."
  export LIBRARY_PATH="${HOMEBREW_PREFIX}/lib:${LIBRARY_PATH:-}"
  brew reinstall emacs --build-from-source
  ok "Emacs reinstalled"
fi

if echo "$EMACS_FEATURES" | grep -q "tree-sitter:YES"; then
  ok "Tree-sitter: active"
else
  warn "Tree-sitter: NOT active"
  warn "Ensure tree-sitter is installed, then: brew reinstall emacs --build-from-source"
fi

# ── 6. /Applications symlink ──────────────────────────────────────────────────
section "/Applications/Emacs.app"

EMACS_APP_SRC="${HOMEBREW_PREFIX}/opt/emacs/Emacs.app"
EMACS_APP_DST="/Applications/Emacs.app"

if [[ ! -e "$EMACS_APP_SRC" ]]; then
  warn "Emacs.app not found at expected path ${EMACS_APP_SRC} — skipping symlink"
elif [[ -L "$EMACS_APP_DST" && "$(readlink "$EMACS_APP_DST")" == "$EMACS_APP_SRC" ]]; then
  ok "Symlink already correct"
elif [[ -e "$EMACS_APP_DST" ]]; then
  warn "${EMACS_APP_DST} exists but points elsewhere — skipping (remove manually if needed)"
else
  ln -s "$EMACS_APP_SRC" "$EMACS_APP_DST"
  ok "Symlink created: ${EMACS_APP_DST} → ${EMACS_APP_SRC}"
fi

# ── 7. Config scaffold ─────────────────────────────────────────────────────────
section "Config scaffold"

EMACS_CONFIG_DIR="${HOME}/.config/emacs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for dir in \
  "${EMACS_CONFIG_DIR}" \
  "${EMACS_CONFIG_DIR}/lisp/extensions" \
  "${EMACS_CONFIG_DIR}/lisp/extensions/tests" \
  "${EMACS_CONFIG_DIR}/backups" \
  "${EMACS_CONFIG_DIR}/auto-saves"; do
  mkdir -p "$dir"
done
ok "Directory structure ready"

link_file() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    warn "$(basename "$src") not found in script dir — skipping"
    return
  fi
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    ok "$(basename "$dst") already symlinked"
  elif [[ -e "$dst" ]]; then
    warn "$(basename "$dst") exists and is not a symlink — skipping (remove manually to replace)"
  else
    ln -s "$src" "$dst"
    ok "Symlinked $(basename "$dst") → ${src}"
  fi
}

link_file "${SCRIPT_DIR}/early-init.el" "${EMACS_CONFIG_DIR}/early-init.el"
link_file "${SCRIPT_DIR}/init.el"       "${EMACS_CONFIG_DIR}/init.el"

for el in "${SCRIPT_DIR}/lisp/extensions/"*.el; do
  [[ -f "$el" ]] && link_file "$el" \
    "${EMACS_CONFIG_DIR}/lisp/extensions/$(basename "$el")"
done

for el in "${SCRIPT_DIR}/lisp/extensions/tests/"*.el; do
  [[ -f "$el" ]] && link_file "$el" \
    "${EMACS_CONFIG_DIR}/lisp/extensions/tests/$(basename "$el")"
done

if [[ ! -f "${EMACS_CONFIG_DIR}/.gitignore" ]]; then
  cat > "${EMACS_CONFIG_DIR}/.gitignore" <<'EOF'
eln-cache/
tree-sitter/
backups/
auto-saves/
custom.el
cider-repl-history
*.elc
*~
\#*\#
.\#*
.DS_Store
EOF
  ok ".gitignore written"
fi

if [[ ! -d "${EMACS_CONFIG_DIR}/.git" ]]; then
  git -C "${EMACS_CONFIG_DIR}" init -q
  git -C "${EMACS_CONFIG_DIR}" add .
  git -C "${EMACS_CONFIG_DIR}" commit -q -m "Initial Emacs config scaffold"
  ok "Git repo initialized at ${EMACS_CONFIG_DIR}"
else
  ok "Git repo already present"
fi

# ── 8. Tree-sitter language grammars ──────────────────────────────────────────
section "Tree-sitter language grammars"

log "Compiling grammars: clojure, python, javascript, typescript, tsx, json, css, bash, toml, yaml, markdown..."

"$EMACS_BIN" --batch --eval "
(setq treesit-language-source-alist
      '((clojure    \"https://github.com/sogaiu/tree-sitter-clojure\")
        (python     \"https://github.com/tree-sitter/tree-sitter-python\")
        (javascript \"https://github.com/tree-sitter/tree-sitter-javascript\")
        (typescript \"https://github.com/tree-sitter/tree-sitter-typescript\"
                    \"master\" \"typescript/src\")
        (tsx        \"https://github.com/tree-sitter/tree-sitter-typescript\"
                    \"master\" \"tsx/src\")
        (json       \"https://github.com/tree-sitter/tree-sitter-json\")
        (css        \"https://github.com/tree-sitter/tree-sitter-css\")
        (bash       \"https://github.com/tree-sitter/tree-sitter-bash\")
        (toml       \"https://github.com/ikatyang/tree-sitter-toml\")
        (yaml       \"https://github.com/ikatyang/tree-sitter-yaml\")
        (markdown   \"https://github.com/ikatyang/tree-sitter-markdown\")))
(dolist (lang (mapcar #'car treesit-language-source-alist))
  (condition-case err
      (progn
        (treesit-install-language-grammar lang)
        (message \"  ok  %s\" lang))
    (error
      (message \"  ERR %s: %s\" lang (error-message-string err)))))
" 2>&1 | grep -E "^  (ok|ERR)" | sed 's/^  ok /  ✓ /;s/^  ERR /  ✗ /'

ok "Grammar compilation complete"

# ── 9. Shell PATH ─────────────────────────────────────────────────────────────
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

# ── Done ───────────────────────────────────────────────────────────────────────
section "Complete"

INSTALLED_VER=$("$EMACS_BIN" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo ""
printf "  %-18s %s\n" "Emacs version:"  "${INSTALLED_VER}"
printf "  %-18s %s\n" "Emacs binary:"   "${EMACS_BIN}"
printf "  %-18s %s\n" "Emacs.app:"      "${EMACS_APP_DST}"
printf "  %-18s %s\n" "Config dir:"     "${EMACS_CONFIG_DIR}"
printf "  %-18s %s\n" "Extensions:"     "${EMACS_CONFIG_DIR}/lisp/extensions/"
echo ""
echo -e "${GREEN}Run:${RESET}  emacs   or   open /Applications/Emacs.app"
echo ""
echo "On first launch, use-package will install packages from MELPA."
echo "This requires internet access and takes about 30 seconds."
