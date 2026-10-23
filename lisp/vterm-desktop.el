;;; vterm-desktop.el --- Save/restore vterm buffers (incl. Claude Code) with desktop  -*- lexical-binding: t; -*-

;; `desktop-save-mode' ignores vterm buffers because vterm registers no
;; desktop handler.  This file adds one.
;;
;; For every vterm buffer it records the shell's working directory.  When the
;; shell (or the vterm process itself) is running an interactive Claude Code
;; session, it also records that session's ID and the claude command-line
;; flags, read from the live process via ~/.claude/sessions/<pid>.json and
;; /proc/<pid>/cmdline.
;;
;; On `desktop-read' each saved vterm is recreated in its directory and, for
;; Claude buffers, `claude [flags] --resume <id>' is typed into the shell, so
;; the conversation comes back and you land in your shell when Claude exits.

(require 'desktop)
(require 'cl-lib)
(declare-function vterm-mode "vterm")
(declare-function vterm-send-string "vterm")
(declare-function vterm-send-return "vterm")

(defvar vterm-desktop-sessions-directory "~/.claude/sessions/"
  "Directory where Claude Code writes one <pid>.json per running session.")

(defvar vterm-desktop-claude-program "claude"
  "Program name typed into the restored shell to resume a Claude session.")

(defvar vterm-desktop-resume-delay 0.3
  "Seconds to wait before first checking whether the shell is ready.")

(defvar vterm-desktop-resume-max-wait 8.0
  "Give up waiting for the shell prompt after this many seconds and type anyway.")

;;; Inspecting live processes

(defun vterm-desktop--children (pid)
  "Return the PIDs of the direct children of PID."
  (let ((file (format "/proc/%d/task/%d/children" pid pid)))
    (if (file-readable-p file)
        (mapcar #'string-to-number
                (split-string (with-temp-buffer
                                (insert-file-contents file)
                                (buffer-string))))
      (cl-loop for p in (list-system-processes)
               when (eql (cdr (assq 'ppid (process-attributes p))) pid)
               collect p))))

(defun vterm-desktop--pid-cwd (pid)
  "Return the working directory of PID, or nil."
  (let ((dir (file-symlink-p (format "/proc/%d/cwd" pid))))
    (and dir (file-directory-p dir) dir)))

(defun vterm-desktop--claude-args (pid)
  "Return the arguments PID was started with, minus session-selection flags.
Returns nil unless argv[0] looks like the claude program."
  (let* ((raw (condition-case nil
                  (with-temp-buffer
                    (insert-file-contents-literally (format "/proc/%d/cmdline" pid))
                    (split-string (buffer-string) "\0" t))
                (error nil)))
         (args (cdr raw))
         out)
    (when (and raw (string-suffix-p vterm-desktop-claude-program (car raw)))
      (while args
        (let ((a (pop args)))
          (cond
           ((member a '("--resume" "-r" "--session-id"))
            (when (and args (not (string-prefix-p "-" (car args))))
              (pop args)))
           ((member a '("--continue" "-c" "--fork-session")) nil)
           (t (push a out)))))
      (nreverse out))))

(defun vterm-desktop--session-info (pid)
  "Return (:session-id ID :directory DIR :args ARGS) if PID is an
interactive Claude Code session, else nil."
  (let ((file (expand-file-name (format "%d.json" pid)
                                vterm-desktop-sessions-directory)))
    (when (file-readable-p file)
      (condition-case nil
          (let* ((data (with-temp-buffer
                         (insert-file-contents file)
                         (json-parse-buffer :object-type 'alist)))
                 (sid (alist-get 'sessionId data)))
            (when (and (stringp sid)
                       (eql (alist-get 'pid data) pid)
                       (equal (alist-get 'kind data) "interactive"))
              (list :session-id sid
                    :directory (alist-get 'cwd data)
                    :args (vterm-desktop--claude-args pid))))
        (error nil)))))

(defun vterm-desktop--claude-session (pid &optional depth)
  "Find an interactive Claude Code session among PID and its descendants."
  (let ((depth (or depth 0)))
    (or (vterm-desktop--session-info pid)
        (and (< depth 3)
             (cl-some (lambda (child)
                        (vterm-desktop--claude-session child (1+ depth)))
                      (vterm-desktop--children pid))))))

;;; Saving

(defvar-local vterm-desktop--restored-session nil
  "Session data this buffer was restored from, until Claude is seen running.
Protects the session ID if the desktop is saved again before the typed
`claude --resume' command has started (e.g. Emacs killed right after start).")

