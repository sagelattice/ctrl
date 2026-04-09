;;; check.el --- Headless quality checks for ctrl Emacs extensions -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Invoked headlessly by check.sh:
;;
;;   emacs --batch -l lisp/check.el
;;
;; Runs across all source files and extensions:
;;   1. SPDX       — inserts missing license/copyright headers
;;   2. Structure  — validates extension layout and code conventions
;;   3. Format     — rewrites indentation via indent-region
;;   4. Byte-compile — catches undefined vars, wrong-arity calls, syntax errors
;;   5. Checkdoc   — validates docstring presence and style
;;   6. ERT        — runs bootstrap-test, check-test, and each extension's test suite
;;
;; Exits with status 1 if any check fails; status 0 on success.
;; Idempotent: safe to re-run.

;;; Commentary:
;; Derives the repo root from this file's own location via `load-file-name'.
;; Accumulates an error count across all checks and calls `kill-emacs' 1 at
;; the end if any errors were recorded.  Read-only with respect to production
;; code, except for the SPDX insertion step which intentionally mutates files.

;;; Code:

(defconst check--lisp-dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Absolute path to the lisp/ directory containing check.el.")

(defconst check--repo-dir
  (file-name-directory (directory-file-name check--lisp-dir))
  "Absolute path to the repository root.")

(defconst check--extensions-dir
  (expand-file-name "extensions" check--lisp-dir)
  "Absolute path to lisp/extensions/.")

;; Load shared batch logging.
(load (expand-file-name "ctrl-log" check--lisp-dir) nil t)

(defvar check--valid-extensions nil
  "List of extension names that passed structural validation.")

;; ── 1. SPDX header insertion ──────────────────────────────────────────────────

(defun check--source-files ()
  "Return all .el and .sh files under the repo root, excluding vendored paths."
  (let ((results nil))
    (dolist (f (directory-files-recursively
                check--repo-dir
                "\\.\\(el\\|sh\\)$"
                nil
                (lambda (dir)
                  (not (string-match-p
                        "/\\(\\.git\\|node_modules\\|vendor\\)\\(/\\|$\\)"
                        dir)))))
      (unless (or (string-match-p "/\\(\\.git\\|node_modules\\|vendor\\)/" f)
                  (string-prefix-p ".#" (file-name-nondirectory f)))
        (push f results)))
    (nreverse results)))

(defun check--comment-prefix (file)
  "Return the line-comment prefix string for FILE."
  (if (string-suffix-p ".el" file) ";; " "# "))

(defun check--spdx-insert (file)
  "Insert missing SPDX headers into FILE, preserving the first line.
Uses the comment syntax appropriate to the file type."
  (let* ((prefix (check--comment-prefix file))
         (license-line   (concat prefix "SPDX-License-Identifier: GPL-3.0-or-later"))
         (copyright-line (concat prefix "SPDX-FileCopyrightText: 2026 Anthony Urena")))
    (with-temp-buffer
      (insert-file-contents file)
      (let ((has-license   (save-excursion
                             (goto-char (point-min))
                             (re-search-forward "SPDX-License-Identifier:" nil t)))
            (has-copyright (save-excursion
                             (goto-char (point-min))
                             (re-search-forward "SPDX-FileCopyrightText:" nil t))))
        (when (or (not has-license) (not has-copyright))
          (goto-char (point-min))
          (forward-line 1)              ; move past line 1 (shebang or cookie)
          (unless has-copyright (insert copyright-line "\n"))
          (unless has-license   (insert license-line   "\n"))
          (write-region (point-min) (point-max) file nil 'silent)
          (ctrl-log--log "%s: inserted SPDX headers" (file-name-nondirectory file)))))))

(defun check--run-spdx ()
  "Insert missing SPDX headers in all .el and .sh source files."
  (ctrl-log--section "SPDX")
  (dolist (f (check--source-files))
    (check--spdx-insert f)
    (ctrl-log--ok "%s" (file-name-nondirectory f))))

;; ── 2. Structural validation ──────────────────────────────────────────────────

(defun check--validate-extension (name ext-dir)
  "Validate the structural conventions for extension NAME in EXT-DIR.
Returns non-nil if all checks pass; nil otherwise."
  (let ((el       (expand-file-name (concat name ".el") ext-dir))
        (test-el  (expand-file-name (concat "tests/" name "-test.el") ext-dir))
        (ok t))
    ;; Required files.
    (unless (file-exists-p el)
      (ctrl-log--fail "%s: missing %s.el" name name)
      (setq ok nil))
    (unless (file-exists-p test-el)
      (ctrl-log--fail "%s: missing tests/%s-test.el" name name)
      (setq ok nil))
    (when ok
      ;; Lexical binding on line 1.
      (with-temp-buffer
        (insert-file-contents el nil 0 200)
        (goto-char (point-min))
        (unless (string-match-p "lexical-binding: t"
                                (buffer-substring (point-min) (line-end-position)))
          (ctrl-log--fail "%s: missing lexical-binding: t on line 1" name)
          (setq ok nil)))
      ;; (provide '<name>) form.
      (with-temp-buffer
        (insert-file-contents el)
        (goto-char (point-min))
        (unless (re-search-forward (format "^(provide '%s)" (regexp-quote name)) nil t)
          (ctrl-log--fail "%s: missing (provide '%s) form" name name)
          (setq ok nil)))
      ;; (defun <name>-install ...) form.
      (with-temp-buffer
        (insert-file-contents el)
        (goto-char (point-min))
        (unless (re-search-forward (format "^(defun %s-install" (regexp-quote name)) nil t)
          (ctrl-log--fail "%s: missing (defun %s-install ...)" name name)
          (setq ok nil)))
      ;; bun.lock present when package.json is present.
      (when (file-exists-p (expand-file-name "package.json" ext-dir))
        (unless (file-exists-p (expand-file-name "bun.lock" ext-dir))
          (ctrl-log--fail "%s: package.json present but bun.lock is missing" name)
          (setq ok nil))))
    ok))

(defun check--run-structure ()
  "Validate layout and conventions for all extensions.
Populates `check--valid-extensions' with names that pass."
  (ctrl-log--section "Structure")
  (setq check--valid-extensions nil)
  (unless (file-directory-p check--extensions-dir)
    (ctrl-log--log "No extensions directory found — skipping")
    (cl-return-from check--run-structure nil))
  ;; Flat .el files directly in extensions/ are not allowed.
  (dolist (f (directory-files check--extensions-dir t "\\.el$"))
    (ctrl-log--fail "Flat extension file not allowed: %s" (file-name-nondirectory f))
    (ctrl-log--log "  Move to lisp/extensions/%s/%s"
                (file-name-base f) (file-name-nondirectory f)))
  ;; Validate each subdirectory.
  (dolist (name (directory-files check--extensions-dir nil "^[^.]"))
    (let ((ext-dir (expand-file-name name check--extensions-dir)))
      (when (file-directory-p ext-dir)
        (if (string= name "skel")
            nil                         ; template — skip
          (if (check--validate-extension name ext-dir)
              (progn
                (ctrl-log--ok "%s" name)
                (push name check--valid-extensions))
            nil)))))
  (setq check--valid-extensions (nreverse check--valid-extensions))
  (when (null check--valid-extensions)
    (ctrl-log--log "No structurally valid extensions found")))

