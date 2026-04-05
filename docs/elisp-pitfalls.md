# Emacs Lisp Pitfalls

These are bugs that have surfaced during `./check.sh` or live use. Each entry
has a wrong pattern, a correct pattern, and the rule that catches it.

---

**Byte-compile: free variable warnings for mode maps**

`with-eval-after-load` defers execution but does not suppress byte-compilation of
the body. Referencing a mode map symbol directly (e.g. `markdown-mode-map`) causes
a free-variable warning because the compiler has not loaded the package. Use
`(symbol-value 'markdown-mode-map)` instead:

```elisp
;; Wrong — free variable warning at compile time:
(with-eval-after-load 'markdown-mode
  (define-key markdown-mode-map ...))

;; Correct:
(with-eval-after-load 'markdown-mode
  (define-key (symbol-value 'markdown-mode-map) ...))
```

---

**`re-search-backward` is exclusive of the starting position**

`re-search-backward` does not find a match whose boundary coincides with point.
When scanning for a fence or delimiter that might sit on the *current* line,
starting the search from `(point)` or `(line-end-position)` silently misses that
line. Always anchor to `(line-beginning-position 2)` (the start of the next line)
so the full current line falls inside the search range:

```elisp
;; Wrong — misses the fence when point is anywhere on the fence line:
(goto-char pos)
(re-search-backward fence-re nil t)

;; Correct — current line is fully included:
(goto-char (line-beginning-position 2))
(re-search-backward fence-re nil t)
```

Every function that uses `re-search-backward` to locate a surrounding block must
have an ERT test that places point at column 0 of the target line (the hardest
boundary case).
