;;; check-test.el --- ERT tests for check.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena

;;; Commentary:
;; ERT tests for the ctrl headless check script.  Fixture extension trees
;; are created under `temporary-file-directory'.  No real subprocess is
;; required and no files outside the temp directory are written.
;;
;; Run with:
;;   emacs --batch -l lisp/check.el -l lisp/check-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'check)

;; ── Helpers ───────────────────────────────────────────────────────────────────

(defmacro check-test--with-clean-errors (&rest body)
  "Execute BODY with `check--errors' reset to 0, then restore it."
  (declare (indent 0))
  `(let ((check--errors 0))
     ,@body))

(defmacro check-test--silently (&rest body)
  "Execute BODY with all check logging and incidental Emacs messages suppressed.
`check--fail' still increments `check--errors' but emits no output."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'check--section) #'ignore)
             ((symbol-function 'check--ok)      #'ignore)
             ((symbol-function 'check--log)     #'ignore)
             ((symbol-function 'check--fail)
              (lambda (&rest _)
                (setq check--errors (1+ check--errors))))
             ((symbol-function 'message)        #'ignore))
     ,@body))

(defun check-test--make-extension (root name &optional opts)
  "Create a minimal valid extension directory for NAME under ROOT.
OPTS is a plist of optional overrides:
  :no-lexical   — omit the lexical-binding cookie
  :no-provide   — omit the (provide ...) form
  :no-install   — omit the (defun <name>-install ...) form
  :no-test      — omit the tests/<name>-test.el file
  :package-json — create package.json without bun.lock
  :both-locks   — create both package.json and bun.lock"
  (let* ((ext-dir  (expand-file-name name root))
         (tests    (expand-file-name "tests" ext-dir))
         (el       (expand-file-name (concat name ".el") ext-dir))
         (test-el  (expand-file-name (concat name "-test.el") tests))
         (lexical  (if (plist-get opts :no-lexical) ""
                     (format ";;; %s.el --- Test -*- lexical-binding: t; -*-\n" name)))
         (provide  (if (plist-get opts :no-provide) ""
                     (format "(provide '%s)\n" name)))
         (install  (if (plist-get opts :no-install) ""
                     (format "(defun %s-install () nil)\n" name))))
    (make-directory tests t)
    (write-region (concat lexical install provide) nil el nil 'silent)
    (unless (plist-get opts :no-test)
      (write-region (format "(provide '%s-test)\n" name) nil test-el nil 'silent))
    (when (plist-get opts :package-json)
      (write-region "{}" nil (expand-file-name "package.json" ext-dir) nil 'silent))
    (when (plist-get opts :both-locks)
      (write-region "{}" nil (expand-file-name "package.json" ext-dir) nil 'silent)
      (write-region ""  nil (expand-file-name "bun.lock"     ext-dir) nil 'silent))
    ext-dir))

;; ── Source file discovery ─────────────────────────────────────────────────────

(ert-deftest check-test-source-files-finds-el-and-sh ()
  "check--source-files returns both .el and .sh files."
  (let* ((tmpdir (make-temp-file "check-test-" t))
         (el     (expand-file-name "foo.el" tmpdir))
         (sh     (expand-file-name "bar.sh" tmpdir))
         (check--repo-dir tmpdir))
    (unwind-protect
        (progn
          (write-region "" nil el nil 'silent)
          (write-region "" nil sh nil 'silent)
          (let ((files (check--source-files)))
            (should (member el files))
            (should (member sh files))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-source-files-excludes-node-modules ()
  "check--source-files excludes files under node_modules/."
  (let* ((tmpdir   (make-temp-file "check-test-" t))
         (nm       (expand-file-name "node_modules" tmpdir))
         (vendored (expand-file-name "pkg/index.el" nm))
         (check--repo-dir tmpdir))
    (unwind-protect
        (progn
          (make-directory (file-name-directory vendored) t)
          (write-region "" nil vendored nil 'silent)
          (should (not (member vendored (check--source-files)))))
      (delete-directory tmpdir t))))

;; ── SPDX insertion ────────────────────────────────────────────────────────────

(ert-deftest check-test-spdx-insert-adds-missing-headers-el ()
  "SPDX headers are inserted into an .el file that lacks them."
  (let* ((tmpdir (make-temp-file "check-test-" t))
         (el     (expand-file-name "foo.el" tmpdir)))
    (unwind-protect
        (check-test--silently
          (write-region ";;; foo.el --- test -*- lexical-binding: t; -*-\n(provide 'foo)\n"
                        nil el nil 'silent)
          (check--spdx-insert el)
          (let ((contents (with-temp-buffer
                            (insert-file-contents el)
                            (buffer-string))))
            (should (string-match-p "SPDX-License-Identifier:" contents))
            (should (string-match-p "SPDX-FileCopyrightText:"  contents))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-spdx-insert-skips-when-headers-present ()
  "SPDX insertion is skipped when both headers already exist."
  (let* ((tmpdir (make-temp-file "check-test-" t))
         (el     (expand-file-name "foo.el" tmpdir))
         (original (concat ";;; foo.el --- test -*- lexical-binding: t; -*-\n"
                           ";; SPDX-License-Identifier: GPL-3.0-or-later\n"
                           ";; SPDX-FileCopyrightText: 2026 Anthony Urena\n"
                           "(provide 'foo)\n")))
    (unwind-protect
        (check-test--silently
          (write-region original nil el nil 'silent)
          (check--spdx-insert el)
          (let ((contents (with-temp-buffer
                            (insert-file-contents el)
                            (buffer-string))))
            (should (= (length (split-string contents "SPDX-License-Identifier:" t)) 2))
            (should (= (length (split-string contents "SPDX-FileCopyrightText:"  t)) 2))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-spdx-insert-uses-hash-prefix-for-sh ()
  "SPDX insertion uses # prefix for .sh files."
  (let* ((tmpdir (make-temp-file "check-test-" t))
         (sh     (expand-file-name "run.sh" tmpdir)))
    (unwind-protect
        (check-test--silently
          (write-region "#!/usr/bin/env bash\necho hi\n" nil sh nil 'silent)
          (check--spdx-insert sh)
          (let ((contents (with-temp-buffer
                            (insert-file-contents sh)
                            (buffer-string))))
            (should (string-match-p "^# SPDX-License-Identifier:" contents))
            (should (string-match-p "^# SPDX-FileCopyrightText:"  contents))))
      (delete-directory tmpdir t))))

;; ── Structural validation ─────────────────────────────────────────────────────

(ert-deftest check-test-validate-extension-passes-valid ()
  "A correctly structured extension passes validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext")
          (check-test--with-clean-errors
            (should (check--validate-extension
                     "myext" (expand-file-name "myext" tmpdir)))
            (should (= check--errors 0))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-validate-extension-fails-no-lexical ()
  "Missing lexical-binding cookie fails validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext" '(:no-lexical t))
          (check-test--with-clean-errors
            (should-not (check--validate-extension
                         "myext" (expand-file-name "myext" tmpdir)))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-validate-extension-fails-no-provide ()
  "Missing (provide ...) form fails validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext" '(:no-provide t))
          (check-test--with-clean-errors
            (should-not (check--validate-extension
                         "myext" (expand-file-name "myext" tmpdir)))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-validate-extension-fails-no-install ()
  "Missing (defun <name>-install ...) form fails validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext" '(:no-install t))
          (check-test--with-clean-errors
            (should-not (check--validate-extension
                         "myext" (expand-file-name "myext" tmpdir)))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-validate-extension-fails-missing-lockfile ()
  "package.json without bun.lock fails validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext" '(:package-json t))
          (check-test--with-clean-errors
            (should-not (check--validate-extension
                         "myext" (expand-file-name "myext" tmpdir)))))
      (delete-directory tmpdir t))))

(ert-deftest check-test-validate-extension-passes-with-lockfile ()
  "package.json with bun.lock passes validation."
  (let* ((tmpdir (make-temp-file "check-test-" t)))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "myext" '(:both-locks t))
          (check-test--with-clean-errors
            (should (check--validate-extension
                     "myext" (expand-file-name "myext" tmpdir)))
            (should (= check--errors 0))))
      (delete-directory tmpdir t))))

;; ── Structure run — skel skipped ──────────────────────────────────────────────

(ert-deftest check-test-run-structure-skips-skel ()
  "check--run-structure never adds skel to valid-extensions."
  (let* ((tmpdir  (make-temp-file "check-test-" t))
         (check--extensions-dir tmpdir)
         (check--valid-extensions nil))
    (unwind-protect
        (check-test--silently
          (check-test--make-extension tmpdir "skel")
          (check-test--with-clean-errors
            (check--run-structure))
          (should (not (member "skel" check--valid-extensions))))
      (delete-directory tmpdir t))))

;; ── Error accumulation ────────────────────────────────────────────────────────

(ert-deftest check-test-fail-increments-error-count ()
  "check--fail increments `check--errors' by 1 each call."
  (check-test--with-clean-errors
    (check-test--silently
      (check--fail "First")
      (check--fail "Second")
      (should (= check--errors 2)))))

(provide 'check-test)

;;; check-test.el ends here
