#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Anthony Urena
#
# check.sh — Structural and quality checks for custom Emacs extensions
#
# Across all source files (.el, .sh):
#   1. SPDX         — inserts license and copyright headers if absent
#
# For each extension under lisp/extensions/<name>/:
#   2. Structure    — enforces directory layout, required files, and code conventions
#   3. Format       — rewrites indentation in place via indent-region
#   4. Byte-compile — catches undefined vars, wrong-arity calls, syntax errors
#   5. Checkdoc     — validates docstring presence and style
#   6. ERT          — runs the paired test suite
#
# Exits non-zero if any check fails.
# Idempotent: safe to run multiple times.

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${CYAN}▶${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
fail()    { echo -e "${RED}✗${RESET} $*"; }
section() { echo -e "\n${BOLD}── $* ──${RESET}"; }

# ── Locate Emacs ───────────────────────────────────────────────────────────────
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi
EMACS_BIN="${HOMEBREW_PREFIX}/bin/emacs"
[[ -x "$EMACS_BIN" ]] || EMACS_BIN="$(command -v emacs 2>/dev/null)" \
  || { echo -e "${RED}✗ ERROR:${RESET} emacs not found on PATH" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_DIR="${SCRIPT_DIR}/lisp/extensions"

errors=0
# Extensions that pass structural checks — populated in section 2.
valid_extensions=()

# ── 1. SPDX headers ───────────────────────────────────────────────────────────
section "SPDX"

# Collect all .el and .sh source files in the repo, excluding vendored paths.
SOURCE_FILES=()
while IFS= read -r f; do
  SOURCE_FILES+=("$f")
done < <(find "$SCRIPT_DIR" \( -name '*.el' -o -name '*.sh' \) \
    ! -path '*/vendor/*' \
    ! -path '*/.git/*' \
    2>/dev/null | sort)

spdx_insert_el() {
  local file="$1"
  if ! grep -qE "^;; SPDX-License-Identifier:" "$file"; then
    sed -i '' "1a\\
;; SPDX-License-Identifier: GPL-3.0-or-later
" "$file"
    log "$(basename "$file"): inserted SPDX-License-Identifier"
  fi
  if ! grep -qE "^;; SPDX-FileCopyrightText:" "$file"; then
    sed -i '' "/^;; SPDX-License-Identifier:/a\\
;; SPDX-FileCopyrightText: 2026 Anthony Urena
" "$file"
    log "$(basename "$file"): inserted SPDX-FileCopyrightText"
  fi
}

spdx_insert_sh() {
  local file="$1"
  if ! grep -qE "^# SPDX-License-Identifier:" "$file"; then
    sed -i '' "1a\\
# SPDX-License-Identifier: GPL-3.0-or-later
" "$file"
    log "$(basename "$file"): inserted SPDX-License-Identifier"
  fi
  if ! grep -qE "^# SPDX-FileCopyrightText:" "$file"; then
    sed -i '' "/^# SPDX-License-Identifier:/a\\
# SPDX-FileCopyrightText: 2026 Anthony Urena
" "$file"
    log "$(basename "$file"): inserted SPDX-FileCopyrightText"
  fi
}

for src in "${SOURCE_FILES[@]}"; do
  case "$src" in
    *.el) spdx_insert_el "$src" ;;
    *.sh) spdx_insert_sh "$src" ;;
  esac
  ok "$(basename "$src")"
done

# ── 2. Structure ───────────────────────────────────────────────────────────────
section "Structure"

if [[ ! -d "$EXTENSIONS_DIR" ]]; then
  warn "No extensions directory found at ${EXTENSIONS_DIR}"
  exit 0
fi

# Flat .el files directly in lisp/extensions/ are not allowed.
# Every extension must live in its own named subdirectory.
while IFS= read -r -d '' flat_el; do
  fail "Flat extension file not allowed: $(basename "$flat_el")"
  log  "  Move to lisp/extensions/$(basename "${flat_el%.el}")/${flat_el##*/}"
  (( errors++ ))
done < <(find "$EXTENSIONS_DIR" -maxdepth 1 -name '*.el' -print0 2>/dev/null)

