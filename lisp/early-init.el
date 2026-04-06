;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; This file is loaded before the package system and GUI is initialized.
;; It's the right place for performance tuning and pre-GUI settings.
;; Keep this file minimal and focused.

;;; ─── Garbage Collection Tuning ───────────────────────────────────────────────
;;
;; The default GC threshold (800KB) causes constant GC pauses during startup
;; because package loading generates a lot of short-lived objects.
;; Set it very high during startup, then restore to a reasonable value after.

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Restore after startup is complete
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)
            (message "GC restored. Startup: %.2fs, %d GCs"
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done)))

;;; ─── Package System ───────────────────────────────────────────────────────────
;;
;; Inhibit the default package.el initialization here — we'll initialize it
;; explicitly in init.el after setting up our package archives.
;; This prevents double-initialization and shaves a few milliseconds.

(setq package-enable-at-startup nil)

;;; ─── GUI: Suppress Flash and Resize ──────────────────────────────────────────
;;
;; These suppress the brief flash of default UI before your theme loads,
;; and prevent Emacs from resizing the frame as it initializes.

(setq inhibit-redisplay t
      inhibit-message t)

(add-hook 'window-setup-hook
          (lambda ()
            (setq inhibit-redisplay nil
                  inhibit-message nil)
            (redisplay)))

;; Prevent frame resize on font/theme changes — speeds up startup on macOS
(setq frame-inhibit-implied-resize t)

;; Suppress the default startup screen
(setq inhibit-startup-screen t
      inhibit-startup-echo-area-message (user-login-name))

;;; ─── UI: Disable Toolbar/Scrollbar Early ─────────────────────────────────────
;;
;; Disabling here (rather than in init.el) prevents them from briefly
;; appearing and then disappearing — avoids a visual flicker on startup.

(when (fboundp 'menu-bar-mode)   (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(when (fboundp 'tooltip-mode)    (tooltip-mode -1))

;;; ─── File Handler Optimization ────────────────────────────────────────────────
;;
;; Temporarily disable file-name-handler-alist during startup.
;; This list is consulted on every file open; clearing it avoids overhead
;; while loading packages. Restored after startup.

(defvar my/saved-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my/saved-file-name-handler-alist)))

;;; early-init.el ends here
