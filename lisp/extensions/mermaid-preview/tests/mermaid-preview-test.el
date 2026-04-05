;;; mermaid-preview-test.el --- ERT tests for mermaid-preview -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena

;;; Commentary:
;; ERT tests for the mermaid-preview extension.  All subprocess calls are
;; mocked — no test requires Bun or mmdc to be present.
;;
;; Run with:
;;   emacs --batch \
;;     --eval "(add-to-list 'load-path \"<ext-dir>\")" \
;;     -l mermaid-preview.el \
;;     -l tests/mermaid-preview-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'mermaid-preview)

;; ── Helpers ───────────────────────────────────────────────────────────────────

(defmacro mermaid-preview-test--with-markdown-buffer (content &rest body)
  "Execute BODY in a temporary buffer containing CONTENT."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,content)
     ,@body))

;; ── Install ───────────────────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-install-is-interactive ()
  "mermaid-preview-install must be callable via M-x."
  (should (commandp #'mermaid-preview-install)))

;; ── Block detection ───────────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-block-at-point-found ()
  "Returns block data when point is inside a mermaid fence."
  (mermaid-preview-test--with-markdown-buffer
      "```mermaid\ngraph TD\n  A --> B\n```\n"
    (goto-char (point-min))
    (forward-line 1)                    ; inside the block
    (let ((result (mermaid-preview--block-at-point)))
      (should result)
      (should (= (length result) 3))
      (should (stringp (nth 2 result)))
      (should (string-match-p "graph TD" (nth 2 result))))))

(ert-deftest mermaid-preview-test-block-at-point-not-found ()
  "Returns nil when point is outside any mermaid fence."
  (mermaid-preview-test--with-markdown-buffer
      "Just some text\nNo mermaid here\n"
    (goto-char (point-min))
    (should-not (mermaid-preview--block-at-point))))

(ert-deftest mermaid-preview-test-all-blocks-empty ()
  "Returns empty list when buffer has no mermaid blocks."
  (mermaid-preview-test--with-markdown-buffer
      "# Heading\n\nSome text.\n"
    (should (null (mermaid-preview--all-blocks)))))

(ert-deftest mermaid-preview-test-all-blocks-single ()
  "Finds a single mermaid block in the buffer."
  (mermaid-preview-test--with-markdown-buffer
      "```mermaid\ngraph LR\n  X --> Y\n```\n"
    (let ((blocks (mermaid-preview--all-blocks)))
      (should (= (length blocks) 1))
      (should (string-match-p "graph LR" (nth 2 (car blocks)))))))

(ert-deftest mermaid-preview-test-all-blocks-multiple ()
  "Finds multiple mermaid blocks in the buffer."
  (mermaid-preview-test--with-markdown-buffer
      "```mermaid\nflowchart TD\n  A --> B\n```\nText\n```mermaid\nsequenceDiagram\n  Alice->>Bob: Hi\n```\n"
    (let ((blocks (mermaid-preview--all-blocks)))
      (should (= (length blocks) 2))
      (should (string-match-p "flowchart" (nth 2 (nth 0 blocks))))
      (should (string-match-p "sequenceDiagram" (nth 2 (nth 1 blocks)))))))

(ert-deftest mermaid-preview-test-block-positions-ordered ()
  "Block BEG is always less than END."
  (mermaid-preview-test--with-markdown-buffer
      "```mermaid\ngraph TD\n  A --> B\n```\n"
    (goto-char (point-min))
    (forward-line 1)
    (let ((block (mermaid-preview--block-at-point)))
      (should block)
      (should (< (nth 0 block) (nth 1 block))))))

;; ── Source extraction ─────────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-source-content ()
  "Extracted source contains diagram text, not fence markers."
  (mermaid-preview-test--with-markdown-buffer
      "```mermaid\ngraph TD\n  A --> B\n```\n"
    (goto-char (point-min))
    (forward-line 1)
    (let ((block (mermaid-preview--block-at-point)))
      (should block)
      (let ((source (nth 2 block)))
        (should-not (string-match-p "```" source))
        (should (string-match-p "graph TD" source))))))

;; ── Subprocess invocation ─────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-render-spawns-process ()
  "mermaid-preview--render calls make-process with mmdc and a .png output path."
  (let (captured-command)
    (cl-letf (((symbol-function 'make-process)
               (lambda (&rest args)
                 (setq captured-command (plist-get args :command))
                 nil))
              ((symbol-function 'write-region)
               (lambda (&rest _) nil)))
      (mermaid-preview--render "graph TD\n  A --> B\n")
      (should captured-command)
      (should (cl-some (lambda (s) (string-suffix-p ".svg" s)) captured-command)))))

(ert-deftest mermaid-preview-test-render-opens-on-success ()
  "On successful exit, mermaid-preview--render calls open with the PNG path."
  (let (opened-file sentinel-fn)
    (cl-letf (((symbol-function 'make-process)
               (lambda (&rest args)
                 (setq sentinel-fn (plist-get args :sentinel))
                 ;; Return nil — process-status and process-exit-status are
                 ;; also mocked below, so the sentinel never dereferences it.
                 nil))
              ((symbol-function 'write-region)
               (lambda (&rest _) nil))
              ((symbol-function 'file-exists-p)
               (lambda (_) t))
              ((symbol-function 'call-process)
               (lambda (_prog _infile _buf _display &rest args)
                 (setq opened-file (car args)))))
      (mermaid-preview--render "graph TD\n  A --> B\n")
      ;; Simulate successful process exit by calling the sentinel directly.
      (when sentinel-fn
        (cl-letf (((symbol-function 'process-status) (lambda (_) 'exit))
                  ((symbol-function 'process-exit-status) (lambda (_) 0)))
          (funcall sentinel-fn nil "finished\n")))
      (should opened-file)
      (should (string-suffix-p ".svg" opened-file)))))

;; ── Commands ──────────────────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-block-at-point-is-interactive ()
  "mermaid-preview-block-at-point must be callable via M-x."
  (should (commandp #'mermaid-preview-block-at-point)))

(ert-deftest mermaid-preview-test-all-blocks-is-interactive ()
  "mermaid-preview-all-blocks must be callable via M-x."
  (should (commandp #'mermaid-preview-all-blocks)))

;; ── Dependency check ──────────────────────────────────────────────────────────

(ert-deftest mermaid-preview-test-check-deps-errors-on-missing-bun ()
  "mermaid-preview--check-deps signals user-error when bun is absent."
  (cl-letf (((symbol-function 'mermaid-preview--bun-available-p)
             (lambda () nil)))
    (should-error (mermaid-preview--check-deps) :type 'user-error)))

(ert-deftest mermaid-preview-test-check-deps-errors-on-missing-mmdc ()
  "mermaid-preview--check-deps signals user-error when mmdc is absent."
  (cl-letf (((symbol-function 'mermaid-preview--bun-available-p)
             (lambda () t))
            ((symbol-function 'mermaid-preview--mmdc-available-p)
             (lambda () nil)))
    (should-error (mermaid-preview--check-deps) :type 'user-error)))

(provide 'mermaid-preview-test)

;;; mermaid-preview-test.el ends here
