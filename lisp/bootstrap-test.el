;;; bootstrap-test.el --- ERT tests for bootstrap.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena

;;; Commentary:
;; ERT tests for the ctrl bootstrap script.  All filesystem operations
;; and process calls are mocked — no test writes outside
;; `temporary-file-directory' and no real subprocess is required.
;;
;; Run with:
;;   emacs --batch -l lisp/bootstrap.el -l lisp/bootstrap-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'bootstrap)

;; ── Helpers ───────────────────────────────────────────────────────────────────

(defmacro bootstrap-test--with-clean-errors (&rest body)
  "Execute BODY with `bootstrap--errors' reset to 0, then restore it."
  (declare (indent 0))
  `(let ((bootstrap--errors 0))
     ,@body))

(defmacro bootstrap-test--silently (&rest body)
  "Execute BODY with all bootstrap logging suppressed.
`bootstrap--fail' still increments `bootstrap--errors' but emits no output."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'bootstrap--section) #'ignore)
             ((symbol-function 'bootstrap--ok)      #'ignore)
             ((symbol-function 'bootstrap--log)     #'ignore)
             ((symbol-function 'bootstrap--warn)    #'ignore)
             ((symbol-function 'bootstrap--fail)
              (lambda (&rest _)
                (setq bootstrap--errors (1+ bootstrap--errors)))))
     ,@body))

;; ── Feature verification ──────────────────────────────────────────────────────

(ert-deftest bootstrap-test-verify-features-ok-when-treesit-available ()
  "No error recorded when tree-sitter reports available."
  (bootstrap-test--with-clean-errors
    (bootstrap-test--silently
      (cl-letf (((symbol-function 'treesit-available-p) (lambda () t)))
        (bootstrap--verify-features)
        (should (= bootstrap--errors 0))))))

(ert-deftest bootstrap-test-verify-features-fails-when-treesit-absent ()
  "Error recorded when tree-sitter is not available."
  (bootstrap-test--with-clean-errors
    (bootstrap-test--silently
      (cl-letf (((symbol-function 'treesit-available-p) (lambda () nil)))
        (bootstrap--verify-features)
        (should (= bootstrap--errors 1))))))

;; ── Symlink helper ────────────────────────────────────────────────────────────

(ert-deftest bootstrap-test-link-creates-symlink ()
  "bootstrap--link creates a symlink when destination is absent."
  (let* ((tmpdir (make-temp-file "bootstrap-test-" t))
         (src    (expand-file-name "src-target" tmpdir))
         (dst    (expand-file-name "dst-link"   tmpdir)))
    (unwind-protect
        (bootstrap-test--silently
          (write-region "" nil src nil 'silent)
          (bootstrap--link src dst)
          (should (file-symlink-p dst))
          (should (string= (file-symlink-p dst) src)))
      (delete-directory tmpdir t))))

(ert-deftest bootstrap-test-link-skips-correct-symlink ()
  "bootstrap--link does nothing when destination already points to source."
  (let* ((tmpdir (make-temp-file "bootstrap-test-" t))
         (src    (expand-file-name "src" tmpdir))
         (dst    (expand-file-name "dst" tmpdir)))
    (unwind-protect
        (bootstrap-test--silently
          (write-region "" nil src nil 'silent)
          (make-symbolic-link src dst)
          (bootstrap-test--with-clean-errors
            (bootstrap--link src dst)
            (should (= bootstrap--errors 0)))
          (should (string= (file-symlink-p dst) src)))
      (delete-directory tmpdir t))))

(ert-deftest bootstrap-test-link-replaces-stale-symlink ()
  "bootstrap--link replaces a symlink that points to a different target."
  (let* ((tmpdir  (make-temp-file "bootstrap-test-" t))
         (src-old (expand-file-name "old" tmpdir))
         (src-new (expand-file-name "new" tmpdir))
         (dst     (expand-file-name "dst" tmpdir)))
    (unwind-protect
        (bootstrap-test--silently
          (write-region "" nil src-old nil 'silent)
          (write-region "" nil src-new nil 'silent)
          (make-symbolic-link src-old dst)
          (bootstrap--link src-new dst)
          (should (string= (file-symlink-p dst) src-new)))
      (delete-directory tmpdir t))))

(ert-deftest bootstrap-test-link-warns-on-real-file ()
  "bootstrap--link warns and skips when destination is a real file."
  (let* ((tmpdir (make-temp-file "bootstrap-test-" t))
         (src    (expand-file-name "src" tmpdir))
         (dst    (expand-file-name "dst" tmpdir)))
    (unwind-protect
        (bootstrap-test--silently
          (write-region "" nil src nil 'silent)
          (write-region "" nil dst nil 'silent)
          (bootstrap-test--with-clean-errors
            (bootstrap--link src dst)
            (should (= bootstrap--errors 0)))
          (should (not (file-symlink-p dst))))
      (delete-directory tmpdir t))))

;; ── Config scaffold ───────────────────────────────────────────────────────────

(ert-deftest bootstrap-test-config-scaffold-creates-dirs ()
  "bootstrap--config-scaffold creates the expected subdirectories."
  (let* ((tmpdir     (make-temp-file "bootstrap-test-" t))
         (config-dir (expand-file-name "emacs" tmpdir)))
    (unwind-protect
        (bootstrap-test--silently
          (cl-letf (((symbol-function 'expand-file-name)
                     (lambda (name &optional base)
                       (if (and (stringp name) (string= name "~/.config/emacs"))
                           config-dir
                         (if base
                             (concat (file-name-as-directory base) name)
                           (concat "/" name)))))
                    ((symbol-function 'bootstrap--link)   #'ignore)
                    ((symbol-function 'call-process)      (lambda (&rest _) 0))
                    ((symbol-function 'write-region)      #'ignore))
            (bootstrap--config-scaffold)
            (should (file-directory-p config-dir))
            (should (file-directory-p (expand-file-name "backups"    config-dir)))
            (should (file-directory-p (expand-file-name "auto-saves" config-dir)))))
      (delete-directory tmpdir t))))

(ert-deftest bootstrap-test-config-scaffold-skips-existing-gitignore ()
  "bootstrap--config-scaffold does not overwrite an existing .gitignore."
  (let* ((tmpdir     (make-temp-file "bootstrap-test-" t))
         (config-dir (expand-file-name "emacs" tmpdir))
         (gitignore  (expand-file-name ".gitignore" config-dir))
         (sentinel   "existing content"))
    (unwind-protect
        (progn
          (make-directory config-dir t)
          (write-region sentinel nil gitignore nil 'silent)
          (bootstrap-test--silently
            (cl-letf (((symbol-function 'bootstrap--link) #'ignore)
                      ((symbol-function 'call-process)    (lambda (&rest _) 0))
                      ((symbol-function 'expand-file-name)
                       (lambda (name &optional base)
                         (cond
                          ((string= name "~/.config/emacs") config-dir)
                          (base (concat (file-name-as-directory base) name))
                          (t (concat "/" name))))))
              (bootstrap--config-scaffold)))
          (should (string= (with-temp-buffer
                             (insert-file-contents gitignore)
                             (buffer-string))
                           sentinel)))
      (delete-directory tmpdir t))))

;; ── Extension bootstrap ───────────────────────────────────────────────────────

(ert-deftest bootstrap-test-install-extensions-skips-skel ()
  "bootstrap--install-extensions never calls <skel>-install."
  (let* ((tmpdir   (make-temp-file "bootstrap-test-" t))
         (ext-root (expand-file-name "extensions" tmpdir))
         (skel-dir (expand-file-name "skel" ext-root))
         (skel-el  (expand-file-name "skel.el" skel-dir))
         (called   nil))
    (unwind-protect
        (bootstrap-test--silently
          (make-directory skel-dir t)
          (write-region "(provide 'skel)" nil skel-el nil 'silent)
          (let ((bootstrap--lisp-dir (file-name-as-directory tmpdir)))
            (cl-letf (((symbol-function 'skel-install)
                       (lambda () (setq called t))))
              (bootstrap--install-extensions)))
          (should (not called)))
      (delete-directory tmpdir t))))

(defvar bootstrap-test--install-called nil
  "Set to t by the fixture foo-install function during install test.")

(ert-deftest bootstrap-test-install-extensions-calls-install-fn ()
  "bootstrap--install-extensions calls <name>-install for each real extension."
  (setq bootstrap-test--install-called nil)
  (let* ((tmpdir   (make-temp-file "bootstrap-test-" t))
         (ext-root (expand-file-name "extensions" tmpdir))
         (foo-dir  (expand-file-name "foo" ext-root))
         (foo-el   (expand-file-name "foo.el" foo-dir)))
    (unwind-protect
        (bootstrap-test--silently
          (make-directory foo-dir t)
          (write-region
           (concat ";;; foo.el --- test -*- lexical-binding: t; -*-\n"
                   "(defun foo-install ()\n"
                   "  (setq bootstrap-test--install-called t))\n"
                   "(provide 'foo)\n")
           nil foo-el nil 'silent)
          (let ((bootstrap--lisp-dir (file-name-as-directory tmpdir)))
            (bootstrap--install-extensions))
          (should bootstrap-test--install-called))
      (delete-directory tmpdir t))))

(ert-deftest bootstrap-test-install-extensions-records-error-on-missing-el ()
  "bootstrap--install-extensions records a warning (not error) for missing .el."
  (let* ((tmpdir   (make-temp-file "bootstrap-test-" t))
         (ext-root (expand-file-name "extensions" tmpdir))
         (bar-dir  (expand-file-name "bar" ext-root)))
    (unwind-protect
        (bootstrap-test--silently
          (make-directory bar-dir t)
          (bootstrap-test--with-clean-errors
            (let ((bootstrap--lisp-dir (file-name-as-directory tmpdir)))
              (bootstrap--install-extensions))
            (should (= bootstrap--errors 0))))
      (delete-directory tmpdir t))))

;; ── Error accumulation ────────────────────────────────────────────────────────

(ert-deftest bootstrap-test-fail-increments-error-count ()
  "bootstrap--fail increments `bootstrap--errors' by 1 each call."
  (bootstrap-test--with-clean-errors
    (bootstrap-test--silently
      (bootstrap--fail "First error")
      (bootstrap--fail "Second error")
      (should (= bootstrap--errors 2)))))

(provide 'bootstrap-test)

;;; bootstrap-test.el ends here
