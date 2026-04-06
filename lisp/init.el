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

;; Bootstrap use-package (built into Emacs 29+; this is a no-op on 29+)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

;; Always install packages if not present — removes the need for :ensure t
;; on every declaration. Override with :ensure nil for built-in packages.
(setq use-package-always-ensure t)

;;; ─── Load Path: Your Extensions ──────────────────────────────────────────────
;;
;; Each extension lives in its own subdirectory under lisp/extensions/<name>/.
;; Add every such subdirectory to the load path so (require 'name) works.

(let ((ext-dir (expand-file-name "lisp/extensions" user-emacs-directory)))
  (dolist (subdir (directory-files ext-dir t "^[^.]"))
    (when (file-directory-p subdir)
      (add-to-list 'load-path subdir))))

;;; ─── Native Compilation: Runtime Settings ────────────────────────────────────
;;
;; early-init.el handled the compile-time flags. These are the runtime settings
;; that control how native comp behaves once Emacs is running.

(when (featurep 'native-compile)
  ;; Number of parallel workers for async native compilation.
  ;; nil = auto-detect (usually number of CPU cores / 2)
  (setq native-comp-async-jobs-number nil)

  ;; Optimization level: 0 = fastest compile, 3 = most optimized output.
  ;; 2 is a good balance for personal config.
  (setq native-opt-speed 2)

  ;; Verbosity during async compilation. 0 = silent, 3 = very noisy.
  (setq native-comp-verbose 0))

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

(setq treesit-language-source-alist
      '((clojure    "https://github.com/sogaiu/tree-sitter-clojure")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                    "master" "typescript/src")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript"
                    "master" "tsx/src")
        (json       "https://github.com/tree-sitter/tree-sitter-json")
        (css        "https://github.com/tree-sitter/tree-sitter-css")
        (bash       "https://github.com/tree-sitter/tree-sitter-bash")
        (toml       "https://github.com/ikatyang/tree-sitter-toml")
        (yaml       "https://github.com/ikatyang/tree-sitter-yaml")
        (markdown   "https://github.com/ikatyang/tree-sitter-markdown")))

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

;;; ─── Claude Integration ───────────────────────────────────────────────────────

(defun ctrl/claude ()
  "Open ansi-term at project root (or current directory) and launch claude."
  (interactive)
  (let* ((project (project-current))
         (root (if project (project-root project) default-directory))
         (default-directory root)
         (buf (ansi-term (or (getenv "SHELL") "/bin/zsh") "claude")))
    (term-send-string (get-buffer-process buf) "claude\n")))

(global-set-key (kbd "C-c a") #'ctrl/claude)

;;; ─── Flycheck: Syntax Checking ────────────────────────────────────────────────

(use-package flycheck
  :hook (prog-mode . flycheck-mode))

;;; ─── Custom Extensions Loader ────────────────────────────────────────────────
;;
;; Each extension subdirectory contains a <name>.el file that owns all logic
;; for that extension.  A subdirectory is only loaded when <name>/<name>.el
;; exists — this excludes tests/ directories and structural templates (skel).

(let ((ext-dir (expand-file-name "lisp/extensions" user-emacs-directory)))
  (dolist (subdir (directory-files ext-dir t "^[^.]"))
    (when (file-directory-p subdir)
      (let* ((name (file-name-nondirectory subdir))
             (el (expand-file-name (concat name ".el") subdir)))
        (when (file-exists-p el)
          (load el nil t))))))

;;; init.el ends here
