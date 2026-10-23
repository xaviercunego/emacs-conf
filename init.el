;; PERFORMANCE ;;

;; Reduce GC-induced stutter. With the default 800KB threshold, a long-running
;; daemon (many buffers = large heap) pauses ~50ms per collection = dropped
;; frames while scrolling/opening files. Collect far less often instead.
(setq gc-cons-threshold (* 100 1024 1024))     ;; 100 MB
(setq inhibit-compacting-font-caches t)        ;; Don't recompact font caches on GC (icon/glyph jank)
(setq read-process-output-max (* 1 1024 1024)) ;; 1 MB — smoother LSP (eglot) throughput

;; CUSTOM FUNCTIONS ;;

(defun copy-to-clipboard ()
  (interactive)
  (if (display-graphic-p)
      (progn
	(message "Yanked region to clipboard!")
	(call-interactively 'clipboard-kill-ring-save)
	)
    (if (region-active-p)
	(progn
          ;; Wayland session: use wl-copy (install with: sudo pacman -S wl-clipboard)
          (shell-command-on-region (region-beginning) (region-end) "wl-copy")
          (message "Yanked region to clipboard!")
          (deactivate-mark))
      (message "No region active; can't yank to clipboard!")))
  )

(defun paste-from-clipboard ()
  (interactive)
  (if (display-graphic-p)
      (clipboard-yank)
    ;; Wayland session: use wl-paste (install with: sudo pacman -S wl-clipboard)
    (insert (shell-command-to-string "wl-paste -n"))
    )
)

(global-set-key [f8] 'copy-to-clipboard)
(global-set-key [f9] 'paste-from-clipboard)

;; CUSTOM BINDING ;;

(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "C-c t") 'vterm)
(global-set-key (kbd "C-c r") 'revert-buffer)
(global-set-key (kbd "C-c m l") 'magit-log-buffer-file)
(global-set-key (kbd "C-c m b") 'magit-blame-addition)
(global-set-key (kbd "C-c s") 'projectile-ripgrep)
(global-set-key (kbd "C-c f") 'projectile-find-file)
(global-set-key (kbd "C-c d") 'ranger)

;; Bind Ctl + Alt + Arrows for Window Movement
(global-set-key (kbd "C-M-<left>")  'windmove-left)
(global-set-key (kbd "C-M-<right>") 'windmove-right)
(global-set-key (kbd "C-M-<up>")    'windmove-up)
(global-set-key (kbd "C-M-<down>")  'windmove-down)

;; GENERAL CUSTOM ;;

(setq select-enable-clipboard t)  ;; Use the system clipboard (was deprecated x-select-enable-clipboard)

(setq inhibit-startup-message t)  ;; Disable start-up message

;; Performance optimizations for better terminal rendering
(setq redisplay-skip-fontification-on-input t)  ;; Skip fontification during fast input
(setq fast-but-imprecise-scrolling t)           ;; Faster scrolling
(setq jit-lock-defer-time 0)                    ;; Immediate syntax highlighting

(scroll-bar-mode -1)        ; Disable visible scrollbar
(tool-bar-mode -1)          ; Disable the toolbar
(tooltip-mode -1)           ; Disable tooltips
(set-fringe-mode 10)        ; Give some breathing room

(menu-bar-mode -1)          ; Disable the menu bar

(setq column-number-mode t) ; Emable column number display

(setq visible-bell t)  ;; Set up the visible bell

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)  ;; Make ESC quit prompts

;; Redirect backup files (~/.Trash did not exist on Manjaro, so backups were failing)
(setq backup-directory-alist '((".*" . "~/.emacs.d/backups/")))

;; Redirect auto-save files
(setq auto-save-file-name-transforms '((".*" "~/.emacs.d/backups/" t)))

;; Disable lock files
(setq create-lockfiles nil)

;; Scroll line by line
(setq scroll-step 1
      scroll-margin 3
      scroll-conservatively 10000)

;; Set shortcuts for scrolling the buffer without moving the cursor
(global-set-key (kbd "M-<down>") (lambda () (interactive) (scroll-up-line)))
(global-set-key (kbd "M-<up>") (lambda () (interactive) (scroll-down-line)))

;; Set the font size
(set-face-attribute 'default nil :height 115)

;; Always active winner mode
(winner-mode 1)

;; Remove the OS title bar at the top of Emacs
(add-to-list 'default-frame-alist '(undecorated . t))

;; Save all open buffers
(desktop-save-mode 1)
(setq desktop-save 'if-exists) ;; Only save if a desktop session already exists
(add-hook 'kill-emacs-hook #'desktop-save-in-desktop-dir) ;; Auto-save before shutdonwn

;; Run the server INSIDE this GUI Emacs (not a headless `emacs --daemon`).
;; `emacsclient` then opens files in this fluent, correctly-themed window.
;; Headless daemon frames render less smoothly and load the theme before any
;; GUI frame exists (washed-out colors), which is why we avoid it.
(require 'server)
(unless (server-running-p)
  (server-start))

;; Prevent splitting windows for projectile-ripgrep results
(add-to-list 'display-buffer-alist
             '("\\*ripgrep-search\\*"
               (display-buffer-reuse-window display-buffer-same-window)))


;; TREE-SITTER (built into Emacs 30) ;;

;; Where to fetch grammars from. Install them once with:
;;   M-x treesit-install-language-grammar  (needs gcc, which you have)
;; or run the batch installer below via: M-x my/treesit-install-all
(setq treesit-language-source-alist
      '((c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (bash       "https://github.com/tree-sitter/tree-sitter-bash")
        (json       "https://github.com/tree-sitter/tree-sitter-json")
        (yaml       "https://github.com/tree-sitter-grammars/tree-sitter-yaml")
        (cmake      "https://github.com/uyha/tree-sitter-cmake")
        (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile")))

(defun my/treesit-install-all ()
  "Install every grammar in `treesit-language-source-alist' that is missing."
  (interactive)
  (dolist (lang (mapcar #'car treesit-language-source-alist))
    (unless (treesit-language-available-p lang)
      (treesit-install-language-grammar lang))))

;; Prefer tree-sitter major modes, but ONLY when the grammar is actually
;; installed — otherwise opening the file throws "Tree-sitter for X isn't
;; available". Install grammars with M-x my/treesit-install-all, then restart.
(dolist (entry '((c-mode       c      c-ts-mode)
                 (c++-mode     cpp    c++-ts-mode)
                 (python-mode  python python-ts-mode)
                 (sh-mode      bash   bash-ts-mode)
                 (json-mode    json   json-ts-mode)
                 (js-json-mode json   json-ts-mode)
                 (cmake-mode   cmake  cmake-ts-mode)))
  (when (treesit-language-available-p (nth 1 entry))
    (add-to-list 'major-mode-remap-alist (cons (nth 0 entry) (nth 2 entry)))))

;; YAML has no classic built-in mode; use yaml-ts-mode only if its grammar exists.
(when (treesit-language-available-p 'yaml)
  (add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode)))


;; PACKAGE MANAGEMENT ;;

(require 'package)

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("org" . "https://orgmode.org/elpa/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; Initialize use-package on non-Linux platforms
(unless (package-installed-p 'use-package)
  (package-install 'use-package))


(require 'use-package)
(setq use-package-always-ensure t)


;; PACKAGES ;;

(use-package ivy
  :diminish
  :bind (("C-s" . swiper)
         :map ivy-minibuffer-map
         ("TAB" . ivy-alt-done)
         ("C-l" . ivy-alt-done)
         ("C-j" . ivy-next-line)
         ("C-k" . ivy-previous-line)
         :map ivy-switch-buffer-map
         ("C-k" . ivy-previous-line)
         ("C-l" . ivy-done)
         ("C-d" . ivy-switch-buffer-kill)
         :map ivy-reverse-i-search-map
         ("C-k" . ivy-previous-line)
         ("C-d" . ivy-reverse-i-search-kill))
  :config
  (ivy-mode 1))

(use-package counsel
  :bind (("C-M-j" . 'counsel-switch-buffer)
	 ("M-x" . counsel-M-x)
         ("C-x b" . counsel-switch-buffer)
         ("C-x C-f" . counsel-find-file)

         :map minibuffer-local-map
         ("C-r" . 'counsel-minibuffer-history))
  :custom
  (counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
  :config
  (counsel-mode 1)
  (setq ivy-initial-inputs-alist nil)) ;; Don't start searches with ^

(use-package doom-modeline
  :init (doom-modeline-mode 1))

(use-package doom-themes
  :config
  ;; Global settings (defaults)
  (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
        doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (load-theme 'doom-one t)

  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (all-the-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (setq doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

;; Markdown files syntax mode
(use-package markdown-mode
  :mode ("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown"))

;; vterm configuration with directory tracking
(use-package vterm
  :config
  ;; Shell configuration
  (setq vterm-shell "/bin/zsh")

  ;; Performance optimizations
  (setq vterm-max-scrollback 5000)
  (setq vterm-timer-delay 0.01)
  (setq vterm-always-compile-module t)
  (setq vterm-buffer-name-string "vterm %s")
  (setq vterm-copy-exclude-prompt t)
  (setq vterm-kill-buffer-on-exit t)
  (setq vterm-ignore-blink-cursor t)

  ;; Enable copy mode keybindings
  (define-key vterm-mode-map (kbd "C-c C-t") 'vterm-copy-mode)
  (define-key vterm-copy-mode-map (kbd "C-c C-t") 'vterm-copy-mode)

  ;; Allow M-w to work in vterm by entering copy mode temporarily
  (define-key vterm-mode-map (kbd "M-w")
    (lambda ()
      (interactive)
      (if (region-active-p)
          (progn
            (kill-ring-save (region-beginning) (region-end))
            (deactivate-mark))
        (message "No region selected"))))

  ;; Hook to optimize vterm buffers
  (add-hook 'vterm-mode-hook
            (lambda ()
              ;; Disable line numbers if enabled globally
              (when (fboundp 'display-line-numbers-mode)
                (display-line-numbers-mode -1))
              ;; Disable unnecessary minor modes that slow down rendering
              (setq-local scroll-margin 0)
              (setq-local scroll-conservatively 101)
              (setq-local scroll-preserve-screen-position t))))

;; Claude Code integration (https://github.com/stevemolitor/claude-code.el)
(use-package claude-code
  :vc (:url "https://github.com/stevemolitor/claude-code.el" :rev :newest)
  :init
  ;; Reuse the already-compiled vterm backend instead of the default 'eat
  (setq claude-code-terminal-backend 'vterm)
  :config
  (claude-code-mode)
  :bind-keymap ("C-c c" . claude-code-command-map))

;; Save/restore vterm buffers with desktop-save-mode (~/.emacs.d/lisp/vterm-desktop.el).
;; Every vterm comes back in its working directory; vterms running an
;; interactive Claude Code session get `claude --resume <id>' typed in.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'vterm-desktop)

(use-package which-key
  :init (which-key-mode))

(use-package ivy-rich
  :config
  (ivy-rich-mode 1))  ;; Enables ivy-rich mode

(use-package gitlab-ci-mode)
(use-package dts-mode)
(use-package gnu-elpa-keyring-update)

(use-package projectile
  :diminish projectile-mode
  :config (projectile-mode)
  :demand t
  :bind ("C-M-p" . projectile-find-file)
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :init
  (when (file-directory-p "~/etc-project/cccp-yocto-image/cccp-layers/meta-cccp")
    (setq projectile-project-search-path '("etc-project/cccp-yocto-image/cccp-layers/meta-cccp")))
  (setq projectile-switch-project-action #'projectile-dired))

(use-package magit
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))
  (add-hook 'magit-log-mode-hook 'hl-line-mode)

(use-package dockerfile-mode
  :mode "Dockerfile\\'")

(use-package ranger
  :ensure t
  :config
  (ranger-override-dired-mode t))

;; CODE INTELLIGENCE ;;

;; In-buffer completion popup (the company-mode alternative, minimal & fast)
(use-package corfu
  :init
  (global-corfu-mode)
  :custom
  (corfu-auto t)            ;; Auto-popup completions
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)     ;; ...after 2 chars
  (corfu-cycle t)
  (corfu-quit-no-match 'separator)
  :bind (:map corfu-map ("RET" . nil)))  ;; Don't steal RET; TAB inserts

;; LSP client (built into Emacs 30). Flymake diagnostics come for free.
(use-package eglot
  :ensure nil
  :hook ((c-ts-mode c++-ts-mode python-ts-mode bash-ts-mode
          yaml-ts-mode dockerfile-ts-mode cmake-ts-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)         ;; Kill server when last buffer closes
  (eglot-events-buffer-size 0)   ;; Don't log LSP traffic (perf)
  :bind (:map eglot-mode-map
              ("C-c l r" . eglot-rename)
              ("C-c l a" . eglot-code-actions)
              ("C-c l f" . eglot-format)))

;; Snippets — handy for boilerplate-heavy Yocto recipes
(use-package yasnippet
  :config (yas-global-mode 1))
(use-package yasnippet-snippets)

;; Trim trailing whitespace ONLY on lines you edited (safe for Yocto recipes)
(use-package ws-butler
  :hook (prog-mode . ws-butler-mode))

;; Git diff indicators in the fringe
(use-package diff-hl
  :config
  (global-diff-hl-mode)
  :hook ((magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

;; Tighter projectile + ivy integration
(use-package counsel-projectile
  :after (counsel projectile)
  :config (counsel-projectile-mode))

;; CUSTOM MODES ;;

;; Bitbake files syntax mode
(add-to-list 'load-path "~/.emacs.d/manual-modes/bb-mode")
(require 'bb-mode)
(setq auto-mode-alist (cons '("\\.bb\\'" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.inc\\'" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbappend\\'" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbclass\\'" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.conf\\'" . bb-mode) auto-mode-alist))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(claude-code corfu counsel-projectile diff-hl dockerfile-mode
		 doom-modeline doom-themes dts-mode gitlab-ci-mode
		 gnu-elpa-keyring-update ivy-rich magit markdown-mode
		 ranger ripgrep vterm wgrep ws-butler
		 yasnippet-snippets))
 '(package-vc-selected-packages
   '((claude-code :url "https://github.com/stevemolitor/claude-code.el"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
