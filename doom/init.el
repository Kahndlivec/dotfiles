;;; init.el -*- lexical-binding: t; -*-
;;
;; Jakub's Doom module list.
;;
;; Scope: this is the editor for ALL real software work — C++ projects, ML and
;; AI learning, systems, algorithms, scripting, math notes, CP. VS Code keeps
;; only agency frontend (JS/TS/HTML) and heavy agentic generation.
;;
;; Principle: nearly everything here is lazy-loaded, so a module you don't
;; invoke costs nothing at runtime. Modules are kept or cut on whether you'll
;; USE them, not on imagined speed. The few things that genuinely cost per
;; keystroke are marked COST and handled in config.el.
;;
;; After editing: `doom sync`. If a flag is rejected, sync names it — delete
;; that flag and re-run.

(doom! :input

       :completion
       (vertico +icons)
       (corfu +orderless +icons)

       :ui
       doom
       dashboard                 ; renamed from doom-dashboard in Doom 2.1
       hl-todo
       ligatures                 ; no +extra — see SETUP.md 8b
       modeline
       ophints
       (popup +defaults)
       treemacs                  ; project tree. lazy; you're coming from VS
                                 ; Code and real projects make it defensible
       vc-gutter
       workspaces                ; SPC TAB — one per project
       zen
       ;; OFF: indent-guides (brace languages don't need it; turn on if you end
       ;; up living in Python), vi-tilde-fringe, tabs, minimap, nav-flash

       :editor
       (evil +everywhere)
       file-templates
       fold
       format
       multiple-cursors
       snippets
       word-wrap

       :emacs
       dired
       electric
       ibuffer
       undo                      ; COST: plain undo-fu, NOT (undo +tree)
       vc

       :term
       vterm

       :checkers
       syntax                    ; COST: tuned in config.el

       :tools
       debugger                  ; see config.el — dape does the real work
       direnv                    ; per-project ML/Python envs, and it's how
                                 ; Emacs picks up the right interpreter
       editorconfig
       (eval +overlay)
       lookup                    ; no +docsets: Dash docsets are a rabbit
                                 ; hole and cppreference is a browser away
       (lsp +eglot)              ; COST + a real trade — see SETUP.md 0
       magit
       make                      ; SPC p m — run a Makefile target
       pdf
       tree-sitter
       ;; OFF: docker (add if you start managing homelab containers from here)

       :os
       (:if (featurep :system 'macos) macos)

       :lang
       (cc +lsp +tree-sitter)
       data                      ; csv/tsv/xml — data analytics work
       emacs-lisp
       json
       (latex +cdlatex +fold +latexmk +ref)  ; +ref = RefTeX: \label/\ref
                                             ; and citations in longer writeups
       markdown
       (org +dragndrop +noter +pandoc)
       (python +lsp +pyright +tree-sitter)
       (sh +lsp)                 ; bash-language-server; real for systems work
       yaml
       ;; Consider later, once you know you need them:
       ;;   (org +jupyter)  -> literate ML notebooks in org. Powerful, fiddly.
       ;;   rust, go        -> if systems work goes that way

       :config
       (default +bindings +smartparens))
