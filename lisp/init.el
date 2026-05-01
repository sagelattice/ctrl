;;; init.el --- Main Emacs configuration -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; A clean, well-commented starting point focused on:
;;   - Native compilation configuration
;;   - Tree-sitter structural editing and highlighting
;;   - Clojure/CIDER development
;;   - A foundation for custom Elisp extensions
;;
;; Directory layout expected by this config:
;;
;;   ~/.config/emacs/
;;   ├── early-init.el       (loaded before this file)
;;   ├── init.el             (this file)
;;   └── lisp/
;;       └── extensions/
;;           └── <name>/
;;               ├── <name>.el
;;               └── tests/
;;                   └── <name>-test.el

;;; ─── Startup Progress ────────────────────────────────────────────────────────
;;
;; early-init.el suppresses redisplay and messages during startup to prevent
;; UI flicker.  On a first boot the screen stays blank while packages download.
;; This helper temporarily lifts both inhibitions so the user can see what's
;; happening without giving up the flicker-free experience on subsequent boots.

(defun ctrl--progress (fmt &rest args)
  "Show FMT+ARGS as a progress message even during inhibited startup.
Temporarily lifts `inhibit-redisplay' and `inhibit-message', emits the
message, and forces an immediate redisplay."
  (let ((inhibit-redisplay nil)
        (inhibit-message nil))
    (message "[ctrl] %s" (apply #'format fmt args))
    (redisplay t)))

;;; ─── Package Management ───────────────────────────────────────────────────────

(require 'package)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/packages/")
        ("melpa"  . "https://melpa.org/packages/")))

;; Prefer MELPA-stable for production packages; override per-package as needed.
(setq package-archive-priorities
      '(("gnu"    . 10)
        ("nongnu" . 8)
        ("melpa"  . 5)))

(package-initialize)

;; On first boot, package-archive-contents is empty — fetch archive metadata
;; before use-package tries to install anything.
(when (null package-archive-contents)
  (ctrl--progress "Refreshing package archives (first boot)...")
  (package-refresh-contents))