# Validate each subdirectory as an extension.
while IFS= read -r -d '' ext_dir; do
  name="$(basename "$ext_dir")"

  ext_el="${ext_dir}/${name}.el"
  test_el="${ext_dir}/tests/${name}-test.el"
  ok_flag=true

  # Required: <name>.el
  if [[ ! -f "$ext_el" ]]; then
    fail "${name}: missing ${name}.el"
    (( errors++ ))
    ok_flag=false
  fi

  # Required: tests/<name>-test.el
  if [[ ! -f "$test_el" ]]; then
    fail "${name}: missing tests/${name}-test.el"
    (( errors++ ))
    ok_flag=false
  fi

  if [[ "$ok_flag" == false ]]; then
    continue
  fi

  ext_errors=0

  # Lexical binding must be declared on the first line.
  first_line="$(head -1 "$ext_el")"
  if [[ "$first_line" != *"lexical-binding: t"* ]]; then
    fail "${name}: missing ';;; -*- lexical-binding: t; -*-' on line 1"
    (( errors++ ))
    (( ext_errors++ ))
  fi

  # Must end with (provide '<name>).
  if ! grep -qE "^\(provide '$name\)" "$ext_el"; then
    fail "${name}: missing (provide '${name}) form"
    (( errors++ ))
    (( ext_errors++ ))
  fi

  # Must define M-x <name>-install.
  if ! grep -qE "^\(defun ${name}-install" "$ext_el"; then
    fail "${name}: missing (defun ${name}-install ...)"
    (( errors++ ))
    (( ext_errors++ ))
  fi

  # If package.json is present, bun.lockb must also be present.
  if [[ -f "${ext_dir}/package.json" && ! -f "${ext_dir}/bun.lockb" ]]; then
    fail "${name}: package.json present but bun.lockb is missing (commit the lockfile)"
    (( errors++ ))
    (( ext_errors++ ))
  fi

  if [[ $ext_errors -eq 0 ]]; then
    ok "${name}"
    valid_extensions+=( "$name" )
  fi

done < <(find "$EXTENSIONS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | sort -z)

if [[ ${#valid_extensions[@]} -eq 0 ]]; then
  warn "No structurally valid extensions to check"
  if [[ $errors -gt 0 ]]; then
    echo -e "\n${RED}${errors} check(s) failed.${RESET}\n"
    exit 1
  fi
  exit 0
fi

# ── 3. Format ─────────────────────────────────────────────────────────────────
section "Format"

for name in "${valid_extensions[@]}"; do
  el="${EXTENSIONS_DIR}/${name}/${name}.el"
  "$EMACS_BIN" --batch \
    --eval "(progn
              (find-file \"${el}\")
              (indent-region (point-min) (point-max))
              (save-buffer))" \
    2>/dev/null
  ok "${name}"
done

# ── 4. Byte-compile ───────────────────────────────────────────────────────────
section "Byte-compile"

for name in "${valid_extensions[@]}"; do
  el="${EXTENSIONS_DIR}/${name}/${name}.el"
  output=$("$EMACS_BIN" --batch -f batch-byte-compile "$el" 2>&1)
  elc="${el%.el}.elc"
  [[ -f "$elc" ]] && rm "$elc"
  if echo "$output" | grep -qiE "^.*(error|warning):"; then
    fail "${name}"
    echo "$output" | grep -iE "^.*(error|warning):" | sed 's/^/    /'
    (( errors++ ))
  else
    ok "${name}"
  fi
done

# ── 5. Checkdoc ───────────────────────────────────────────────────────────────
section "Checkdoc"

for name in "${valid_extensions[@]}"; do
  el="${EXTENSIONS_DIR}/${name}/${name}.el"
  output=$("$EMACS_BIN" --batch \
    --eval "(checkdoc-file \"${el}\")" 2>&1)
  if [[ -n "$output" ]]; then
    fail "${name}"
    echo "$output" | sed 's/^/    /'
    (( errors++ ))
  else
    ok "${name}"
  fi
done

# ── 6. ERT tests ──────────────────────────────────────────────────────────────
section "ERT"

for name in "${valid_extensions[@]}"; do
  ext_dir="${EXTENSIONS_DIR}/${name}"
  ext_el="${ext_dir}/${name}.el"
  test_el="${ext_dir}/tests/${name}-test.el"
  output=$("$EMACS_BIN" --batch \
    --eval "(add-to-list 'load-path \"${ext_dir}\")" \
    -l "$ext_el" \
    -l "$test_el" \
    -f ert-run-tests-batch-and-exit 2>&1)
  if echo "$output" | grep -qE "^(FAILED|passed:.*failed:[^0])"; then
    fail "${name}"
    echo "$output" | tail -5 | sed 's/^/    /'
    (( errors++ ))
  else
    ok "${name}"
  fi
done

# ── Result ────────────────────────────────────────────────────────────────────
section "Result"

if [[ $errors -eq 0 ]]; then
  echo -e "\n${GREEN}All checks passed.${RESET}\n"
else
  echo -e "\n${RED}${errors} check(s) failed.${RESET}\n"
  exit 1
fi
