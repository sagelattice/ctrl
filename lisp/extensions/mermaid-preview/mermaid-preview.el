;;; mermaid-preview.el --- Mermaid diagram preview for Markdown -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Renders Mermaid fenced code blocks as SVG files opened in the system
;; viewer (Preview.app on macOS).  Rendering is always explicit and
;; user-initiated — never triggered automatically on file open or save.
;;
;; Usage:
;;   M-x mermaid-preview-install         Install Bun and mmdc (idempotent)
;;   M-x mermaid-preview-block-at-point  Render the Mermaid block under point
;;   M-x mermaid-preview-all-blocks      Render every Mermaid block in buffer

;;; Commentary:
;; Mermaid diagrams in fenced code blocks (```mermaid ... ```) are rendered
;; on demand via the Mermaid CLI (mmdc) running under Bun.  Output is SVG,
;; opened via the macOS `open' command.  The subprocess runs asynchronously
;; so editing is never blocked.
;;
;; All managed package dependencies are declared in package.json alongside
;; this file and installed via `M-x mermaid-preview-install'.  No network
;; access occurs during rendering.

;;; Code:

;; Capture the extension directory at load time.  load-file-name is only
;; non-nil during the load call itself; using it inside function bodies
;; (called later, interactively or via --eval) returns nil.
(defconst mermaid-preview--dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Directory containing mermaid-preview.el.")

;; ── Customization ─────────────────────────────────────────────────────────────

(defgroup mermaid-preview nil
  "Mermaid diagram rendering for Markdown buffers."
  :group 'tools
  :prefix "mermaid-preview-")

(defcustom mermaid-preview-bun-executable
  (or (executable-find "bun") "bun")
  "Path to the Bun executable used to run mmdc."
  :type 'string
  :group 'mermaid-preview)

(defcustom mermaid-preview-mmdc-path
  (expand-file-name "node_modules/.bin/mmdc" mermaid-preview--dir)
  "Path to the mmdc binary installed by the local package.json."
  :type 'string
  :group 'mermaid-preview)

(defcustom mermaid-preview-timeout 30
  "Maximum seconds to wait for a single diagram to render."
  :type 'integer
  :group 'mermaid-preview)

;; ── Dependency checks ─────────────────────────────────────────────────────────

(defun mermaid-preview--bun-available-p ()
  "Return non-nil if the Bun executable is found."
  (executable-find mermaid-preview-bun-executable))

(defun mermaid-preview--mmdc-available-p ()
  "Return non-nil if the local mmdc binary is present and executable."
  (and (file-executable-p mermaid-preview-mmdc-path)
       mermaid-preview-mmdc-path))

(defun mermaid-preview--check-deps ()
  "Signal an error when required dependencies are absent.
Directs the user to run `M-x mermaid-preview-install'."
  (unless (mermaid-preview--bun-available-p)
    (user-error "Mermaid-preview: bun not found — run M-x mermaid-preview-install"))
  (unless (mermaid-preview--mmdc-available-p)
    (user-error "Mermaid-preview: mmdc not found — run M-x mermaid-preview-install")))

;; Warn on load if dependencies are absent — never signal an error.
(unless (and (mermaid-preview--bun-available-p)
             (mermaid-preview--mmdc-available-p))
  (display-warning 'mermaid-preview
                   "Dependencies missing — run M-x mermaid-preview-install"
                   :warning))

;; ── Bootstrap ─────────────────────────────────────────────────────────────────

(defun mermaid-preview-install ()
  "Install Bun (JS runtime) and mmdc (Mermaid CLI) for mermaid-preview.
This command is idempotent — safe to run multiple times.
Called automatically by install.sh; also available interactively to
repair or re-run the extension bootstrap."
  (interactive)
  (message "Mermaid-preview: installing Bun via Homebrew...")
  (shell-command "brew install bun")
  (message "Mermaid-preview: installing mmdc via bun install...")
  (shell-command (format "cd %s && bun install"
                         (shell-quote-argument mermaid-preview--dir)))
  (message "Mermaid-preview: installation complete."))

;; ── Block detection ───────────────────────────────────────────────────────────

(defconst mermaid-preview--fence-open-re
  "^\\s-*```mermaid\\s-*$"
  "Regexp matching the opening fence of a Mermaid code block.")

(defconst mermaid-preview--fence-close-re
  "^\\s-*```\\s-*$"
  "Regexp matching the closing fence of a generic code block.")

(defun mermaid-preview--block-at-point ()
  "Return (BEG END SOURCE) for the Mermaid block containing point, or nil.
BEG and END are buffer positions spanning the entire fenced block including
fence markers.  SOURCE is the diagram text between the fences."
  (save-excursion
    (let ((pos (point))
          open-beg content-beg content-end close-end)
      ;; Search backward for the opening fence.  Start from the beginning of
      ;; the next line so the entire current line is included in the search
      ;; range — re-search-backward is exclusive of the exact start position,
      ;; which would miss a fence when point is anywhere on the fence line.
      (goto-char (line-beginning-position 2))
      (when (re-search-backward mermaid-preview--fence-open-re nil t)
        (setq open-beg (point))
        (forward-line 1)
        (setq content-beg (point))
        ;; Search forward for the closing fence from content start.
        (when (re-search-forward mermaid-preview--fence-close-re nil t)
          (setq content-end (match-beginning 0))
          (setq close-end (match-end 0))
          ;; Verify point was actually inside this block.
          (when (<= open-beg pos close-end)
            (list open-beg
                  close-end
                  (buffer-substring-no-properties content-beg content-end))))))))

(defun mermaid-preview--all-blocks ()
  "Return a list of (BEG END SOURCE) for every Mermaid block in the buffer."
  (save-excursion
    (goto-char (point-min))
    (let (blocks)
      (while (re-search-forward mermaid-preview--fence-open-re nil t)
        (let ((open-beg (match-beginning 0)))
          (forward-line 1)
          (let ((content-beg (point)))
            (when (re-search-forward mermaid-preview--fence-close-re nil t)
              (let ((content-end (match-beginning 0))
                    (close-end (match-end 0)))
                (push (list open-beg
                            close-end
                            (buffer-substring-no-properties
                             content-beg content-end))
                      blocks))))))
      (nreverse blocks))))

;; ── Subprocess invocation ─────────────────────────────────────────────────────

(defun mermaid-preview--render (source)
  "Render the Mermaid SOURCE string to SVG and open it in the system viewer.
Runs mmdc asynchronously via Bun.  On success, opens the SVG with the macOS
`open' command.  On failure, reports stderr to the minibuffer.  The input
temp file is cleaned up in both cases; the output SVG is left for the viewer."
  (let* ((in-file (make-temp-file "mermaid-preview-in-" nil ".mmd"))
         (out-file (concat (file-name-sans-extension in-file) ".svg"))
         (stderr-buf (generate-new-buffer " *mermaid-preview-stderr*")))
    (write-region source nil in-file nil 'silent)
    (make-process
     :name "mermaid-preview"
     :buffer nil
     :stderr stderr-buf
     :command (list mermaid-preview-bun-executable
                    mermaid-preview-mmdc-path
                    "-i" in-file
                    "-o" out-file)
     :sentinel
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (unwind-protect
             (if (= (process-exit-status proc) 0)
                 (when (file-exists-p out-file)
                   (call-process "open" nil nil nil out-file))
               (let ((err (with-current-buffer stderr-buf
                            (buffer-string))))
                 (message "Mermaid-preview error: %s" (string-trim err))))
           (ignore-errors (delete-file in-file))
           (kill-buffer stderr-buf)))))))

;; ── Public commands ───────────────────────────────────────────────────────────

(defun mermaid-preview-block-at-point ()
  "Render the Mermaid diagram block under point and open as an SVG image."
  (interactive)
  (mermaid-preview--check-deps)
  (let ((block (mermaid-preview--block-at-point)))
    (if block
        (mermaid-preview--render (nth 2 block))
      (message "Mermaid-preview: no Mermaid block found at point."))))

(defun mermaid-preview-all-blocks ()
  "Render every Mermaid diagram block in the current buffer as SVG images."
  (interactive)
  (mermaid-preview--check-deps)
  (let ((blocks (mermaid-preview--all-blocks)))
    (if blocks
        (dolist (block blocks)
          (mermaid-preview--render (nth 2 block)))
      (message "Mermaid-preview: no Mermaid blocks found in buffer."))))

;; ── Keybindings ───────────────────────────────────────────────────────────────

(with-eval-after-load 'markdown-mode
  (define-key (symbol-value 'markdown-mode-map) (kbd "C-c C-m r")
	      #'mermaid-preview-block-at-point)
  (define-key (symbol-value 'markdown-mode-map) (kbd "C-c C-m a")
	      #'mermaid-preview-all-blocks))

;; ── Provide ───────────────────────────────────────────────────────────────────

(provide 'mermaid-preview)

;;; mermaid-preview.el ends here