(require 'use-package)

;; Always install packages if not present — removes the need for :ensure t
;; on every declaration. Override with :ensure nil for built-in packages.
(setq use-package-always-ensure t)

;;; ─── Load Path: Your Extensions ──────────────────────────────────────────────
;;
;; Each extension lives in its own subdirectory under lisp/extensions/<name>/.
;; Add every such subdirectory to the load path so (require 'name) works.

(load (expand-file-name "lisp/ctrl-source" user-emacs-directory) nil t)

(dolist (dir (ctrl-source--extension-dirs
              (expand-file-name "lisp" user-emacs-directory)))
  (add-to-list 'load-path dir))

;;; ─── Tree-Sitter: Grammar Sources ────────────────────────────────────────────
;;
;; Register grammar repositories. Emacs will fetch and compile these on demand.
;; To install a grammar: M-x treesit-install-language-grammar RET <language> RET
;;
;; To install all at once, evaluate:
;;   (mapc #'treesit-install-language-grammar
;;         (mapcar #'car treesit-language-source-alist))
;;
;; Only needs to be done once per machine (grammars persist in tree-sitter/).
;; The canonical grammar list lives in lisp/grammars.el.

(load (expand-file-name "lisp/grammars" user-emacs-directory))

;;; ─── Tree-Sitter: Mode Remapping ─────────────────────────────────────────────
;;
;; Remap traditional major modes to their tree-sitter equivalents.
;; Each -ts-mode uses the parse tree instead of regex for font-lock and indent.
;;
;; Add a language here only after installing its grammar above.

(setq major-mode-remap-alist
      '((python-mode     . python-ts-mode)
        (javascript-mode . js-ts-mode)
        (js-json-mode    . json-ts-mode)
        (css-mode        . css-ts-mode)
        (bash-mode       . bash-ts-mode)
        (sh-mode         . bash-ts-mode)))

;; Note: Clojure does not yet have a built-in -ts-mode in Emacs.
;; clojure-mode from MELPA handles Clojure highlighting well without tree-sitter.
;; A clojure-ts-mode package exists on MELPA if you want to experiment with it.

;;; ─── Theme ────────────────────────────────────────────────────────────────────

(ctrl--progress "Loading theme...")
(load-theme 'modus-vivendi :no-confirm)

;;; ─── Core UI ──────────────────────────────────────────────────────────────────

;; Line numbers in programming modes
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Highlight the current line
(global-hl-line-mode 1)

;; Show matching parens immediately
(setq show-paren-delay 0)
(show-paren-mode 1)

;; Column numbers in the modeline
(column-number-mode 1)

;; Wrap long lines visually (not physically)
(global-visual-line-mode 1)

;; Font — set to something available on macOS; change to taste
;; Recommended: Berkeley Mono, JetBrains Mono, or Iosevka
(when (display-graphic-p)
  (set-face-attribute 'default nil
                      :family "Menlo"  ; macOS default monospace
                      :height 140))    ; 14pt

;;; ─── Core Editing Behavior ────────────────────────────────────────────────────

;; Spaces over tabs
(setq-default indent-tabs-mode nil
              tab-width 2)

;; Delete selected text on typing (standard behavior in most editors)
(delete-selection-mode 1)

;; Scroll one line at a time rather than jumping half a screen
(setq scroll-step 1
      scroll-conservatively 10000
      scroll-margin 3)

;; Save cursor position between sessions
(save-place-mode 1)

;; Remember recently opened files
(recentf-mode 1)
(setq recentf-max-menu-items 25
      recentf-max-saved-items 100)

;; Auto-revert buffers when files change on disk (good for git)
(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)

;; Confirm before exiting with unsaved buffers
(setq confirm-kill-emacs 'y-or-n-p)

;;; ─── Files and Backups ────────────────────────────────────────────────────────
;;
;; Keep backup and autosave files in a central location rather than
;; littering your project directories with ~ files.

(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" user-emacs-directory)))
      backup-by-copying t
      version-control t
      kept-new-versions 6
      kept-old-versions 2
      delete-old-versions t)

(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" user-emacs-directory) t)))

;; custom-set-variables lives in a separate file to keep init.el clean
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;;; ─── Completion ───────────────────────────────────────────────────────────────
;;
;; Vertico + Orderless + Marginalia is a lightweight, composable completion
;; stack. All three are actively maintained and work well together.

;; Vertico: vertical completion UI in the minibuffer
(use-package vertico
  :init (vertico-mode 1)
  :custom (vertico-cycle t))

;; Orderless: space-separated fuzzy matching (type parts of a name in any order)
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Marginalia: rich annotations (docstrings, keybindings) in completion lists
(use-package marginalia
  :init (marginalia-mode 1))

;; Corfu: in-buffer completion popup (replaces company for most cases)
(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  :init (global-corfu-mode 1))

;;; ─── Which-Key ────────────────────────────────────────────────────────────────
;;
;; Shows available keybindings after a prefix. Essential while learning
;; your own config and invaluable for navigating CIDER's keymap.

(use-package which-key
  :init (which-key-mode 1)
  :custom (which-key-idle-delay 0.5))

;;; ─── Project Management ───────────────────────────────────────────────────────

;; project.el is built-in and sufficient for most workflows
(setq project-switch-commands
      '((project-find-file "Find file" "f")
        (project-find-regexp "Find regexp" "g")
        (project-dired "Dired" "d")
        (project-vc-dir "VC-Dir" "v")
        (project-shell "Shell" "s")))

;;; ─── Git Integration ──────────────────────────────────────────────────────────

(use-package magit
  :bind ("C-x g" . magit-status))

;;; ─── Structural Editing: Paredit ──────────────────────────────────────────────
;;
;; Paredit keeps your s-expressions balanced. Essential for Clojure.
;; Every open paren has a matching close; you can't accidentally break structure.

(use-package paredit
  :hook ((clojure-mode       . enable-paredit-mode)
         (clojure-ts-mode    . enable-paredit-mode)
         (emacs-lisp-mode    . enable-paredit-mode)
         (lisp-mode          . enable-paredit-mode)
         (lisp-interaction-mode . enable-paredit-mode)
         (ielm-mode          . enable-paredit-mode)
         (eval-expression-minibuffer-setup . enable-paredit-mode)))

;;; ─── Rainbow Delimiters ───────────────────────────────────────────────────────
;;
;; Color-codes matching parens by nesting depth. Makes deep Clojure forms
;; much easier to read at a glance.

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;;; ─── Clojure ──────────────────────────────────────────────────────────────────

(use-package clojure-mode
  :mode (("\\.clj\\'"  . clojure-mode)
         ("\\.cljs\\'" . clojurescript-mode)
         ("\\.cljc\\'" . clojurec-mode)
         ("\\.edn\\'"  . clojure-mode)))

;; Optional: tree-sitter-based Clojure mode (more accurate highlighting)
;; Uncomment after installing the clojure grammar via treesit-install-language-grammar
;; (use-package clojure-ts-mode)

;;; ─── CIDER ────────────────────────────────────────────────────────────────────
;;
;; CIDER is the Clojure Interactive Development Environment.
;; The key bindings below are the ones you'll use most frequently.
;;
;; Essential bindings (all in clojure-mode buffers):
;;   C-c C-k   → compile/load buffer
;;   C-c C-e   → eval expression before point
;;   C-c C-z   → switch to REPL
;;   C-c C-d d → show documentation
;;   C-c M-j   → jack-in (start a REPL for this project)

(use-package cider
  :hook ((cider-repl-mode . paredit-mode)
         (cider-repl-mode . rainbow-delimiters-mode))
  :custom
  ;; Show results inline in the buffer rather than only in the minibuffer
  (cider-result-overlay-position 'at-point)
  ;; Don't prompt to save files before eval — just do it
  (cider-save-file-on-load t)
  ;; Use a pretty printer for REPL output
  (cider-repl-use-pretty-printing t)
  ;; Clojure docs in the eldoc system (shown in minibuffer as you type)
  (cider-eldoc-display-for-symbol-at-point t)
  ;; Keep this many items in REPL history
  (cider-repl-history-size 1000)
  ;; Where to store REPL history between sessions
  (cider-repl-history-file
   (expand-file-name "cider-repl-history" user-emacs-directory)))

;;; ─── Elisp Development ────────────────────────────────────────────────────────
;;
;; These settings improve the experience of writing Emacs Lisp —
;; which you'll be doing a lot of in the Claude collaboration workflow.

;; Eldoc shows docstrings for the function at point in the minibuffer
(add-hook 'emacs-lisp-mode-hook #'eldoc-mode)

;; Highlight elisp symbols that are defined elsewhere in your session
(use-package highlight-defined
  :hook (emacs-lisp-mode . highlight-defined-mode))

;; Inline evaluation results (like CIDER's overlay, but for Elisp)
(use-package eros
  :hook (emacs-lisp-mode . eros-mode))

;; Useful keybindings for Elisp development
(define-key emacs-lisp-mode-map (kbd "C-c C-k")
  (lambda ()
    (interactive)
    (save-buffer)
    (load-file buffer-file-name)
    (message "Loaded: %s" buffer-file-name)))


;;; ─── Flycheck: Syntax Checking ────────────────────────────────────────────────

(use-package flycheck
  :hook (prog-mode . flycheck-mode))

;;; ─── Markdown ─────────────────────────────────────────────────────────────────
;;
;; markdown-mode provides syntax highlighting, structure navigation, and
;; preview support for Markdown files.  Code blocks are fontified using
;; the native major mode for each language fence.

(use-package markdown-mode
  :mode (("\\.md\\'"       . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :custom
  (markdown-fontify-code-blocks-natively t))

;;; ─── Rust ─────────────────────────────────────────────────────────────────────
;;
;; rust-ts-mode is built into Emacs 29+ and uses the tree-sitter grammar for
;; accurate highlighting, indentation, and imenu.  eglot (also built-in)
;; connects to rust-analyzer for completion and diagnostics.
;;
;; Prerequisites (run once): brew install rustup && rustup-init && rustup component add rust-analyzer

(unless (executable-find "rustup")
  (display-warning 'ctrl "rustup not found — Rust development unavailable" :warning))

(use-package rust-ts-mode
  :ensure nil
  :mode "\\.rs\\'"
  :hook (rust-ts-mode . eglot-ensure))

;;; ─── OCaml ────────────────────────────────────────────────────────────────────
;;
;; tuareg: major mode for .ml/.mli/.mly/.mll files.
;; merlin: IDE layer — type-at-point (C-c C-t), jump to definition (C-c C-l),
;;         and completion via merlin-capf, picked up automatically by corfu.
;;
;; Prerequisites (run once): brew install opam && opam init && opam install merlin

(unless (executable-find "opam")
  (display-warning 'ctrl "opam not found — OCaml development unavailable" :warning))

(use-package tuareg
  :mode (("\\.ml[ily]?\\'" . tuareg-mode)
         ("\\.topml\\'"    . tuareg-mode)))

(use-package merlin
  :hook (tuareg-mode . merlin-mode)
  :custom
  (merlin-command 'opam))

;;; ─── Custom Extensions Loader ────────────────────────────────────────────────
;;
;; Each extension subdirectory contains a <name>.el file that owns all logic
;; for that extension.  A subdirectory is only loaded when <name>/<name>.el
;; exists — this excludes tests/ directories and structural templates (skel).

(dolist (dir (ctrl-source--extension-dirs
              (expand-file-name "lisp" user-emacs-directory)))
  (when-let ((el (ctrl-source--extension-el dir)))
    (ctrl--progress "Loading extension: %s" (file-name-nondirectory dir))
    (load el nil t)))

;;; init.el ends here
