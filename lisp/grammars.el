;;; grammars.el --- Tree-sitter grammar sources -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; SPDX-FileCopyrightText: 2026 Anthony Urena
;;
;; Canonical definition of `treesit-language-source-alist'.
;; Loaded by both init.el (runtime) and bootstrap.el (install-time grammar
;; compilation).  Edit this file to add or remove language grammars — the
;; change propagates to both consumers automatically.

;;; Commentary:
;; Single source of truth for the tree-sitter grammar repository list.

;;; Code:

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

(provide 'grammars)

;;; grammars.el ends here
