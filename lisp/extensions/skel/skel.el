;;; skel.el --- Skeleton for new extensions -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Canonical starting point for new extensions in this repository.
;; Satisfies every structural constraint enforced by check.sh.
;;
;; To create a new extension:
;;   1. Copy this directory to lisp/extensions/<name>/
;;   2. Rename every occurrence of "skel" to "<name>" throughout both files
;;   3. Replace STUB sections with real logic
;;   4. Run ./check.sh
;;
;; Usage:
;;   M-x skel-install   Install required runtimes and packages (STUB)
;;   M-x skel-run       Run the extension (STUB)

;;; Commentary:
;; This file is the canonical starting point for new extensions in this
;; repository.  It satisfies every structural constraint enforced by check.sh:
;; lexical binding, SPDX headers, a defcustom group, an idempotent install
;; command, user-facing commands with mode-local keybindings, and a provide
;; form.  Replace the STUB sections with real implementations.
;;
;; See docs/extension-architecture.md for the full architecture, including
;; patterns for external binary dependencies and subprocess invocation.

;;; Code:

;; ── Customization ─────────────────────────────────────────────────────────────

(defgroup skel nil
  "Configuration for the skel extension."
  :group 'tools
  :prefix "skel-")

;; STUB: add defcustom entries here for paths, timeouts, output formats, etc.

;; ── Bootstrap ─────────────────────────────────────────────────────────────────

(defun skel-install ()
  "Install system runtimes and managed package dependencies for skel.
This command is idempotent — safe to run multiple times."
  (interactive)
  ;; STUB: replace with shell-command calls to install system runtimes and
  ;; managed packages.  See docs/extension-architecture.md for the pattern.
  (message "skel: installation complete."))

;; ── Commands ──────────────────────────────────────────────────────────────────

(defun skel-run ()
  "Run the skel extension on the current buffer.
STUB: replace this body with the real implementation."
  (interactive)
  (message "skel: ran."))

;; ── Keybindings ───────────────────────────────────────────────────────────────
;;
;; STUB: uncomment and replace <major-mode> with the relevant mode.
;; Never bind keys globally.
;;
;; (with-eval-after-load '<major-mode>
;;   (define-key <major-mode>-map (kbd "C-c C-s r") #'skel-run))

;; ── Provide ───────────────────────────────────────────────────────────────────

(provide 'skel)

;;; skel.el ends here
