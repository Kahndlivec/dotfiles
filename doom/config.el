;;; config.el -*- lexical-binding: t; -*-
;;
;; Jakub — Doom Emacs.
;; Order of sections: performance, look, editing, notes/org, math, pdf,
;; remote, claude, then the CP layer (+cp.el).
;;
;; Reload after editing:  SPC h r r   (doom/reload)
;; Look up any symbol:    SPC h v / SPC h f
;; What is this key:      SPC h k

(setq user-full-name "Jakub"
      user-mail-address "")


;;; ---------------------------------------------------------------------
;;; 1. Performance
;;; ---------------------------------------------------------------------
;; Doom already does the big ones (deferred loading, gcmh, no site-lisp).
;; These are the remaining knobs that actually move the needle on a 32GB M1.

;; GC: collect during idle, with a large threshold, so it never fires mid-keystroke.
(setq gcmh-idle-delay 'auto
      gcmh-auto-idle-delay-factor 10
      gcmh-high-cons-threshold (* 128 1024 1024))

;; LSP/subprocess throughput. Default is 4KB, which throttles clangd badly.
(setq read-process-output-max (* 4 1024 1024)
      process-adaptive-read-buffering nil)

;; Redisplay. The single biggest source of "Emacs feels laggy vs nvim".
(setq fast-but-imprecise-scrolling t
      redisplay-skip-fontification-on-input t
      inhibit-compacting-font-caches t
      jit-lock-defer-time 0
      idle-update-delay 1.0)

;; Bidirectional text reordering is on by default and is pure cost for us.
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Long lines (minified JSON, a 200k-char test case) would otherwise hang Emacs.
(global-so-long-mode 1)

;; Smooth pixel scrolling (touchpad and high-res mouse wheels).
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))

;; Big files: strip everything expensive.
(add-hook! 'find-file-hook
  (defun +my/big-file-tweaks-h ()
    (when (> (buffer-size) (* 1024 1024))
      (setq-local display-line-numbers nil)
      (setq-local truncate-lines t)
      (font-lock-mode -1)
      (when (bound-and-true-p flycheck-mode) (flycheck-mode -1)))))

;; --- redisplay cost per keystroke -------------------------------------
;; These are the things that run on EVERY key you press. This block is the
;; difference between "feels like nvim" and "feels like Emacs".

;; Line numbers. Relative is what you want as a vim user, but the gutter
;; recomputing its width mid-scroll is a real cost. Fix the width and never
;; shrink it. Also: no line numbers in prose, org or PDFs — they cost the
;; same there and tell you nothing.
(setq display-line-numbers-type 'relative
      display-line-numbers-width 3
      display-line-numbers-grow-only t)
(remove-hook 'text-mode-hook #'display-line-numbers-mode)

;; A blinking cursor wakes a timer and forces redisplay a few times a second,
;; forever, whether or not you're typing.
(blink-cursor-mode -1)
(setq-default cursor-in-non-selected-windows nil)

;; evil-goggles flashes the region an operator affected. Useful feedback for
;; dd/yy, but the change and delete animations fire constantly while editing.
;; Keep the hint, drop the two that fire most, and halve the duration.
(after! evil-goggles
  (setq evil-goggles-duration 0.08
        evil-goggles-async-duration 0.08
        evil-goggles-enable-change nil
        evil-goggles-enable-delete nil))

;; The modeline redraws on every keystroke. Each segment you don't need is
;; work done 66 times a second while you hold a key down.
(after! doom-modeline
  (setq doom-modeline-enable-word-count nil
        doom-modeline-buffer-state-icon nil
        doom-modeline-check-simple-format t
        doom-modeline-highlight-modified-buffer-name nil))

;; --- a straight answer to "why does this feel slow" -------------------
(defun +my/perf-report ()
  "Report the things that actually explain Emacs feeling sluggish."
  (interactive)
  (let* ((log (get-buffer "*Async-native-compile-log*"))
         (compiling (and log (> (buffer-size log) 0)
                         (with-current-buffer log
                           (save-excursion
                             (goto-char (point-max))
                             (forward-line -1)
                             (not (looking-at-p ".*Compilation finished")))))))
    (message
     (concat
      (format "init %s | GC %d collections, %.2fs total"
              (emacs-init-time) gcs-done gc-elapsed)
      (format " | line-numbers %s" (or display-line-numbers "off"))
      (format " | LSP %s" (if (bound-and-true-p eglot--managed-mode) "on" "off"))
      (if compiling
          "  <- NATIVE COMPILATION STILL RUNNING. This is your lag. Wait."
        "")))))

(defun +my/time-open (file)
  "Open FILE and report how long it took. Run it three times on three
different files: if only the first is slow, that's `doom-first-file-hook'
loading half of Doom on demand, which is a once-per-session cost and normal."
  (interactive "fFile: ")
  (let ((start (float-time)))
    (find-file file)
    (message "opened in %.3fs" (- (float-time) start))))

