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
(global-set-key (kbd "C-c t") 'multi-term)
(global-set-key (kbd "C-c r") 'revert-buffer)


;; GENERAL CUSTOM ;;

(setq x-select-enable-clipboard t)  ;; Use the general clipboard

(setq inhibit-startup-message t)  ;; Disable start-up message 

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

;; multi-term mode
(add-to-list 'load-path "~/.emacs.d/manual-modes/multi-term")
(require 'multi-term)
(setq multi-term-program "/bin/zsh")

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


;; CUSTOM MODES ;;

;; Bitbake files syntax mode
(add-to-list 'load-path "~/.emacs.d/manual-modes/bb-mode")
(require 'bb-mode)
(setq auto-mode-alist (cons '("\\.bb$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.inc$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbappend$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.bbclass$" . bb-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.conf$" . bb-mode) auto-mode-alist))