;; ── 3. Format ─────────────────────────────────────────────────────────────────

(defun check--run-format ()
  "Rewrite indentation in each valid extension's .el file."
  (ctrl-log--section "Format")
  (dolist (name check--valid-extensions)
    (let ((el (expand-file-name (concat name "/" name ".el") check--extensions-dir)))
      (with-current-buffer (find-file-noselect el t)
        (cl-letf (((symbol-function 'message) #'ignore))
          (indent-region (point-min) (point-max)))
        (save-buffer))
      (ctrl-log--ok "%s" name))))

;; ── 4. Byte-compile ───────────────────────────────────────────────────────────

(defun check--run-byte-compile ()
  "Byte-compile each valid extension, recording warnings and errors.
Deletes the .elc artifact after each check."
  (ctrl-log--section "Byte-compile")
  (dolist (name check--valid-extensions)
    (let* ((el  (expand-file-name (concat name "/" name ".el") check--extensions-dir))
           (elc (concat (file-name-sans-extension el) ".elc"))
           (log-buf-name "*Compile-Log*"))
      ;; Clear any previous compile log.
      (when (get-buffer log-buf-name)
        (kill-buffer log-buf-name))
      (let ((result (byte-compile-file el)))
        ;; Collect warnings from the compile log buffer.
        (let* ((log-buf (get-buffer log-buf-name))
               (log-output (if log-buf
                               (with-current-buffer log-buf (buffer-string))
                             "")))
          (when (file-exists-p elc)
            (delete-file elc))
          (if (and result (not (string-match-p "\\(error\\|warning\\)" log-output)))
              (ctrl-log--ok "%s" name)
            (ctrl-log--fail "%s: byte-compile failed or emitted warnings" name)
            (when (and log-buf (not (string-empty-p log-output)))
              (dolist (line (split-string log-output "\n" t))
                (message "      %s" line)))))))))

;; ── 5. Checkdoc ───────────────────────────────────────────────────────────────

(defun check--run-checkdoc ()
  "Run checkdoc on each valid extension's .el file."
  (ctrl-log--section "Checkdoc")
  (dolist (name check--valid-extensions)
    (let* ((el (expand-file-name (concat name "/" name ".el") check--extensions-dir))
           (output (with-output-to-string
                     (let ((standard-output (current-buffer)))
                       (checkdoc-file el)))))
      (if (string-empty-p output)
          (ctrl-log--ok "%s" name)
        (ctrl-log--fail "%s: checkdoc errors" name)
        (dolist (line (split-string output "\n" t))
          (message "      %s" line))))))

;; ── 6. ERT ────────────────────────────────────────────────────────────────────

(defun check--run-ert-pair (label src-el test-el load-dir)
  "Run ERT for LABEL by loading SRC-EL and TEST-EL in a subprocess.
LOAD-DIR is prepended to the load path."
  (let* ((emacs-bin (expand-file-name invocation-name invocation-directory))
         (out-buf (generate-new-buffer (format " *check-ert-%s*" label)))
         (exit-code
          (call-process emacs-bin nil out-buf nil
                        "--batch"
                        "--eval" (format "(add-to-list 'load-path %S)" load-dir)
                        "-l" src-el
                        "-l" test-el
                        "-f" "ert-run-tests-batch-and-exit")))
    (if (= exit-code 0)
        (ctrl-log--ok "%s" label)
      (ctrl-log--fail "%s: ERT tests failed" label)
      (with-current-buffer out-buf
        (let ((lines (split-string (buffer-string) "\n" t)))
          (dolist (line (last lines 5))
            (message "      %s" line)))))
    (kill-buffer out-buf)))

(defun check--run-ert ()
  "Run ERT test suites for lisp modules and all valid extensions.
Always runs bootstrap and check module tests regardless of extension count."
  (ctrl-log--section "ERT")
  ;; Lisp module tests (bootstrap.el, check.el).
  (dolist (name '("bootstrap" "check"))
    (check--run-ert-pair
     name
     (expand-file-name (concat name ".el")       check--lisp-dir)
     (expand-file-name (concat name "-test.el")  check--lisp-dir)
     check--lisp-dir))
  ;; Extension tests.
  (dolist (name check--valid-extensions)
    (let ((ext-dir (expand-file-name name check--extensions-dir)))
      (check--run-ert-pair
       name
       (expand-file-name (concat name ".el")             ext-dir)
       (expand-file-name (concat "tests/" name "-test.el") ext-dir)
       ext-dir))))

;; ── Entry point ──────────────────────────────────────────────────────────────

(defun check-run ()
  "Run all checks and exit with status 1 if any fail.
Intended for headless invocation via `emacs --batch -l check.el -f check-run'."
  (setq ctrl-log--errors 0
        check--valid-extensions nil)
  (check--run-spdx)
  (check--run-structure)
  (when check--valid-extensions
    (check--run-format)
    (check--run-byte-compile)
    (check--run-checkdoc))
  (check--run-ert)
  (if (= ctrl-log--errors 0)
      (message "\nAll checks passed.")
    (message "\n%d error(s)." ctrl-log--errors)
    (kill-emacs 1)))

(provide 'check)

;;; check.el ends here
