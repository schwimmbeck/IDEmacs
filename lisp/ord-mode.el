;;; ord-mode.el --- Major mode for the ORD hardware description language -*- lexical-binding: t; -*-

;; SPDX-FileCopyrightText: 2026 Dominik Schwimmbeck
;; SPDX-License-Identifier: Apache-2.0

;; Author: Dominik Schwimmbeck <dominik.schwimmbeck@tu-berlin.de>
;; Keywords: languages
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; ORD is the hardware description language of ORDeC
;; (https://github.com/tub-msc/ordec). It is a superset of Python, so
;; this mode derives from `python-mode' and follows the design of
;; ORDeC's other editor packages (support/editors/ in the ORDeC
;; repository): only the ORD delta is maintained on top of the editor's
;; existing Python support. The delta covers:
;;
;; - cell declarations (cell Name:)
;; - viewgen declarations (viewgen name(params) -> Type:)
;; - node statements (output y:, Nmos(w=4u, l=400n) m1:,
;;   anonymous LayoutRect r:, bodyless Net vdd)
;; - path/net declarations
;; - the connection operator -- and the constrain operator !
;; - SI-suffixed numbers (100n, 3.14u) and parameter access ($param)
;;
;; Like the Sublime and VS Code packages, this layer is regex based.
;; Semantic features (diagnostics, completion, navigation, rename,
;; semantic tokens, inlay hints) come from ORDeC's ordec-lsp language
;; server; see the IDEmacs init.el for the lsp-mode client.

;;; Code:

(require 'python)

(defconst ord-mode--soft-keywords
  '("cell" "viewgen" "path" "net" "anonymous" "match" "case" "type")
  "Soft keywords that never start a node statement kind.
Mirrors the exclusion list of the other ORDeC editor grammars.")

(defconst ord-mode--python-keywords
  '("and" "as" "assert" "async" "await" "break" "class" "continue"
    "def" "del" "elif" "else" "except" "finally" "for" "from" "global"
    "if" "import" "in" "is" "lambda" "nonlocal" "not" "or" "pass"
    "raise" "return" "try" "while" "with" "yield" "None" "True" "False")
  "Python keywords, excluded as node statement kinds like in ord.lark.")

(defconst ord-mode--node-statement-regexp
  (concat
   ;; Statement position: only indentation (and possibly the anonymous
   ;; keyword, fontified by its own rule) before the kind.
   "^\\s-*\\(?:\\_<anonymous\\_>\\s-+\\)?"
   ;; Kind: dotted identifiers (Nmos, lib.Nmos) with optional
   ;; constructor arguments, one paren nesting level deep
   ;; (Nmos(w=4u, l=400n) m1:). Subscripted kinds like rows[i] and
   ;; deeper nesting are left to the language server.
   "\\(\\_<[[:alpha:]_][[:alnum:]_]*\\(?:\\s-*\\.\\s-*[[:alpha:]_][[:alnum:]_]*\\)*\\)"
   "\\(?:([^()\n]*\\(?:([^()\n]*)[^()\n]*\\)*)\\)?"
   ;; Target: dotted identifiers (m1, ring.vx).
   "\\s-+\\([[:alpha:]_][[:alnum:]_]*\\(?:\\s-*\\.\\s-*[[:alpha:]_][[:alnum:]_]*\\)*\\)"
   ;; Terminator: block colon, further bodyless targets, or statement end.
   "\\s-*\\(?::\\|,\\|;\\|#\\|$\\)")
  "Regexp for node statements; group 1 is the kind, group 2 the target.")

(defun ord-mode--match-node-statement (limit)
  "Search for the next node statement before LIMIT.
Emacs regexps have no lookahead, so the keyword exclusions that the
other ORDeC editor grammars express inline are applied here after
matching. Returns non-nil and sets the match data on success."
  (let (found)
    (while (and (not found)
                (re-search-forward ord-mode--node-statement-regexp limit t))
      ;; The kind may be dotted with spaces around the dots, so a keyword
      ;; can head a longer match (from . import a). Exclude on the first
      ;; identifier, like the lookahead in the other editor grammars. A
      ;; keyword target rejects expression continuation lines such as
      ;; "isinstance(x, y) and". save-match-data keeps the string-match
      ;; from clobbering the buffer match data that font-lock consumes.
      (let* ((kind (match-string-no-properties 1))
             (target (match-string-no-properties 2))
             (head (save-match-data
                     (substring kind 0 (string-match "[^[:alnum:]_]" kind)))))
        (unless (or (member head ord-mode--python-keywords)
                    (member head ord-mode--soft-keywords)
                    (member target ord-mode--python-keywords))
          (setq found t))))
    found))

(defun ord-mode--match-constrain (limit)
  "Match the next constrain operator ! before LIMIT, but not !=.
A matcher function instead of \"\\\\(!\\\\)[^=]\" so the character after
! is not consumed: ! at end of buffer and consecutive !! both fontify."
  (let (found)
    (while (and (not found) (search-forward "!" limit t))
      (unless (eq (char-after) ?=)
        (setq found t)))
    found))

(defconst ord-mode-font-lock-keywords
  '(;; cell is a soft keyword: only a declaration when followed by a
    ;; name and colon (celldef has no superclass list).
    ("\\_<\\(cell\\)\\s-+\\([[:alpha:]_][[:alnum:]_]*\\)\\s-*:"
     (1 font-lock-keyword-face) (2 font-lock-type-face))
    ;; viewgen is a soft keyword: only a declaration when a name
    ;; follows (parameter list and return arrow may still be missing
    ;; while typing).
    ("\\_<\\(viewgen\\)\\s-+\\([[:alpha:]_][[:alnum:]_]*\\)"
     (1 font-lock-keyword-face) (2 font-lock-function-name-face))
    ;; path/net are soft keywords: a target name must follow (net = 5
    ;; stays an ordinary assignment) and the match is anchored to
    ;; statement position.
    ("\\(?:^\\|[;:]\\)\\s-*\\(\\_<\\(?:path\\|net\\)\\_>\\)\\s-+[[:alpha:]_]"
     (1 font-lock-keyword-face))
    ;; anonymous node statements: anonymous LayoutRect r:
    ("^\\s-*\\(\\_<anonymous\\_>\\)\\s-+[[:alpha:]_]"
     (1 font-lock-keyword-face))
    ;; Node statements, including after an anonymous prefix.
    (ord-mode--match-node-statement
     (1 font-lock-type-face) (2 font-lock-variable-name-face))
    ;; Parameter access: $param, .$param, t.$param
    ("\\(\\$[[:alpha:]_][[:alnum:]_]*\\)" (1 font-lock-variable-name-face))
    ;; SI-suffixed numbers: 100n, 3.14u, 1e-3k
    ("\\_<\\([0-9][0-9_]*\\(?:\\.[0-9_]*\\)?\\(?:[eE][-+]?[0-9_]+\\)?\\)\\([afpnumkMGT]\\)\\_>"
     (1 font-lock-constant-face) (2 font-lock-constant-face))
    ;; Connection operator: a -- b
    ("--" . font-lock-keyword-face)
    ;; Constrain operator, but not !=
    (ord-mode--match-constrain (0 font-lock-keyword-face)))
  "Font-lock rules for the ORD constructs on top of Python.
None of the rules override existing fontification, so strings and
comments always win. The rules are prepended to the inherited Python
rules so that the ORD operators beat Python's operator fontification.")

;;;###autoload
(define-derived-mode ord-mode python-mode "Ord"
  "Major mode for ORD, the hardware description language of ORDeC.

ORD is a superset of Python: editing behavior is inherited from
`python-mode' and the ORD-specific constructs are added as a
font-lock layer. Semantic support comes from the ordec-lsp
language server via `lsp-mode'."
  (font-lock-add-keywords nil ord-mode-font-lock-keywords))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ord\\'" . ord-mode))

(provide 'ord-mode)
;;; ord-mode.el ends here
