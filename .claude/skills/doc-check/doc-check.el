;;; doc-check.el --- Find .md files referencing changed source files -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Headless script invoked by the doc-check skill.  Accepts changed filenames
;; as command-line arguments and prints every .md file that references each one,
;; with line numbers.  Claude then reads only those locations to check for drift.
;;
;; Usage:
;;   emacs --batch \
;;     -l .claude/skills/doc-check/doc-check.el \
;;     -f doc-check-run \
;;     -- file1 file2 ...

;;; Commentary:
;; Derives the repo root from its own location via `load-file-name'.
;; Searches only .md files outside .claude/ to avoid self-referential matches.

;;; Code:

(defconst doc-check--script-dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Directory containing doc-check.el.")

(defconst doc-check--repo-root
  (expand-file-name "../../.." doc-check--script-dir)
  "Repository root — three levels above the skill directory.")

(load (expand-file-name "lisp/ctrl-source" doc-check--repo-root) nil t)

(defun doc-check--md-files ()
  "Return all .md files under the repo root."
  (ctrl-source--files doc-check--repo-root 'md))

(defun doc-check--matching-lines (file pattern)
  "Return line numbers in FILE where PATTERN matches."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((line 0) hits)
      (goto-char (point-min))
      (while (not (eobp))
        (setq line (1+ line))
        (when (re-search-forward pattern (line-end-position) t)
          (push line hits))
        (forward-line 1))
      (nreverse hits))))

(defun doc-check-run ()
  "Print .md files referencing each changed file given as command-line args.
Output format: one header per changed file, then indented file:line entries."
  (let ((changed command-line-args-left)
        (md-files (doc-check--md-files)))
    (setq command-line-args-left nil)
    (unless changed
      (message "Usage: emacs --batch -l doc-check.el -f doc-check-run -- FILE...")
      (kill-emacs 1))
    (dolist (target changed)
      (let* ((basename (file-name-nondirectory target))
             (pattern  (regexp-quote basename))
             (hits     nil))
        (dolist (md md-files)
          (let ((lines (doc-check--matching-lines md pattern)))
            (when lines
              (push (cons (file-relative-name md doc-check--repo-root) lines)
                    hits))))
        (message "%s" target)
        (if hits
            (dolist (entry (nreverse hits))
              (message "  %s:%s"
                       (car entry)
                       (mapconcat #'number-to-string (cdr entry) ",")))
          (message "  (no references found)"))))))

(provide 'doc-check)

;;; doc-check.el ends here
