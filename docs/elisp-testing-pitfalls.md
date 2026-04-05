# Emacs Lisp Testing Pitfalls

Pitfalls specific to writing ERT tests for files in `lisp/` and
`lisp/extensions/`. General Elisp pitfalls are in `docs/elisp-pitfalls.md`.
Extension-specific pitfalls are in `docs/elisp-extension-pitfalls.md`.

---

**Entry-point functions must be called via `-f`, not executed at load time**

Files loaded with `emacs --batch -l foo.el -l foo-test.el -f ert-run-tests-batch-and-exit`
must be side-effect-free on load. Top-level calls that invoke production logic
run before the test file is loaded — tests then run against already-modified
state, and any errors abort before ERT starts. Wrap all entry-point logic in a
named function invoked via `-f`:

```elisp
;; Wrong — runs immediately on -l, before foo-test.el is loaded:
(verify-features)
(config-scaffold)

;; Correct — called explicitly via -f foo-run:
(defun foo-run ()
  (verify-features)
  (config-scaffold)
  ...)
```

Shell invocation:
```bash
emacs --batch -l lisp/foo.el -f foo-run
```

---

**Use `defvar` for variables that must be visible across loaded files**

Test fixtures that set a flag from inside a dynamically loaded file require
`defvar` (dynamic binding). A `let`-bound variable is lexically scoped to its
form; `setq` from a separately-loaded file cannot reach it.

```elisp
;; Wrong — foo-install's setq cannot reach a let-binding in the test file:
(let ((called nil))
  (my-install-extensions)
  (should called))

;; Correct — defvar declares a dynamic variable; setq in foo.el reaches it:
(defvar my-test--install-called nil)
...
(setq my-test--install-called nil)
(my-install-extensions)
(should my-test--install-called)
```

---

**Mock `message` to suppress Emacs-internal noise**

`cl-letf` mocking of production logging functions does not suppress `message`
calls from Emacs internals (e.g. `sh-mode` initialization, `indent-region`
progress reporters). Mock `message` itself inside the silencing macro:

```elisp
(defmacro my-test--silently (&rest body)
  `(cl-letf (((symbol-function 'my--ok)   #'ignore)
             ((symbol-function 'my--fail) (lambda (&rest _) ...))
             ((symbol-function 'message)  #'ignore))  ; suppresses internals
     ,@body))
```

Note: `inhibit-message` does **not** suppress batch-mode stderr in Emacs 30.
`cl-letf` on `message` is the correct approach.

---

**Use `with-temp-buffer` over `find-file-noselect` when major modes are unwanted**

`find-file-noselect` activates the file's major mode. For `.sh` files this
triggers `sh-mode`, which emits "Setting up indent for shell type bash" and
two follow-up lines. When reading or rewriting a file purely for content, use
`with-temp-buffer` + `insert-file-contents` + `write-region` instead:

```elisp
;; Wrong — triggers sh-mode, emits indent-setup messages to stderr:
(with-current-buffer (find-file-noselect file t)
  (insert "# header\n")
  (save-buffer))

;; Correct — no major mode, no messages:
(with-temp-buffer
  (insert-file-contents file)
  (goto-char (point-min))
  (insert "# header\n")
  (write-region (point-min) (point-max) file nil 'silent))
```
