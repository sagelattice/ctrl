# Emacs Lisp Extension Pitfalls

Pitfalls specific to writing extensions under `lisp/extensions/`. General Elisp
pitfalls (mode map free variables, `re-search-backward` semantics) are in
`docs/elisp-pitfalls.md`.

---

**Checkdoc: message strings must start with a capital letter**

`checkdoc` enforces that strings passed to `message`, `user-error`, `error`, and
similar functions begin with a capital letter. Prefixes like `"my-pkg: something"`
fail; use `"My-pkg: something"` or restructure the message.

---

**Extension-relative paths must be captured at load time**

`load-file-name` is only non-nil during the `load` call itself. Inside function
bodies — called interactively or via `--eval` after loading — it is nil. Any
path relative to the extension directory must be captured at the top level using
a `defconst`, evaluated while the file is being loaded:

```elisp
;; Wrong — load-file-name is nil when the function is later called:
(defun my-ext-install ()
  (let ((dir (file-name-directory (or load-file-name buffer-file-name ""))))
    (shell-command (format "cd %s && bun install" dir))))

;; Correct — capture the directory once, at load time:
(defconst my-ext--dir
  (file-name-directory (or load-file-name buffer-file-name ""))
  "Directory containing my-ext.el.")

(defun my-ext-install ()
  (shell-command (format "cd %s && bun install"
                         (shell-quote-argument my-ext--dir))))
```
