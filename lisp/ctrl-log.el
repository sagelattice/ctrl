;;; ctrl-log.el --- Shared batch logging for headless scripts -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Shared logging utilities used by bootstrap.el and check.el when running
;; headlessly via emacs --batch.  All output goes to stderr via `message'.
;; `ctrl-log--errors' accumulates failures; callers reset it at the start of a
;; run and inspect it at the end.

;;; Commentary:
;; Load this file explicitly by path before using its symbols:
;;
;;   (load (expand-file-name "ctrl-log" <lisp-dir>) nil t)

;;; Code:

(defvar ctrl-log--errors 0
  "Count of errors accumulated during the current headless run.")

(defun ctrl-log--section (title)
  "Emit a section header for TITLE to stderr."
  (message "\n── %s ──" title))

(defun ctrl-log--ok (fmt &rest args)
  "Emit an ok-status line to stderr using FMT and ARGS."
  (message "  ✓  %s" (apply #'format fmt args)))

(defun ctrl-log--log (fmt &rest args)
  "Emit a progress line to stderr using FMT and ARGS."
  (message "  ▶  %s" (apply #'format fmt args)))

(defun ctrl-log--warn (fmt &rest args)
  "Emit a warning line to stderr using FMT and ARGS."
  (message "  ⚠  %s" (apply #'format fmt args)))

(defun ctrl-log--fail (fmt &rest args)
  "Emit an error line to stderr using FMT and ARGS and increment `ctrl-log--errors'."
  (message "  ✗  %s" (apply #'format fmt args))
  (setq ctrl-log--errors (1+ ctrl-log--errors)))

(provide 'ctrl-log)

;;; ctrl-log.el ends here
