;;; bootstrap.el --- Headless bootstrap for ctrl Emacs configuration -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Invoked headlessly by install.sh after Emacs is installed:
;;
;;   emacs --batch -l lisp/bootstrap.el -f bootstrap-run
;;
;; Performs feature verification, config scaffold, extension bootstrap,
;; and tree-sitter grammar compilation.  Exits with status 1 if any step
;; fails; status 0 on success.  Idempotent: safe to re-run.

;;; Commentary:
;; Self-contained bootstrap for the ctrl Emacs dotfiles.  All paths are
;; derived from this file's own location via `load-file-name'.  Each
;; step is idempotent.  Errors are accumulated across all steps; the
;; process exits with status 1 if any step produced an error.

;;; Code:

(defconst bootstrap--lisp-dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Absolute path to the lisp/ directory containing bootstrap.el.")

;; Load the canonical grammar list (shared with init.el).
(load (expand-file-name "grammars" bootstrap--lisp-dir) nil t)
;; Load shared batch logging.
(load (expand-file-name "ctrl-log" bootstrap--lisp-dir) nil t)

;; ── 1. Feature verification ──────────────────────────────────────────────────

(defun bootstrap--verify-features ()
  "Assert that required Emacs build features are available.
Records an error and emits a warning if tree-sitter is not active.
Does not exit immediately — errors are accumulated."
  (ctrl-log--section "Feature verification")
  (if (and (fboundp 'treesit-available-p) (treesit-available-p))
      (ctrl-log--ok "Tree-sitter: active")
    (ctrl-log--fail "Tree-sitter not active — run: brew reinstall emacs")))

;; ── 2. Config scaffold ────────────────────────────────────────────────────────

(defun bootstrap--link (src dst)
  "Create a symlink at DST pointing to SRC, idempotently.
Skips if DST already points to SRC.  Replaces a stale symlink.
Warns and skips if DST is a real file or directory."
  (cond
   ((and (file-symlink-p dst)
         (string= (file-symlink-p dst) src))
    (ctrl-log--ok "%s already symlinked" (file-name-nondirectory dst)))
   ((file-symlink-p dst)
    (delete-file dst)
    (make-symbolic-link src dst)
    (ctrl-log--ok "Relinked %s" (file-name-nondirectory dst)))
   ((file-exists-p dst)
    (ctrl-log--warn "%s exists and is not a symlink — skipping"
                     (file-name-nondirectory dst)))
   (t
    (make-symbolic-link src dst)
    (ctrl-log--ok "Symlinked %s" (file-name-nondirectory dst)))))

(defun bootstrap--config-scaffold ()
  "Create the Emacs config directory structure and symlinks.
Uses `user-emacs-directory' so the symlinks land wherever Emacs
actually looks — ~/.config/emacs (XDG) or ~/.emacs.d (classic),
whichever is active on this machine.  All operations are idempotent."
  (ctrl-log--section "Config scaffold")
  (let* ((config-dir (directory-file-name (expand-file-name user-emacs-directory)))
         (lisp-src   (directory-file-name bootstrap--lisp-dir))
         (early-init (expand-file-name "early-init.el" bootstrap--lisp-dir))
         (init       (expand-file-name "init.el" bootstrap--lisp-dir)))
    ;; Directories.
    (dolist (dir (list config-dir
                       (expand-file-name "backups" config-dir)
                       (expand-file-name "auto-saves" config-dir)))
      (make-directory dir t))
    (ctrl-log--ok "Directory structure ready")
    ;; Symlinks.
    (bootstrap--link early-init (expand-file-name "early-init.el" config-dir))
    (bootstrap--link init       (expand-file-name "init.el"       config-dir))
    (bootstrap--link lisp-src   (expand-file-name "lisp"          config-dir))))

;; ── 3. Extension bootstrap ────────────────────────────────────────────────────

(defun bootstrap--install-extensions ()
  "Enumerate extensions under lisp/extensions/ and call each <name>-install.
Skips the skel template directory.  Logs progress per extension."
  (ctrl-log--section "Extension bootstrap")
  (let* ((ext-root (expand-file-name "extensions" bootstrap--lisp-dir))
         (found nil))
    (if (not (file-directory-p ext-root))
        (ctrl-log--ok "No extensions directory — skipping")
      (dolist (name (directory-files ext-root nil "^[^.]"))
        (let ((ext-dir (expand-file-name name ext-root)))
          (when (and (file-directory-p ext-dir)
                     (not (string= name "skel")))
            (let ((el (expand-file-name (concat name ".el") ext-dir)))
              (if (not (file-exists-p el))
                  (ctrl-log--warn "%s: missing %s.el — skipping" name name)
                (setq found t)
                (ctrl-log--log "Installing %s..." name)
                (condition-case err
                    (progn
                      (add-to-list 'load-path ext-dir)
                      (load el nil t)
                      (let ((install-fn (intern (concat name "-install"))))
                        (if (fboundp install-fn)
                            (progn
                              (funcall install-fn)
                              (ctrl-log--ok "%s" name))
                          (ctrl-log--fail "%s: %s-install not defined"
                                           name name))))
                  (error
                   (ctrl-log--fail "%s: %s" name
                                    (error-message-string err)))))))))
      (unless found
        (ctrl-log--ok "No extensions to install")))))

;; ── 4. Tree-sitter grammar compilation ───────────────────────────────────────

(defun bootstrap--compile-grammars ()
  "Compile tree-sitter language grammars for all configured languages.
Per-language errors are caught and reported without aborting the run."
  (ctrl-log--section "Tree-sitter language grammars")
  (if (not (and (fboundp 'treesit-available-p) (treesit-available-p)))
      (ctrl-log--warn "Tree-sitter not available — skipping grammar compilation")
    (let ((to-compile
           (seq-filter (lambda (entry)
                         (not (treesit-language-available-p (car entry))))
                       treesit-language-source-alist)))
      (if (null to-compile)
          (ctrl-log--ok "All grammars already installed — skipping")
        (ctrl-log--log "Compiling grammars: %s"
                        (mapconcat (lambda (x) (symbol-name (car x)))
                                   to-compile ", "))
        (dolist (entry to-compile)
          (let ((lang (car entry)))
            (condition-case err
                (progn
                  (treesit-install-language-grammar lang)
                  (ctrl-log--ok "%s" (symbol-name lang)))
              (error
               (ctrl-log--fail "%s: %s" (symbol-name lang)
                                (error-message-string err))))))
        (ctrl-log--ok "Grammar compilation complete")))))

;; ── Entry point ──────────────────────────────────────────────────────────────

(defun bootstrap-run ()
  "Run the full bootstrap sequence and exit with status 1 on any error.
Intended for headless invocation via `emacs --batch -l bootstrap.el -f bootstrap-run'."
  (setq ctrl-log--errors 0)
  (bootstrap--verify-features)
  (bootstrap--config-scaffold)
  (bootstrap--install-extensions)
  (bootstrap--compile-grammars)
  (when (> ctrl-log--errors 0)
    (message "\n%d error(s) during bootstrap." ctrl-log--errors)
    (kill-emacs 1)))

(provide 'bootstrap)

;;; bootstrap.el ends here