(defun vterm-desktop-save-buffer (_desktop-dirname)
  "Return the data desktop should save for the current vterm buffer.
Used as the buffer-local value of `desktop-save-buffer'."
  (condition-case err
      (let* ((proc (get-buffer-process (current-buffer)))
             (pid (and proc (process-live-p proc) (process-id proc)))
             (live (and pid (vterm-desktop--claude-session pid)))
             (claude (cond (live (setq vterm-desktop--restored-session nil) live)
                           (t vterm-desktop--restored-session)))
             (dir (or (plist-get claude :directory)
                      (and pid (vterm-desktop--pid-cwd pid))
                      default-directory)))
        (list :directory (abbreviate-file-name (file-name-as-directory dir))
              :session-id (plist-get claude :session-id)
              :args (plist-get claude :args)))
    (error
     (message "vterm-desktop: could not inspect %s: %s"
              (buffer-name) (error-message-string err))
     (list :directory default-directory))))

;;; Restoring

(defun vterm-desktop--type-command (buffer command)
  "Type COMMAND followed by RET into the shell running in BUFFER."
  (when (and (buffer-live-p buffer)
             (process-live-p (get-buffer-process buffer)))
    (with-current-buffer buffer
      (vterm-send-string command)
      (vterm-send-return))))

(defun vterm-desktop--shell-ready-p (buffer)
  "Non-nil once the shell in BUFFER has printed its first prompt.
Detected as any non-whitespace output, which is prompt-agnostic (works
regardless of the user's zsh/bash prompt)."
  (and (buffer-live-p buffer)
       (process-live-p (get-buffer-process buffer))
       (with-current-buffer buffer
         (save-excursion
           (goto-char (point-max))
           (skip-chars-backward " \t\n\r")
           (> (point) (point-min))))))

(defun vterm-desktop--resume-when-ready (buffer command &optional elapsed)
  "Type COMMAND into BUFFER once its shell is ready, polling until then.
Waits for the first prompt instead of a blind delay, so a slow or loaded
startup cannot drop the command; types exactly once, so it never runs
twice.  Gives up and types anyway after `vterm-desktop-resume-max-wait'."
  (let ((elapsed (or elapsed 0.0)))
    (when (and (buffer-live-p buffer)
               (process-live-p (get-buffer-process buffer)))
      (if (or (vterm-desktop--shell-ready-p buffer)
              (>= elapsed vterm-desktop-resume-max-wait))
          (vterm-desktop--type-command buffer command)
        (run-at-time 0.1 nil #'vterm-desktop--resume-when-ready
                     buffer command (+ elapsed 0.1))))))

(defun vterm-desktop-restore-buffer (_file-name buffer-name misc)
  "Recreate a vterm buffer named BUFFER-NAME from the saved MISC data.
Handler for `desktop-buffer-mode-handlers'."
  (require 'vterm)
  (let* ((dir (plist-get misc :directory))
         (session-id (plist-get misc :session-id))
         (args (plist-get misc :args))
         (buffer (generate-new-buffer buffer-name)))
    (with-current-buffer buffer
      (setq default-directory
            (if (and dir (file-directory-p dir))
                (file-name-as-directory dir)
              (expand-file-name "~/")))
      (vterm-mode)
      (when session-id
        (setq vterm-desktop--restored-session
              (list :session-id session-id :directory dir :args args))
        (run-at-time vterm-desktop-resume-delay nil
                     #'vterm-desktop--resume-when-ready buffer
                     (mapconcat #'shell-quote-argument
                                (append (list vterm-desktop-claude-program)
                                        args
                                        (list "--resume" session-id))
                                " "))))
    buffer))

;;; Daemon fix-up

(defun vterm-desktop--unshow-in-initial-frame ()
  "Keep vterm buffers out of the daemon's invisible initial frame.
`desktop-read' shows the first restored buffer in the selected window.  In a
daemon that window is in the 80x24 `terminal-frame', and since vterm sizes
the terminal to the smallest window showing it, a Claude session displayed
there would stay 80 columns wide even in a big GUI frame."
  (when (and (daemonp) (frame-live-p terminal-frame))
    (dolist (window (window-list terminal-frame 'no-minibuf))
      (when (with-current-buffer (window-buffer window)
              (derived-mode-p 'vterm-mode))
        (set-window-buffer window (get-scratch-buffer-create))))))

(add-hook 'desktop-after-read-hook #'vterm-desktop--unshow-in-initial-frame)

;;; Save on leaving

;; `desktop-save-mode' already saves (a) when Emacs actually exits, via the
;; `kill-emacs-hook' entry in init.el, and (b) during idle time, via an idle
;; timer re-armed on each window-configuration change.  For a daemon, though,
;; "closing Emacs" usually means closing a client frame while the daemon keeps
;; running, which triggers neither of those.  This saves then too, so leaving
;; Emacs always captures the current sessions.

(defun vterm-desktop--save-now ()
  "Save the desktop to its directory without ever prompting.
`desktop-save' asks before overwriting a file whose on-disk timestamp has
changed behind Emacs's back; in a daemon that question would block with no
one to answer it, so an automatic save must never ask."
  (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t))
            ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
    (ignore-errors (desktop-save-in-desktop-dir))))

(defun vterm-desktop--save-on-frame-delete (frame)
  "Save the desktop when FRAME (a normal, non-child frame) is deleted."
  (when (and desktop-save-mode
             desktop-dirname
             (frame-live-p frame)
             (not (eq frame terminal-frame))
             (not (frame-parameter frame 'parent-frame)) ; skip posframes etc.
             (eq (emacs-pid) (desktop-owner)))
    (vterm-desktop--save-now)))

(add-hook 'delete-frame-functions #'vterm-desktop--save-on-frame-delete)

;;; Wiring

(defun vterm-desktop--enable-in-buffer ()
  "Mark the current vterm buffer as something desktop should save."
  (setq-local desktop-save-buffer #'vterm-desktop-save-buffer))

(add-hook 'vterm-mode-hook #'vterm-desktop--enable-in-buffer)
(add-to-list 'desktop-buffer-mode-handlers
             '(vterm-mode . vterm-desktop-restore-buffer))

;; Also cover vterm buffers that already exist when this file is loaded.
(dolist (buf (buffer-list))
  (with-current-buffer buf
    (when (derived-mode-p 'vterm-mode)
      (vterm-desktop--enable-in-buffer))))

(provide 'vterm-desktop)
;;; vterm-desktop.el ends here