(defun +my/profile-open (file)
  "Profile opening FILE and show what actually spent the time.
Expand the top entry with TAB."
  (interactive "fFile to open: ")
  (profiler-reset)
  (profiler-start 'cpu)
  (find-file file)
  (profiler-stop)
  (profiler-report))

(defun +my/profile-typing ()
  "Profile the next 5 seconds. Hold a key down, then read the report."
  (interactive)
  (profiler-start 'cpu)
  (run-at-time 5 nil (lambda ()
                       (profiler-stop)
                       (profiler-report)
                       (message "Expand the top entry with TAB."))) 
  (message "Profiling for 5 seconds — hold j down now."))

(map! :leader
      :desc "Perf report"       "h p" #'+my/perf-report
      :desc "Profile typing"    "h P" #'+my/profile-typing
      :desc "Time file open"    "h o" #'+my/time-open
      :desc "Profile file open" "h O" #'+my/profile-open)

;; --- if it's STILL slow, flip these in order --------------------------
;; 1. Ligatures. Cheap on Emacs 30+, but not free. Remove `ligatures' from
;;    init.el and doom sync.
;; 2. Smartparens. Runs on post-self-insert-hook, i.e. every character you
;;    type. Change `(default +bindings +smartparens)' to `(default +bindings)'.
;; 3. Line numbers entirely: `SPC :` then `doom/toggle-line-numbers'.
;; Change ONE at a time and re-run `SPC h p`, or you won't know what helped.

;; eglot: quiet, non-blocking, shuts down when the last buffer closes.
;; Chosen over lsp-mode deliberately. What you give up: semantic-token
;; highlighting (tree-sitter covers most of it), inline code lenses, a call
;; hierarchy UI, and running two servers on one buffer. All of those matter in
;; a large unfamiliar codebase — which for you lives in VS Code, not here.
(after! eglot
  (setq eglot-sync-connect nil
        eglot-autoshutdown t
        eglot-extend-to-xref t
        eglot-report-progress nil)
  (if (boundp 'eglot-events-buffer-config)
      (setq eglot-events-buffer-config '(:size 0 :format full))
    (setq eglot-events-buffer-size 0))

  ;; clangd. Your ~/.config/clangd/config.yaml already handles include paths;
  ;; these are the flags that keep it fast and quiet on single-file sources.
  (add-to-list 'eglot-server-programs
               '((c-mode c-ts-mode c++-mode c++-ts-mode)
                 . ("clangd"
                    "--background-index"
                    "--clang-tidy=false"
                    "--header-insertion=never"
                    "--completion-style=detailed"
                    "--pch-storage=memory"
                    "-j=4"))))

;; COST: flycheck re-checks on every change by default, which means running a
;; linter between your keystrokes. Check on save and after a real pause instead.
(after! flycheck
  (setq flycheck-check-syntax-automatically '(save mode-enabled idle-change)
        flycheck-idle-change-delay 1.5
        flycheck-display-errors-delay 0.4))

;; which-key popping up too eagerly reads as lag even though it isn't.
(after! which-key
  (setq which-key-idle-delay 0.4))


;;; ---------------------------------------------------------------------
;;; 2. Look
;;; ---------------------------------------------------------------------
;; --- Theme ------------------------------------------------------------
;; Switch live with `SPC h t` — consult-theme previews each one as you scroll
;; the candidate list, so you can actually see it before committing. When you
;; find the one, paste it into `doom-theme' below so it survives a restart.
;; `SPC t T' cycles through the shortlist without opening a prompt.
(setq doom-theme 'doom-monokai-pro)   ; same palette as your Sublime/VS Code.
                                      ; swap for -spectrum (higher contrast),
                                      ; -ristretto (warm), -machine (cooler)

(defvar +my/themes
  '(;; ---- already installed via :ui doom (the doom-themes megapack) ----
    doom-tomorrow-night     ; current — the base16 palette from your nvim config
    doom-monokai-pro        ; the real Monokai Pro
    doom-monokai-machine    ; Monokai Pro, cooler and more desaturated
    doom-monokai-octagon    ; Monokai Pro, deep blue-black background
    doom-monokai-ristretto  ; Monokai Pro, warm brown — closest to your aesthetic
    doom-monokai-spectrum   ; Monokai Pro, highest contrast of the set
    doom-monokai-classic    ; the original Monokai
    doom-gruvbox            ; gruvbox dark, Doom's port
    doom-miramare           ; a gruvbox variant, softer and warmer
    doom-badger             ; warm dark, almost no blue
    doom-Iosvkem            ; near-black, muted
    doom-earl-grey          ; light and warm — for long PDF/org reading sessions

    ;; ---- from packages.el ----
    kanagawa-wave           ; Hokusai palette, muted. try this one first
    kanagawa-dragon         ; darker, near-monochrome Kanagawa
    ef-autumn ef-melissa-dark ef-elea-dark ef-night ef-dark
    gruvbox-dark-hard gruvbox-dark-medium gruvbox-dark-soft
    catppuccin

    ;; ---- built into Emacs, nothing installed ----
    modus-vivendi-tinted)
  "Shortlist of themes to cycle with `+my/cycle-theme'.
Some names are guesses at the package's exact theme symbols — if one errors,
`M-x load-theme' will complete on what's actually available and you can fix
the entry here.")

(defun +my/cycle-theme ()
  "Load the next theme in `+my/themes'."
  (interactive)
  (let* ((pos (or (cl-position doom-theme +my/themes) -1))
         (next (nth (mod (1+ pos) (length +my/themes)) +my/themes)))
    (setq doom-theme next)
    (load-theme next t)
    (message "%s" next)))

(map! :leader
      :desc "Cycle theme"  "t T" #'+my/cycle-theme
      :desc "Pick theme"   "h t" #'consult-theme)

;; Catppuccin needs its flavor chosen before it renders correctly.
(after! catppuccin-theme
  (setq catppuccin-flavor 'mocha))   ; or 'macchiato / 'frappe / 'latte

;; doom-themes adds extra fontification for org headings, dired and the
;; modeline. Non-Doom themes (ef, kanagawa, catppuccin) don't get that, so org
;; buffers look a bit flatter under them. This restores the useful part.
(after! org
  (custom-set-faces!
    '(org-document-title :height 1.3 :weight bold)
    '(outline-1 :height 1.15 :weight bold)
    '(outline-2 :height 1.10 :weight semi-bold)
    '(outline-3 :height 1.05 :weight semi-bold)))

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 15 :weight 'medium)
      doom-big-font (font-spec :family "JetBrainsMono Nerd Font" :size 22)
      doom-variable-pitch-font (font-spec :family "Inter" :size 16))

;; No `doom-serif-font'. Only name fonts that `fc-list' actually shows.
;; A font Emacs can't resolve throws during `after-init-hook', which aborts
;; the rest of that hook — including theme application. Symptom: Emacs comes
;; up white with no theme, and nothing in your config appears to have loaded.
;;
;; To check a family name before putting it here, run this with `SPC ;`:
;;   (seq-filter (lambda (f) (string-match-p "Helvetica" f)) (font-family-list))

;; --- startup window size ----------------------------------------------
;; 160x50, centred on whatever monitor Emacs opens on.
;;
;; Why 160 and not the 120 that looked right to you: 120 is good for ONE
;; window, but the moment you `C-w v` you get two 59-column panes, which is
;; too narrow for C++. At 160 a vertical split gives two ~79-column windows —
;; code on the left, tests or Claude on the right, both comfortable. If you
;; mostly work single-window, drop it back to 120.
(setq default-frame-alist
      (append '((width . 160) (height . 50)) default-frame-alist))

(defun +my/center-frame (&optional frame)
  "Centre FRAME on the monitor it is currently displayed on.
Uses the monitor workarea rather than the raw screen size, so GNOME's top
bar and the dock are accounted for, and multi-monitor setups land on the right
screen instead of halfway between two."
  (interactive)
  (let* ((frame (or frame (selected-frame)))
         (area (frame-monitor-workarea frame))
         (mx (nth 0 area)) (my (nth 1 area))
         (mw (nth 2 area)) (mh (nth 3 area))
         (fw (frame-pixel-width frame))
         (fh (frame-pixel-height frame)))
    (set-frame-position frame
                        (+ mx (max 0 (/ (- mw fw) 2)))
                        (+ my (max 0 (/ (- mh fh) 2))))))

(add-hook 'window-setup-hook #'+my/center-frame)
(add-hook 'after-make-frame-functions #'+my/center-frame)

(defun +my/frame-size ()
  "Print the current frame size in characters, for pasting into config.el."
  (interactive)
  (message "(width . %d) (height . %d)" (frame-width) (frame-height)))

(map! :leader
      :desc "Frame size"   "h w" #'+my/frame-size
      :desc "Centre frame" "w C" #'+my/center-frame)

;; `SPC t F` toggles real fullscreen whenever you want it.

(setq display-line-numbers-type 'relative)

;; Thin bar cursor in insert mode, block in normal — same as your nvim.
(setq evil-normal-state-cursor  '(box)
      evil-insert-state-cursor  '(bar . 2)
      evil-visual-state-cursor  '(hollow)
      evil-replace-state-cursor '(hbar . 2))

(setq-default line-spacing 0.12)

;; Modeline: keep it informative but stop it recomputing on every keystroke.
(after! doom-modeline
  (setq doom-modeline-buffer-file-name-style 'relative-from-project
        doom-modeline-major-mode-icon t
        doom-modeline-buffer-encoding nil
        doom-modeline-percent-position nil
        doom-modeline-vcs-max-length 24))

(setq confirm-kill-emacs nil)   ; the daemon is what keeps state; no nag


;;; ---------------------------------------------------------------------
;;; 3. Editing / evil
;;; ---------------------------------------------------------------------
(setq evil-want-fine-undo t          ; undo insert-mode edits in chunks, not all at once
      evil-kill-on-visual-paste nil  ; pasting over a selection doesn't clobber the register
      evil-ex-substitute-global t)   ; :s//  is global by default, like nvim's gdefault

(setq-default tab-width 4
              indent-tabs-mode nil
              fill-column 88)

;; Format on demand everywhere (SPC c f), on save only where it's safe.
;; Deliberately not global: reformatting a C++ file mid-contest is not helpful,
;; and reformatting org/LaTeX mangles your own line breaks.
(when (fboundp 'apheleia-mode)
  (add-hook! (python-mode python-ts-mode sh-mode json-mode yaml-mode)
             #'apheleia-mode))

;; Tree-sitter text objects: vif/vaf = function, vic/vac = class,
;; via/vaa = parameter, vil/val = loop. Works with d, y, c too.
(use-package! evil-textobj-tree-sitter
  :when (modulep! :tools tree-sitter)
  :after tree-sitter
  :config
  (define-key evil-outer-text-objects-map "f"
              (evil-textobj-tree-sitter-get-textobj "function.outer"))
  (define-key evil-inner-text-objects-map "f"
              (evil-textobj-tree-sitter-get-textobj "function.inner"))
  (define-key evil-outer-text-objects-map "c"
              (evil-textobj-tree-sitter-get-textobj "class.outer"))
  (define-key evil-inner-text-objects-map "c"
              (evil-textobj-tree-sitter-get-textobj "class.inner"))
  (define-key evil-outer-text-objects-map "a"
              (evil-textobj-tree-sitter-get-textobj "parameter.outer"))
  (define-key evil-inner-text-objects-map "a"
              (evil-textobj-tree-sitter-get-textobj "parameter.inner")))



;;; ---------------------------------------------------------------------
;;; 3b. Keys: windows, and staying off the keys your hands don't like
;;; ---------------------------------------------------------------------
;; Two constraints drive everything here:
;;   1. Muscle memory from nvim should transfer. Anything you already press
;;      there should do the same thing here.
;;   2. HHKB reality: no Alt bindings, no F-keys, and nothing that makes the
;;      right pinky stretch to 0 / - / = / \.

;; --- window movement --------------------------------------------------
;; C-h/j/k/l, exactly like vim-tmux-navigator in your nvim.
;;
;; This takes C-h away from the Emacs help prefix. That's a deliberate trade
;; and a cheap one: Doom already puts every help command on `SPC h`, which is
;; where you'd reach for it anyway, and C-h is the most valuable chord on a
;; keyboard with Ctrl at caps.
;;
;; Bound in normal/visual/motion states only, NOT insert. In insert state C-j
;; and C-k belong to the corfu completion popup, and hitting ESC before
;; changing windows is what your hands already do in vim.
(map! :nvm "C-h" #'evil-window-left
      :nvm "C-j" #'evil-window-down
      :nvm "C-k" #'evil-window-up
      :nvm "C-l" #'evil-window-right)

;; The same four inside a terminal, so a vterm buffer isn't a roach motel.
;; `:after vterm' matters: vterm-mode-map doesn't exist until vterm loads, and
;; binding into a keymap that isn't defined yet aborts the rest of this file.
(map! :after vterm
      :map vterm-mode-map
      :n "C-h" #'evil-window-left
      :n "C-j" #'evil-window-down
      :n "C-k" #'evil-window-up
      :n "C-l" #'evil-window-right)

;; --- splits -----------------------------------------------------------
;; Deliberately NOT rebound: `C-w s`, `C-w v`, `C-w c`, `C-w o`, `C-w =` and
;; the rest of evil's window map already work exactly as they do in nvim, and
;; `SPC w` is the same map again if you'd rather lead with space. Adding a
;; third way to split windows would be noise.
;;
;; The only additions are the two things nvim gives you that Doom doesn't
;; surface on an obvious key:
(map! :leader
      :desc "Maximise this window"   "w z" #'doom/window-maximize-buffer
      :desc "Undo window layout"     "w u" #'winner-undo
      :desc "Redo window layout"     "w U" #'winner-redo)

;; --- staying off Alt ----------------------------------------------------
;; Emacs leans on Meta constantly and you've ruled Alt out. The escape hatches:
;;
;;   M-x           ->  SPC :        (run any command)
;;   M-:           ->  SPC ;        (eval an elisp expression)
;;   M-;           ->  gc           (comment, evil-style operator)
;;   M-w / C-y     ->  y / p        (evil registers)
;;   C-h k         ->  SPC h k      (describe key)
;;
;; `SPC :` is the one to burn in. It replaces the single most-used binding in
;; all of Emacs, and it's two comfortable keys instead of a stretch.
;;
;; Both of these are already Doom defaults — restated here only so the mapping
;; is written down somewhere you'll actually read.

;; --- errors and diagnostics ------------------------------------------
;; ]e / [e for next/previous error, matching how ]b [b ]d [d already work.
(map! :nv "] e" #'next-error
      :nv "[ e" #'previous-error)

;;; ---------------------------------------------------------------------
;;; 4. Notes: org + denote
;;; ---------------------------------------------------------------------
;; Single source of truth, on local disk. Google Drive is mounted at
;; ~/GoogleDrive (rclone) — GoodNotes exports are reachable there, but don't
;; keep org files ON the mount: autosave over FUSE is slow and conflict-prone.
(setq org-directory (expand-file-name "~/Documents/notes/"))

(defvar +notes-attachments-dir (expand-file-name "assets/" org-directory)
  "Where pasted images (iPad handwriting exports) land.")

(after! org
  (setq org-agenda-files
        (mapcar (lambda (f) (expand-file-name f org-directory))
                '("inbox.org" "todo.org" "school.org"))

        ;; --- structure ---
        org-startup-folded 'content
        org-startup-indented t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-use-sub-superscripts '{}
        org-image-actual-width '(600)
        org-log-done 'time
        org-log-into-drawer t

        ;; --- todo pipeline ---
        org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!)" "KILL(k@)"))

        ;; --- agenda ---
        org-agenda-start-day "-1d"
        org-agenda-span 10
        org-agenda-start-on-weekday nil
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-deadline-warning-days 7

        ;; --- capture ---
        org-capture-templates
        `(("i" "Inbox" entry
           (file ,(expand-file-name "inbox.org" org-directory))
           "* %?\n%U\n" :prepend t)
          ("t" "Todo" entry
           (file+headline ,(expand-file-name "todo.org" org-directory) "Tasks")
           "* TODO %?\n%U\n" :prepend t)
          ("s" "School / MFF" entry
           (file+headline ,(expand-file-name "school.org" org-directory) "Tasks")
           "* TODO %?\n  SCHEDULED: %^{when}t\n" :prepend t)
          ("p" "CP problem log" entry
           (file+olp+datetree ,(expand-file-name "cp-log.org" org-directory))
           "* %^{Problem} %^g\n:PROPERTIES:\n:LINK: %^{url}\n:END:\n\n** Idea\n%?\n\n** What I missed\n\n")
          ("m" "Math scratch" entry
           (file+olp+datetree ,(expand-file-name "math-log.org" org-directory))
           "* %^{Topic}\n%?\n"))))

;; Reveal emphasis markers/links only when the cursor is on them.
;; Prose proportional, code and tables monospaced. Org only.
(use-package! mixed-pitch
  :hook (org-mode . mixed-pitch-mode)
  :config
  (setq mixed-pitch-variable-pitch-cursor nil)
  ;; Anything alignment-sensitive must stay fixed-pitch or tables break.
  (dolist (f '(org-table org-code org-verbatim org-block org-block-begin-line
               org-block-end-line org-meta-line org-document-info-keyword
               org-property-value org-special-keyword org-drawer org-date))
    (add-to-list 'mixed-pitch-fixed-pitch-faces f)))

(use-package! org-appear
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autolinks nil
        org-appear-autosubmarkers t))

;; Typography for org buffers.
(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :hook (org-agenda-finalize . org-modern-agenda)
  :config
  (setq org-modern-star 'replace
        org-modern-hide-stars nil
        org-modern-table nil))   ; org-modern's tables fight with variable-pitch

;; --- denote: your note files ------------------------------------------
(use-package! denote
  :hook (dired-mode . denote-dired-mode)
  :config
  (setq denote-directory (expand-file-name "denote/" org-directory)
        denote-file-type 'org
        denote-known-keywords '("math" "analysis" "algebra" "cp" "ml"
                                "linux" "emacs" "mff" "agency" "ref")
        denote-prompts '(title keywords)
        denote-date-prompt-use-org-read-date t)
  (denote-rename-buffer-mode 1))

(use-package! consult-denote
  :after denote
  :config (consult-denote-mode 1))

;; --- pasting iPad handwriting into notes ------------------------------
;; Workflow: crop/export the region in GoodNotes -> it lands on the clipboard
;; or in a watched folder -> SPC n v drops it into the org file as a link,
;; with the file copied into assets/ next to your notes.
(use-package! org-download
  :after org
  :config
  (setq org-download-method 'directory
        org-download-image-dir +notes-attachments-dir
        org-download-heading-lvl nil
        org-download-timestamp "%Y%m%d-%H%M%S-"
        ;; GNOME/Wayland: PrtSc → select area → it's on the clipboard, then
        ;; `SPC n v' (org-download-clipboard) pastes it via wl-paste.
        org-download-display-inline-images 'posframe))

(map! :leader
      (:prefix-map ("n" . "notes")
       :desc "Denote: new note"        "n" #'denote
       :desc "Denote: new + template"  "N" #'denote-type
       :desc "Denote: link"            "l" #'denote-link
       :desc "Denote: backlinks"       "b" #'denote-backlinks
       :desc "Denote: rename file"     "R" #'denote-rename-file
       :desc "Find note"               "f" #'consult-denote-find
       :desc "Search notes"            "s" #'consult-denote-grep
       :desc "Paste image"             "v" #'org-download-clipboard
       :desc "Agenda"                  "a" #'org-agenda
       :desc "Capture"                 "c" #'org-capture))


;;; ---------------------------------------------------------------------
;;; 5. Math: LaTeX previews and typing speed
;;; ---------------------------------------------------------------------
(after! org
  ;; dvisvgm gives vector previews that stay crisp on a 4K monitor.
  (setq org-preview-latex-default-process 'dvisvgm
        org-startup-with-latex-preview nil)  ; on-demand: SPC m l p / C-c C-x C-l
  (plist-put org-format-latex-options :scale 1.5)
  (plist-put org-format-latex-options :foreground 'auto)
  (plist-put org-format-latex-options :background 'auto)

  ;; Preamble used for both previews and export.
  (add-to-list 'org-latex-packages-alist '("" "amsmath" t))
  (add-to-list 'org-latex-packages-alist '("" "amssymb" t))
  (add-to-list 'org-latex-packages-alist '("" "mathtools" t))
  (add-to-list 'org-latex-packages-alist '("" "physics" t)))

;; CDLaTeX inside org: `fd` -> fraction, `^` `_` auto-brace, ``a -> \alpha.
;; This is what makes typing real math in plain text bearable.
(add-hook! 'org-mode-hook #'org-cdlatex-mode)

(after! cdlatex
  (setq cdlatex-simplify-sub-super-scripts t
        cdlatex-use-dollar-to-ensure-math t))

(after! latex
  (setq TeX-engine 'luatex
        TeX-save-query nil
        TeX-show-compilation nil
        +latex-viewers '(pdf-tools)))


;;; ---------------------------------------------------------------------
;;; 6. PDFs: reading + annotating
;;; ---------------------------------------------------------------------
(after! pdf-view
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t)
  ;; Match the dark theme without inverting figures badly.
  (add-hook! 'pdf-view-mode-hook #'pdf-view-themed-minor-mode)
  (add-hook! 'pdf-view-mode-hook (lambda () (display-line-numbers-mode -1))))

;; org-noter: skripta/paper on one side, your org notes on the other, and every
;; note is anchored to a page. This is the piece that makes Emacs actually good
;; for reading MFF lecture notes.
(after! org-noter
  (setq org-noter-notes-search-path (list org-directory)
        org-noter-always-create-frame nil
        org-noter-kill-frame-at-session-end nil
        org-noter-separate-notes-from-heading t))

(map! :leader
      (:prefix-map ("r" . "read")
       :desc "org-noter session"  "n" #'org-noter
       :desc "Open PDF"           "o" #'find-file
       :desc "Highlight region"   "h" #'pdf-annot-add-highlight-markup-annotation
       :desc "Add text note"      "t" #'pdf-annot-add-text-annotation
       :desc "List annotations"   "l" #'pdf-annot-list-annotations))


;;; ---------------------------------------------------------------------
;;; 7. Remote: TRAMP over Tailscale
;;; ---------------------------------------------------------------------
;; TRAMP is the #1 cause of "why did Emacs freeze". Almost all of it comes
;; from Emacs re-probing the remote host. These settings stop that.
(after! tramp
  (setq tramp-default-method "ssh"
        tramp-verbose 1
        tramp-use-connection-share t      ; honour ControlMaster in ~/.ssh/config
        remote-file-name-inhibit-cache 60
        tramp-completion-reread-directory-timeout 60
        vc-handled-backends '(Git))       ; but see the hook below

  ;; Don't run git/vc, projectile scans, or format-on-save over the wire.
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
  (setq tramp-copy-size-limit (* 1024 1024)
        tramp-inline-compress-start-size (* 1024 1024)))

(defun +my/remote-buffer-tweaks-h ()
  "Disable expensive machinery in remote buffers."
  (when (file-remote-p default-directory)
    (setq-local vc-handled-backends nil)
    (when (bound-and-true-p apheleia-mode) (apheleia-mode -1))
    (when (bound-and-true-p flycheck-mode) (flycheck-mode -1))))
(add-hook 'find-file-hook #'+my/remote-buffer-tweaks-h)

;; Projectile: don't let it walk remote trees.
(after! projectile
  (setq projectile-file-exists-remote-cache-expire (* 10 60))
  (add-to-list 'projectile-globally-ignored-directories "^node_modules$")
  (add-to-list 'projectile-globally-ignored-directories "^.venv$"))

;; Change this to your Tailscale host alias from ~/.ssh/config.
(defvar +my/homelab-host "homelab"
  "SSH host alias for the homelab node, as defined in ~/.ssh/config.")

(map! :leader
      :desc "Homelab (dired)" "o H"
      (cmd! (dired (format "/ssh:%s:~/" +my/homelab-host)))
      :desc "Homelab (shell)" "o S"
      (cmd! (let ((default-directory (format "/ssh:%s:~/" +my/homelab-host)))
              (shell (format "*%s*" +my/homelab-host)))))


;;; ---------------------------------------------------------------------
;;; 8. Claude inside Emacs
;;; ---------------------------------------------------------------------
;; Requires the Claude Code CLI on PATH:  npm i -g @anthropic-ai/claude-code
;; claude-code-ide runs it in a vterm buffer AND exposes Emacs to Claude over
;; MCP, so it can use xref, tree-sitter, and your diagnostics rather than
;; grepping blindly.
(use-package! claude-code-ide
  :defer t
  :commands (claude-code-ide claude-code-ide-menu)
  :config
  (when (boundp 'claude-code-ide-terminal-backend)
    (setq claude-code-ide-terminal-backend 'vterm))
  (setq claude-code-ide-window-side 'right
        claude-code-ide-window-width 90
        claude-code-ide-focus-on-open t)
  (when (fboundp 'claude-code-ide-emacs-tools-setup)
    (claude-code-ide-emacs-tools-setup)))

(map! :leader
      (:prefix-map ("l" . "llm")
       :desc "Claude (project)"     "l" #'claude-code-ide
       :desc "Claude menu"          "m" #'claude-code-ide-menu
       :desc "vterm here"           "t" #'+vterm/toggle))


;;; ---------------------------------------------------------------------
;;; 9. The server, and PATH
;;; ---------------------------------------------------------------------
;; Run the Emacs server inside the normal GUI Emacs (Super+E launches or raises
;; it). That one process is then both your editor and what `emacsclient'
;; connects to, so `e file.cpp' in a terminal opens a buffer in the session
;; you're already looking at. No separate systemd daemon: a daemon plus a
;; launched Emacs gives you TWO independent Emacsen with different buffers.
;; Guarded on `daemonp' so it stays correct if you ever switch to a daemon.
(unless (daemonp)
  (require 'server)
  (unless (server-running-p)
    (server-start)))

;; GNOME gets PATH from ~/.config/environment.d (install.sh writes it), but
;; belt and braces: make sure the user-level bin dirs are visible to GUI Emacs.
(dolist (p '("~/.local/bin" "~/.npm-global/bin" "~/.config/emacs/bin"))
  (let ((dir (expand-file-name p)))
    (when (file-directory-p dir)
      (add-to-list 'exec-path dir)
      (unless (string-match-p (regexp-quote dir) (or (getenv "PATH") ""))
        (setenv "PATH" (concat dir ":" (getenv "PATH")))))))


;;; ---------------------------------------------------------------------
;;; 9b. Things that matter over months, not minutes
;;; ---------------------------------------------------------------------

;; --- projects find themselves ----------------------------------------
;; Without this, `SPC p p' only knows about projects you've already visited,
;; so every new repo needs adding by hand. With it, anything one level under
;; these directories containing a .git is found automatically.
(after! projectile
  (setq projectile-project-search-path
        (seq-filter #'file-directory-p
                    (list (expand-file-name "~/Documents/cp/")
                          (expand-file-name "~/Documents/agency/")
                          (expand-file-name "~/Documents/personal/")
                          (expand-file-name "~/dotfiles/")))
        projectile-auto-discover t
        projectile-enable-caching t))

;; --- buffers stay honest ---------------------------------------------
;; Switch a git branch, pull, or edit a file from the terminal, and open
;; buffers silently go stale. Without this you eventually save over someone
;; else's change — or your own.
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(global-auto-revert-mode 1)

;; --- your work survives a restart -------------------------------------
;; `SPC q l' restores the last session. This makes it worth using: buffers,
;; window layout and workspaces come back where you left them.
(after! persp-mode
  (setq persp-auto-save-opt 1        ; save on Emacs exit
        persp-autokill-buffer-on-remove 'kill-weak))

;; Save file buffers after 30 seconds idle. Not auto-save (which writes #files#
;; you never see) — this writes the actual file, so nothing is ever more than
;; half a minute from disk.
(setq auto-save-visited-interval 30)
(auto-save-visited-mode 1)

;; --- maintenance ------------------------------------------------------
;; `doom upgrade' pulls new Doom AND new package versions. It is the single
;; most common way a working Emacs breaks. Do it deliberately, on a day you
;; have time, never mid-contest and never the night before a deadline.
;; `doom sync' after editing init.el or packages.el is safe and routine.

;;; ---------------------------------------------------------------------
;;; 10. Projects: build, run, debug
;;; ---------------------------------------------------------------------
;; This is the part that matters once you're working on real C++ and ML
;; projects rather than single files.

;; --- compile ----------------------------------------------------------
(after! compile
  (setq compilation-scroll-output 'first-error
        compilation-always-kill t
        compilation-ask-about-save nil)
  ;; Colourise compiler output instead of leaving raw escape codes.
  (add-hook 'compilation-filter-hook #'ansi-color-compilation-filter))

(defun +my/project-compile ()
  "Run `compile' from the project root, not the current file's directory."
  (interactive)
  (let ((default-directory (or (doom-project-root) default-directory)))
    (call-interactively #'compile)))

;; --- CMake ------------------------------------------------------------
(use-package! cmake-mode
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

(defun +my/cmake-configure ()
  "Configure a CMake build dir that also emits compile_commands.json.
That file is what makes clangd understand a whole project rather than one
translation unit — without it, LSP in a real C++ project is guesswork."
  (interactive)
  (let* ((root (or (doom-project-root) default-directory))
         (default-directory root))
    (compile (concat "cmake -S . -B build "
                     "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON "
                     "-DCMAKE_BUILD_TYPE=RelWithDebInfo "
                     "&& ln -sf build/compile_commands.json ."))))

(defun +my/cmake-build ()
  "Build the configured CMake project."
  (interactive)
  (let ((default-directory (or (doom-project-root) default-directory)))
    (compile "cmake --build build -j")))

;; --- header/source toggle ---------------------------------------------
;; The one C++ navigation command you'll reach for constantly.
(after! cc-mode
  (setq ff-search-directories
        '("." "../src" "../include" "../inc" "src" "include" "inc"
          "/usr/include" "/usr/local/include/*")))

;; --- debugging --------------------------------------------------------
;; dape speaks DAP directly. For C++ use its `gdb' config (GDB 14+ speaks DAP
;; natively, no adapter to install); for Python, debugpy. `M-x dape' prompts with the available configs
;; rather than needing you to hand-write launch.json equivalents.
(use-package! dape
  :defer t
  :commands (dape dape-breakpoint-toggle)
  :config
  (setq dape-buffer-window-arrangement 'right
        dape-inlay-hints t
        dape-cwd-function #'doom-project-root)
  ;; Save breakpoints and the last config across restarts.
  (dape-breakpoint-global-mode 1)
  (add-hook 'dape-compile-hook #'kill-buffer))

(map! :leader
      (:prefix-map ("c" . "code")
       :desc "Compile (project root)" "c" #'+my/project-compile
       :desc "Recompile"              "C" #'recompile
       :desc "CMake configure"        "m" #'+my/cmake-configure
       :desc "CMake build"            "M" #'+my/cmake-build
       :desc "Toggle header/source"   "o" #'ff-find-other-file)
      (:prefix-map ("d" . "debug")
       :desc "Start / continue"   "d" #'dape
       :desc "Toggle breakpoint"  "b" #'dape-breakpoint-toggle
       :desc "Quit session"       "q" #'dape-quit
       :desc "Step over"          "n" #'dape-next
       :desc "Step into"          "i" #'dape-step-in
       :desc "Step out"           "o" #'dape-step-out))


;;; ---------------------------------------------------------------------
;;; 11. gptel — chat, as opposed to agentic editing
;;; ---------------------------------------------------------------------
;; claude-code-ide (section 8) is for "change this code". gptel is for
;; "explain this", "why is this proof step valid", "what does this error mean".
;; Different tool, different keys.
(use-package! gptel
  :defer t
  :commands (gptel gptel-send gptel-menu)
  :config
  (setq gptel-default-mode 'org-mode
        gptel-expert-commands t))

(map! :leader
      (:prefix "l"
       :desc "gptel: chat buffer"  "g" #'gptel
       :desc "gptel: send region"  "s" #'gptel-send
       :desc "gptel: menu"         "G" #'gptel-menu))


;;; ---------------------------------------------------------------------
;;; 12. Competitive programming layer
;;; ---------------------------------------------------------------------
(load! "+cp")

;; Per-machine overrides (font size on the X13 vs the 4K desktop, etc.).
;; Not tracked in git — see .gitignore.
(let ((local (expand-file-name "+local.el" doom-user-dir)))
  (when (file-exists-p local) (load local nil t)))
