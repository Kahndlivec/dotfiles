;; -*- no-byte-compile: t; -*-
;;; packages.el
;;
;; Extra packages on top of the modules in init.el.
;; After editing: `doom sync`.

;; --- Notes -------------------------------------------------------------
;; denote: notes as plain files with a naming convention. No database, no
;; sync daemon, nothing to corrupt. Chosen over org-roam deliberately —
;; org-roam keeps an SQLite index that has to be rebuilt and is the usual
;; reason people say "org-roam got slow". denote has no index at all, which
;; also means your iPad reader sees exactly what Emacs sees.
(package! denote)
(package! consult-denote)   ; SPC n f / SPC n s over your notes

;; Paste/drag images (your iPad math exports) straight into an org file.
(package! org-download)

;; Nicer org bullets/spacing beyond what +pretty gives you.
(package! org-modern)

;; Prose in org rendered proportionally, while tables, code blocks and
;; anything alignment-sensitive stays monospaced.
(package! mixed-pitch)

;; org-noter can annotate DjVu as well as PDF, and pulls this in at load
;; time. Without it `SPC r n' errors before it ever opens a document.
(package! djvu)

;; Auto-align org tags/agenda when the window resizes.
(package! org-appear)       ; reveal emphasis markers only under the cursor

;; --- Project / build / debug -------------------------------------------
;; dape: Debug Adapter Protocol client built on Emacs 29's own machinery.
;; Chosen over dap-mode (what Doom's :tools debugger historically shipped)
;; because dap-mode is heavy, and dape is ~10x smaller and actively maintained.
;; For C++ on Apple Silicon it drives lldb-dap; for Python, debugpy.
(package! dape)

;; CMake buffers. Doom's cc module doesn't bring this.
(package! cmake-mode)

;; --- Claude ------------------------------------------------------------
;; Runs the Claude Code CLI inside an Emacs terminal buffer AND exposes
;; Emacs itself to Claude over MCP (xref, tree-sitter, diagnostics, diffs).
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

;; gptel: plain LLM chat in any buffer, no agent loop. Different tool from
;; claude-code-ide — this is for "explain this proof", "what does this error
;; mean", "rewrite this paragraph", where you want an answer and not edits.
;; Works well against an org or markdown buffer as the transcript.
(package! gptel)

;; --- Considered and left out, on purpose ---------------------------------
;; jinx: fast spell-checking (C module over enchant, unlike flyspell). Genuinely
;;   good, and you'll want it once you're writing prose notes in two languages.
;;   Left off because spell-check is a classic source of typing lag and you
;;   should feel the baseline first. Needs `brew install enchant`.
;;   (package! jinx)
;; forge: GitHub PRs and issues inside magit. Needs a token, and you review PRs
;;   in the browser anyway.
;; citar + :tools biblio: bibliography management. Add when you start writing
;;   something with a reference list, not before.

;; --- Themes ------------------------------------------------------------
;; Note: every Monokai Pro variant and doom-gruvbox already ship with the
;; `:ui doom` module (doom-themes megapack) — no package needed for those.
;; These are the ones that AREN'T in the megapack and are worth having.

;; Prot's ef-themes. The best-designed set for long reading sessions: the
;; contrast ratios are deliberate and org/LaTeX/markdown are first-class
;; rather than an afterthought. ~20 dark variants.
(package! ef-themes)

;; Kanagawa — Hokusai's Great Wave palette. Muted, warm, low-saturation.
;; If `doom sync` can't find this, the package is sometimes named
;; `kanagawa-theme` (singular) instead; try that.
(package! kanagawa-themes)

;; The upstream gruvbox with all six contrast levels (hard/medium/soft,
;; dark and light). More faithful than doom-gruvbox, which is a port.
(package! gruvbox-theme)

;; Catppuccin. Four flavors, set via `catppuccin-flavor' in config.el.
(package! catppuccin-theme)

;; modus-themes is built into Emacs — nothing to install.

;; --- Editing quality of life -------------------------------------------
(package! evil-textobj-tree-sitter)  ; vaf/vif = function, vac/vic = class
;; avy is already bundled with Doom's evil module — `gs SPC` jumps to any char.

;; --- Nice-to-have ------------------------------------------------------
;; If you later want Google Calendar two-way sync, khalel + vdirsyncer is the
;; least-cursed route. Left off deliberately: see SETUP.md for the one-way
;; org -> .ics export that needs no packages at all.
