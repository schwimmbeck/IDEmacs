;;; init.el --- PyCharm-like Emacs setup -*- lexical-binding: t; -*-

;; Author: Dominik Schwimmbeck <dominik.schwimmbeck@tu-berlin.de>

;;; Commentary:
;; Emacs configuration tuned for an IDE workflow:
;; - project-centric editing
;; - tree/file navigation
;; - completion, diagnostics, formatting, and LSP

;;; Code:

(require 'cl-lib)
(require 'package)
(require 'python)
(require 'subr-x)
(require 'treesit nil t)

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
      read-process-output-max (* 1024 1024)
      python-indent-guess-indent-offset nil)

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
(load-theme 'modus-vivendi t)

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
  (setq projectile-known-projects
        (seq-filter #'file-directory-p projectile-known-projects))
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
  (lsp-enable-snippet nil)
  (lsp-log-io nil)
  (lsp-completion-provider :none)
  (lsp-enable-symbol-highlighting t)
  (lsp-headerline-breadcrumb-enable t)
  (lsp-idle-delay 0.2)
  (lsp-pylsp-plugins-pycodestyle-enabled nil)
  :hook ((python-mode . lsp-deferred)
         (ord-mode . lsp-deferred)))

(use-package lsp-pyright
  :after lsp-mode
  :config
  (add-to-list 'lsp-language-id-configuration '(ord-mode . "python"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection
                     (lambda ()
                       (cons (lsp-package-path 'pyright)
                             lsp-pyright-langserver-command-args)))
    :major-modes '(ord-mode)
    :server-id 'pyright-ord
    :multi-root lsp-pyright-multi-root
    :priority 2
    :initialized-fn (lambda (workspace)
                      (with-lsp-workspace workspace
                        (lsp--set-configuration
                         (make-hash-table :test 'equal))))
    :download-server-fn (lambda (_client callback error-callback _update?)
                          (lsp-package-ensure 'pyright callback error-callback))
    :notification-handlers
    (lsp-ht ((concat lsp-pyright-langserver-command "/beginProgress")
             'lsp-pyright--begin-progress-callback)
            ((concat lsp-pyright-langserver-command "/reportProgress")
             'lsp-pyright--report-progress-callback)
            ((concat lsp-pyright-langserver-command "/endProgress")
             'lsp-pyright--end-progress-callback))))
  :custom
  (lsp-pyright-typechecking-mode "off")
  (lsp-pyright-diagnostic-mode "openFilesOnly")
  (lsp-pyright-disable-tagged-hints t)
  (lsp-pyright-use-library-code-for-types t)
  (lsp-pyright-auto-search-paths t))

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
         (python (expand-file-name ".venv/bin/python" root))
         (project-subdirs
          (seq-filter
           #'file-directory-p
           (mapcar
            (lambda (name) (expand-file-name name root))
            '("src" "tests"))))
         (python-package-dirs
          (seq-filter
           #'file-directory-p
           (directory-files root t "^[[:alpha:]_][[:alnum:]_]*$"))))
    (when (file-exists-p python)
      (setq-local lsp-pyright-python-executable-cmd python))
    (setq-local lsp-pyright-extra-paths
                (vconcat
                 (delete-dups
                  (append (list root)
                          project-subdirs
                          python-package-dirs))))))

(defun my/python-mode-setup ()
  "Apply IDE-style defaults for Python buffers."
  (setq-local fill-column 88)
  (setq-local tab-width 4)
  (setq-local python-indent-offset 4)
  ;; Keep LSP for completion and navigation, but avoid Pyright's noisy project
  ;; diagnostics in dynamic codebases. Let Flycheck handle lightweight syntax
  ;; validation instead.
  (setq-local lsp-diagnostics-provider :none)
  (setq-local lsp-disabled-clients
              '(semgrep-ls ruff-lsp pylsp pyls))
  (setq-local flycheck-checker 'python-pycompile)
  (setq-local flycheck-disabled-checkers
              '(python-pylint python-flake8 python-mypy))
  (my/python-auto-venv))

(add-hook 'python-mode-hook #'my/python-mode-setup)
(add-hook 'ord-mode-hook #'my/python-mode-setup)

(defun my/run-project-tests ()
  "Run pytest for the current project."
  (interactive)
  (let ((default-directory (my/project-root)))
    (compile "pytest -q")))

(global-set-key (kbd "<f5>") #'my/run-project-tests)
(global-set-key (kbd "S-<f5>") #'recompile)

;; ---------------------------------------------------------------------------
;; ORD support
;; ---------------------------------------------------------------------------
(let ((ord-emacs-dir (expand-file-name "~/Work/workspace/syntax_highlighting_ordec/emacs/")))
  (when (file-directory-p ord-emacs-dir)
    (add-to-list 'load-path ord-emacs-dir)
    (require 'ord-mode nil t)))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ignored-local-variable-values '((version . ord1)))
 '(package-selected-packages
   '(ace-window blacken cape consult corfu flycheck lsp-pyright
				marginalia multiple-cursors orderless
				treemacs-projectile vertico))
 '(safe-local-variable-values '((version . ord2) (version . ord))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(provide 'init)
;;; init.el ends here
