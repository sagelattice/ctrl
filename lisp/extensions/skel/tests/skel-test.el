;;; skel-test.el --- ERT tests for skel -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena

;;; Commentary:
;; ERT tests for the skel skeleton extension.  In real extensions, all
;; subprocess calls must be mocked — no test should require an external runtime.
;;
;; Run with:
;;   emacs --batch -l skel.el -l tests/skel-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'skel)

;; ── Install ───────────────────────────────────────────────────────────────────

(ert-deftest skel-test-install-is-interactive ()
  "skel-install must be callable via M-x."
  (should (commandp #'skel-install)))

(ert-deftest skel-test-install-completes-without-error ()
  "skel-install runs without signalling an error."
  (should-not
   (condition-case err
       (progn (skel-install) nil)
     (error err))))

;; ── Commands ──────────────────────────────────────────────────────────────────

(ert-deftest skel-test-run-is-interactive ()
  "skel-run must be callable via M-x."
  (should (commandp #'skel-run)))

(provide 'skel-test)

;;; skel-test.el ends here
