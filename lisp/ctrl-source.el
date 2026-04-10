;;; ctrl-source.el --- Project file discovery -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Shared helpers for locating source and documentation files across the
;; ctrl repository.  Loaded by path in headless scripts:
;;
;;   (load (expand-file-name "ctrl-source" <lisp-dir>) nil t)
;;
;; The central entry point is `ctrl-source--files', which accepts type
;; symbols as selector signals and returns the union of matching files.

;;; Commentary:
;; Type symbols act as mux control signals: each activates a row in
;; `ctrl-source--type-patterns', and the selected extensions are compiled
;; into a single optimised regexp via `regexp-opt' before the directory
;; walk begins.  Emacs lock files (.#*) are excluded by the regexp itself
;; via a leading ^[^.] anchor — no post-filter pass needed.

;;; Code:

(defconst ctrl-source--exclude-re
  "/\\(\\.git\\|node_modules\\|vendor\\)\\(/\\|$\\)"
  "Directories excluded from all source file searches.")

(defconst ctrl-source--type-patterns
  '((el . "el")
    (sh . "sh")
    (md . "md"))
  "Routing table for `ctrl-source--files'.
Each entry maps a type symbol to the bare file extension it selects.")

(defun ctrl-source--compile-pattern (types)
  "Compile TYPE symbols into a single optimised file-match regexp.
Uses `regexp-opt' on the selected extensions and anchors to non-dot
filenames, excluding Emacs lock files (.#*) at the regexp level."
  (concat "^[^.].*\\."
          (regexp-opt
           (mapcar (lambda (type) (cdr (assq type ctrl-source--type-patterns)))
                   types))
          "$"))

(defun ctrl-source--files (root &rest types)
  "Return files under ROOT matching any of the TYPE symbols.
TYPES are selector signals into `ctrl-source--type-patterns':
  `el'  — Emacs Lisp (.el)
  `sh'  — shell scripts (.sh)
  `md'  — Markdown (.md)
Excludes .git, node_modules, vendor, and Emacs lock files (.#*)."
  (directory-files-recursively
   root
   (ctrl-source--compile-pattern types)
   nil
   (lambda (dir) (not (string-match-p ctrl-source--exclude-re dir)))))

(defun ctrl-source--extension-dirs (lisp-dir)
  "Return full paths of extension subdirectories under LISP-DIR/extensions/.
Excludes hidden directories and the skel template.
Returns nil when the extensions directory does not exist."
  (let ((ext-root (expand-file-name "extensions" lisp-dir)))
    (when (file-directory-p ext-root)
      (seq-filter
       (lambda (d)
         (and (file-directory-p d)
              (not (string= (file-name-nondirectory d) "skel"))))
       (directory-files ext-root t "^[^.]")))))

(defun ctrl-source--extension-el (ext-dir)
  "Return the main .el file for the extension in EXT-DIR, or nil if absent.
The main file is the one whose base name matches the directory name."
  (let* ((name (file-name-nondirectory ext-dir))
         (el   (expand-file-name (concat name ".el") ext-dir)))
    (when (file-exists-p el) el)))

(provide 'ctrl-source)

;;; ctrl-source.el ends here
