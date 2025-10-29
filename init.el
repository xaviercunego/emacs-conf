;; CUSTOM FUNCTIONS ;;

(defun copy-to-clipboard ()
65;6800;1c  (interactive)
  (if (display-graphic-p)
      (progn
	(message "Yanked region to x-clipboard!")
	(call-interactively 'clipboard-kill-ring-save)
	)
    (if (region-active-p)
	(progn
          (shell-command-on-region (region-beginning) (region-end) "xsel -i -b")
          (message "Yanked region to clipboard!")
          (deactivate-mark))
      (message "No region active; can't yank to clipboard!")))
  )

(defun paste-from-clipboard ()
  (interactive)
  (if (display-graphic-p)
      (progn
	(clipboard-yank)
	(message "graphics active")
	)
    (insert (shell-command-to-string "xsel -o -b"))
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

(setq x-select-enable-clipboard t)  ;; Use the general clipboard

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

;; Redirect backup files
(setq backup-directory-alist            '((".*" . "~/.Trash")))

;; Redirect auto-save files
(setq auto-save-file-name-transforms '((".*" "~/.Trash/" t)))

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

;; Prevent splitting windows for projectile-ripgrep results
(add-to-list 'display-buffer-alist
             '("\\*ripgrep-search\\*"
               (display-buffer-reuse-window display-buffer-same-window)))


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
         ("C-x b" . counsel-ibuffer)
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

;; CUSTOM MODES ;;

;; Bitbake files syntax mode
(add-to-list 'load-path "~/.emacs.d/manual-modes/bb-mode")
(require 'bb-mode)
(setq auto-mode-alist (cons '("\\.bb$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.inc$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbappend$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbclass$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.conf$" . bb-mode) auto-mode-alist))

