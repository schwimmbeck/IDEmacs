;;; init.el --- PyCharm-like Emacs setup for Python and ORDeC -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs configuration tuned for an IDE workflow:
;; - project-centric editing
;; - tree/file navigation
;; - completion, diagnostics, formatting, and LSP
;; - ORDeC as the default project on startup

;;; Code:

(require 'cl-lib)
(require 'package)
(require 'subr-x)

(defconst my/default-project
  (expand-file-name "~/Work/workspace/ordec/")
  "Project opened by default when Emacs starts without files.")

(defconst my/ordec-treesit-dir
  (expand-file-name "syntax_highlighting/tree-sitter-ord/" my/default-project)
  "Expected location of the ORDeC tree-sitter grammar.")

(defconst my/ordec-highlights-file
  (expand-file-name "queries/highlights.scm" my/ordec-treesit-dir)
  "Expected location of the ORDeC tree-sitter highlight query.")

;; Keep tabs literal by default.
(setq-default indent-tabs-mode t)
(setq-default tab-width 4)

;; Write backups and auto-saves into Emacs state instead of project directories.
(setq backup-directory-alist '(("." . "~/.emacs.d/backups"))
      auto-save-file-name-transforms '((".*" "~/.emacs.d/auto-save-list/" t))
      create-lockfiles nil)

(setq package-archives
      '(("gnu"          . "https://elpa.gnu.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; ---------------------------------------------------------------------------
;; Basic UI and editing behavior
;; ---------------------------------------------------------------------------
(setq inhibit-startup-screen t
      initial-scratch-message ""
      ring-bell-function 'ignore
      use-dialog-box nil
      frame-title-format '("%b - Emacs IDE")
      compilation-scroll-output t
      read-process-output-max (* 1024 1024))

(menu-bar-mode 1)
(tool-bar-mode -1)
(scroll-bar-mode 1)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(global-hl-line-mode 1)
(tab-bar-mode 1)
(winner-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(desktop-save-mode 1)

(setq desktop-restore-eager 10
      recentf-max-saved-items 200
      tab-bar-show 1
      tab-bar-close-button-show nil
      tab-bar-new-button-show nil)

(fset 'yes-or-no-p 'y-or-n-p)

;; ---------------------------------------------------------------------------
;; Completion and navigation
;; ---------------------------------------------------------------------------
(use-package vertico
  :init
  (vertico-mode 1))

(use-package savehist
  :init
  (savehist-mode 1))

(use-package orderless
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides
        '((file (styles partial-completion)))))

(use-package marginalia
  :init
  (marginalia-mode 1))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-x b" . consult-buffer)
         ("C-c o" . consult-outline)
         ("C-c i" . consult-imenu)
         ("C-c g" . consult-ripgrep)
         ("M-y"   . consult-yank-pop)))

(use-package corfu
  :init
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.05)
  (corfu-auto-prefix 1)
  (corfu-cycle t)
  (corfu-preview-current nil)
  (corfu-preselect 'prompt))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

(use-package ace-window
  :bind (("M-o" . ace-window)))

(global-set-key (kbd "<f12>") #'xref-find-definitions)
(global-set-key (kbd "S-<f12>") #'xref-find-references)
(global-set-key (kbd "C-/") #'comment-line)

;; ---------------------------------------------------------------------------
;; Projects and sidebar
;; ---------------------------------------------------------------------------
(use-package projectile
  :demand t
  :config
  (projectile-mode 1)
  (setq projectile-auto-discover t
        projectile-completion-system 'default
        projectile-enable-caching t
        projectile-project-search-path '("~/Work/workspace/")
        projectile-globally-ignored-directories
        '(".idea" ".git" ".venv" "__pycache__" ".pytest_cache" "htmlcov" "node_modules" "dist" "build"))
  (when (file-directory-p my/default-project)
    (projectile-add-known-project my/default-project))
  :bind-keymap ("C-c p" . projectile-command-map))

(use-package treemacs
  :bind (("C-x t t" . treemacs)
         ("M-0"     . treemacs-select-window))
  :config
  (setq treemacs-width 36
        treemacs-is-never-other-window t)
  (treemacs-follow-mode 1)
  (treemacs-project-follow-mode 1)
  (treemacs-filewatch-mode 1))

(use-package treemacs-projectile
  :after (treemacs projectile))

;; ---------------------------------------------------------------------------
;; LSP, diagnostics, formatting
;; ---------------------------------------------------------------------------
(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l")
  :custom
  (lsp-log-io nil)
  (lsp-completion-provider :none)
  (lsp-enable-symbol-highlighting t)
  (lsp-headerline-breadcrumb-enable t)
  (lsp-idle-delay 0.2)
  (lsp-pylsp-plugins-pycodestyle-enabled nil)
  :hook ((python-mode . lsp-deferred)))

(use-package lsp-pyright
  :after lsp-mode
  :custom
  (lsp-pyright-typechecking-mode "basic")
  (lsp-pyright-use-library-code-for-types t))

(use-package flycheck
  :init
  (global-flycheck-mode 1))

(use-package blacken
  :hook (python-mode . blacken-mode)
  :custom
  (blacken-line-length 88))

;; ---------------------------------------------------------------------------
;; Python workflow
;; ---------------------------------------------------------------------------
(defun my/project-root ()
  "Return the current project root or `default-directory'."
  (or (when (fboundp 'projectile-project-root)
        (ignore-errors (projectile-project-root)))
      default-directory))

(defun my/python-auto-venv ()
  "Use the current project's .venv for Pyright when available."
  (let* ((root (my/project-root))
         (python (expand-file-name ".venv/bin/python" root)))
    (when (file-exists-p python)
      (setq-local lsp-pyright-python-executable-cmd python))))

(defun my/python-mode-setup ()
  "Apply IDE-style defaults for Python buffers."
  (setq-local fill-column 88)
  (setq-local tab-width 4)
  (setq-local python-indent-offset 4)
  (my/python-auto-venv))

(add-hook 'python-mode-hook #'my/python-mode-setup)

(defun my/run-project-tests ()
  "Run pytest for the current project."
  (interactive)
  (let ((default-directory (my/project-root)))
    (compile "pytest -q")))

(global-set-key (kbd "<f5>") #'my/run-project-tests)
(global-set-key (kbd "S-<f5>") #'recompile)

;; ---------------------------------------------------------------------------
;; ORDeC support
;; ---------------------------------------------------------------------------
(defvar ord--treesit-font-lock-settings nil
  "Compiled tree-sitter font-lock settings for `ord-mode'.")

(when (boundp 'treesit-extra-load-path)
  (add-to-list 'treesit-extra-load-path my/ordec-treesit-dir))

(when (and (file-exists-p my/ordec-highlights-file)
           (fboundp 'treesit-query-compile))
  (setq ord--treesit-font-lock-settings
        (treesit-query-compile
         'ord
         (with-temp-buffer
           (insert-file-contents my/ordec-highlights-file)
           (buffer-string)))))

(define-derived-mode ord-mode prog-mode "Ord"
  "Major mode for editing ORDeC .ord files."
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local tab-width 4)
  (setq-local indent-tabs-mode t)
  (when (and (fboundp 'treesit-language-available-p)
             (treesit-language-available-p 'ord)
             ord--treesit-font-lock-settings)
    (treesit-parser-create 'ord)
    (setq-local treesit-font-lock-settings ord--treesit-font-lock-settings)
    (treesit-major-mode-setup)))

(add-to-list 'auto-mode-alist '("\\.ord\\'" . ord-mode))

;; ---------------------------------------------------------------------------
;; Default startup project
;; ---------------------------------------------------------------------------
(defun my/startup-open-default-project ()
  "Open the default project on startup when Emacs has no file arguments."
  (when (and (not noninteractive)
             (file-directory-p my/default-project)
             (null command-line-args-left)
             (not (cl-some #'buffer-file-name (buffer-list))))
    (projectile-switch-project-by-name my/default-project)
    (when (fboundp 'treemacs-add-and-display-current-project-exclusively)
      (treemacs-add-and-display-current-project-exclusively))))

(add-hook 'emacs-startup-hook #'my/startup-open-default-project)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 '(package-selected-packages
   '(ace-window blacken cape consult corfu flycheck lsp-pyright marginalia
                multiple-cursors orderless treemacs-projectile vertico))
 '(safe-local-variable-values '((version . ord2) (version . ord))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 )

(provide 'init)
;;; init.el ends here
