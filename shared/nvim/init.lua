-- ═══════════════════════════════════════════════════════════════════════════
--  ~/.config/nvim/init.lua
--
--  KEYMAP CONVENTION: Doom Emacs / LazyVim (both descend from Spacemacs).
--  Leader is Space. Press it and wait — which-key shows you everything.
--
--    SPC SPC   find file                SPC f   file       SPC b   buffer
--    SPC .     find file                SPC s   search     SPC w   window
--    SPC ,     switch buffer            SPC g   git        SPC c   code
--                                       SPC o   open       SPC t   toggle
--                                       SPC d   debug      SPC q   quit/session
--                                       SPC h   help
--
--  Non-leader keys are vim/nvim standard:
--    gd gD gr gi gy   goto definition/declaration/references/impl/type
--    K                hover docs           ]d [d   next/prev diagnostic
--    ]c [c            next/prev git hunk   <C-hjkl> move between splits
--    <Esc>            clear search highlight
--
--  One file, two hosts: everything branches on `vim.g.vscode`, so the same
--  keys work in VS Code's Neovim extension and in standalone nvim.
--
--  HHKB rules held: no F-keys, no arrows, no Option bindings. Everything is
--  Control, leader, or a plain letter.
-- ═══════════════════════════════════════════════════════════════════════════

-- Format on save. `SPC t f` flips it for the session either way.
local FORMAT_ON_SAVE = false

-- Colourscheme. "tomorrow-night" | "monokai-pro" | "doom-one" | "gruvbox"
-- This picks which one loads. Change it, restart.
--
-- "tomorrow-night" is the theme from the Doom Emacs screenshot. That was
-- measured, not guessed: the screenshot's background is #1d1f21 and its menu
-- red is #cc6666, which is doom-tomorrow-night's palette exactly. In Neovim
-- the same palette ships as base16's tomorrow-night.
local COLORSCHEME = "monokai-pro"

-- Monokai Pro palette: "pro" | "spectrum" | "octagon" | "machine"
--                     | "ristretto" | "classic"
local MONOKAI_FILTER = "pro"

-- GUI font, used only by Neovide. Terminal nvim takes the font from Ghostty.
-- Verify the exact family name with: ghostty +list-fonts | grep -i jetbrains
local GUI_FONT = "JetBrainsMono Nerd Font Mono"

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- ═══════════════════════════════════════════════════════════════════════════
--  OPTIONS
-- ═══════════════════════════════════════════════════════════════════════════
local opt = vim.opt

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.wrapscan = true
opt.timeoutlen = 500
opt.undofile = true
opt.undolevels = 10000
opt.backup = false

-- Swap files on, but parked out of sight so they never litter a project dir.
opt.swapfile = true
opt.directory = vim.fn.stdpath("state") .. "/swap//"

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- ── Clipboard ──────────────────────────────────────────────────────────────
-- Locally, share the system clipboard. Over SSH, route copies through OSC 52
-- so a yank on the Linux box lands in the Mac clipboard. Paste falls back to
-- the local register, because OSC 52 read is unreliable and usually disabled.
opt.clipboard = "unnamedplus"

if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
    local osc = require("vim.ui.clipboard.osc52")
    local function paste()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
        name = "OSC 52",
        copy = { ["+"] = osc.copy("+"), ["*"] = osc.copy("*") },
        paste = { ["+"] = paste, ["*"] = paste },
    }
end

-- ── Unused language providers ──────────────────────────────────────────────
-- Nothing here is a remote plugin, so these four :checkhealth warnings are
-- noise about a feature you don't use. Delete a line if that ever changes.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- ── Reload files changed on disk ───────────────────────────────────────────
opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermClose", "TermLeave" }, {
    group = vim.api.nvim_create_augroup("checktime", { clear = true }),
    callback = function()
        if vim.o.buftype == "" then vim.cmd("checktime") end
    end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    callback = function()
        vim.notify("File changed on disk — buffer reloaded", vim.log.levels.WARN)
    end,
})

-- ── Big-file guard ─────────────────────────────────────────────────────────
-- Treesitter and clangd will both try to parse whatever you open. A generated
-- file or a fat CP test input hangs the UI for seconds. The `bigfile` flag set
-- here is checked in the treesitter and LSP blocks further down.
local BIGFILE = 1024 * 1024 -- 1 MB
vim.api.nvim_create_autocmd("BufReadPre", {
    group = vim.api.nvim_create_augroup("bigfile", { clear = true }),
    callback = function(ev)
        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
        if not (ok and stats and stats.size > BIGFILE) then return end
        vim.b[ev.buf].bigfile = true
        vim.b[ev.buf].disable_autoformat = true
        vim.opt_local.foldmethod = "manual"
        vim.opt_local.undofile = false
        vim.opt_local.swapfile = false
        vim.opt_local.spell = false
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
                vim.bo[ev.buf].syntax = ""
                vim.notify(("Big file (%.1f MB) — highlighting and LSP off")
                    :format(stats.size / 1024 / 1024), vim.log.levels.WARN)
            end
        end)
    end,
})

local map = vim.keymap.set

-- ═══════════════════════════════════════════════════════════════════════════
--  CORE KEYMAPS — true in both VS Code and standalone nvim
-- ═══════════════════════════════════════════════════════════════════════════

-- hjkl, no escape hatches. Your Fn layer still gives real arrows in insert
-- mode and everywhere outside Vim; this only closes the door in normal/visual.
map({ "n", "v" }, "<Up>", "<Nop>")
map({ "n", "v" }, "<Down>", "<Nop>")
map("n", "<Left>", "<Nop>")
map("n", "<Right>", "<Nop>")

-- Move by visual line on wrapped text, but only for a bare j/k — the moment
-- you type a count, use real lines so the relative number gutter doesn't lie.
map("n", "j", function() return vim.v.count == 0 and "gj" or "j" end, { expr = true, silent = true })
map("n", "k", function() return vim.v.count == 0 and "gk" or "k" end, { expr = true, silent = true })

-- Recentre after every big jump.
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")
map("n", "G", "Gzz")
map("n", "<C-o>", "<C-o>zz")
-- <C-i> and Tab are the same byte in a terminal, so this also remaps Tab in
-- normal mode. Both mean "jump forward", so that's fine.
map("n", "<C-i>", "<C-i>zz")

-- Editing quality of life.
map("n", "J", "mzJ`z", { desc = "Join lines, keep cursor" })
map("v", "p", [["_dP]], { desc = "Paste over selection without clobbering register" })
map("v", "<", "<gv")
map("v", ">", ">gv")
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "Q", "@q", { desc = "Replay macro q" })

-- Highlight on yank.
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        local hl = vim.hl or vim.highlight
        hl.on_yank({ timeout = 300 })
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
if vim.g.vscode then
    -- ═══════════════════════════════════════════════════════════════════════
    --  INSIDE VS CODE — same keys, routed to VS Code commands
    -- ═══════════════════════════════════════════════════════════════════════
    local vscode = require("vscode")
    local function act(id)
        return function() vscode.action(id) end
    end

    -- SPC SPC / SPC . / SPC ,
    map("n", "<leader><leader>", act("workbench.action.quickOpen"), { desc = "Find file" })
    map("n", "<leader>.", act("workbench.action.quickOpen"), { desc = "Find file" })
    map("n", "<leader>,", act("workbench.action.showAllEditors"), { desc = "Switch buffer" })

    -- SPC f — file
    map("n", "<leader>ff", act("workbench.action.quickOpen"), { desc = "Find file" })
    map("n", "<leader>fr", act("workbench.action.openRecent"), { desc = "Recent files" })
    map("n", "<leader>fs", act("workbench.action.files.save"), { desc = "Save" })
    map("n", "<leader>fS", act("workbench.action.files.saveAll"), { desc = "Save all" })
    map("n", "<leader>fn", act("workbench.action.files.newUntitledFile"), { desc = "New file" })

    -- SPC b — buffer
    map("n", "<leader>bb", act("workbench.action.showAllEditors"), { desc = "Switch buffer" })
    map("n", "<leader>bd", act("workbench.action.closeActiveEditor"), { desc = "Close buffer" })
    map("n", "<leader>bo", act("workbench.action.closeOtherEditors"), { desc = "Close others" })
    map("n", "<leader>bn", act("workbench.action.nextEditor"), { desc = "Next buffer" })
    map("n", "<leader>bp", act("workbench.action.previousEditor"), { desc = "Prev buffer" })

    -- SPC s — search
    map("n", "<leader>ss", act("workbench.action.gotoSymbol"), { desc = "Symbol in file" })
    map("n", "<leader>sp", act("workbench.action.findInFiles"), { desc = "Search project" })
    map("n", "<leader>sS", act("workbench.action.showAllSymbols"), { desc = "Symbol in project" })
    map("n", "<leader>sd", act("workbench.actions.view.problems"), { desc = "Diagnostics" })
    map("n", "<leader>sr", act("workbench.action.replaceInFiles"), { desc = "Replace in project" })

    -- SPC w — window
    map("n", "<leader>wv", act("workbench.action.splitEditorRight"), { desc = "Split right" })
    map("n", "<leader>ws", act("workbench.action.splitEditorDown"), { desc = "Split down" })
    map("n", "<leader>wd", act("workbench.action.closeActiveEditor"), { desc = "Close pane" })
    map("n", "<leader>wm", act("workbench.action.toggleEditorWidths"), { desc = "Maximise pane" })
    map("n", "<leader>w=", act("workbench.action.evenEditorWidths"), { desc = "Equalise panes" })

    -- SPC c — code
    map("n", "<leader>cr", act("editor.action.rename"), { desc = "Rename symbol" })
    map({ "n", "v" }, "<leader>ca", act("editor.action.quickFix"), { desc = "Code action" })
    map({ "n", "v" }, "<leader>cf", act("editor.action.formatDocument"), { desc = "Format" })
    map("n", "<leader>cd", act("editor.action.revealDefinition"), { desc = "Definition" })
    map("n", "<leader>cR", act("editor.action.goToReferences"), { desc = "References" })
    map("n", "<leader>ci", act("editor.action.goToImplementation"), { desc = "Implementation" })
    map("n", "<leader>ct", act("editor.action.goToTypeDefinition"), { desc = "Type definition" })
    map("n", "<leader>cc", act("code-runner.run"), { desc = "Build and run" })
    map("n", "<leader><CR>", act("code-runner.run"), { desc = "Build and run" })

    -- SPC g — git
    map("n", "<leader>gg", act("workbench.view.scm"), { desc = "Git panel" })
    map("n", "<leader>gs", act("git.stageSelectedRanges"), { desc = "Stage hunk" })
    map("n", "<leader>gr", act("git.revertSelectedRanges"), { desc = "Reset hunk" })
    map("n", "<leader>gb", act("gitlens.toggleLineBlame"), { desc = "Toggle blame" })

    -- SPC o — open
    map("n", "<leader>oe", act("workbench.view.explorer"), { desc = "File explorer" })
    map("n", "<leader>op", act("workbench.view.explorer"), { desc = "Project tree" })
    map("n", "<leader>ot", act("workbench.action.terminal.toggleTerminal"), { desc = "Terminal" })
    map("n", "<leader>e", act("workbench.action.toggleSidebarVisibility"), { desc = "Toggle sidebar" })

    -- SPC d — debug
    map("n", "<leader>db", act("editor.debug.action.toggleBreakpoint"), { desc = "Breakpoint" })
    map("n", "<leader>dc", act("workbench.action.debug.start"), { desc = "Start / continue" })
    map("n", "<leader>ds", act("workbench.action.debug.stepOver"), { desc = "Step over" })
    map("n", "<leader>di", act("workbench.action.debug.stepInto"), { desc = "Step into" })
    map("n", "<leader>do", act("workbench.action.debug.stepOut"), { desc = "Step out" })
    map("n", "<leader>dq", act("workbench.action.debug.stop"), { desc = "Stop" })

    -- SPC n — notebooks (VS Code only; Jupyter has no nvim twin here)
    map("n", "<leader>nn", act("notebook.cell.insertCodeCellBelow"), { desc = "New cell below" })
    map("n", "<leader>nN", act("notebook.cell.insertCodeCellAbove"), { desc = "New cell above" })
    map("n", "<leader>nx", act("notebook.cell.execute"), { desc = "Run cell" })
    map("n", "<leader>na", act("notebook.execute"), { desc = "Run all cells" })
    map("n", "<leader>nr", act("jupyter.restartkernel"), { desc = "Restart kernel" })

    -- SPC q — quit
    map("n", "<leader>qq", act("workbench.action.closeAllEditors"), { desc = "Close all" })

    -- Non-leader standards
    map("n", "gd", act("editor.action.revealDefinition"), { desc = "Definition" })
    map("n", "gD", act("editor.action.revealDeclaration"), { desc = "Declaration" })
    map("n", "gr", act("editor.action.goToReferences"), { desc = "References" })
    map("n", "gi", act("editor.action.goToImplementation"), { desc = "Implementation" })
    map("n", "gy", act("editor.action.goToTypeDefinition"), { desc = "Type definition" })
    map("n", "]d", act("editor.action.marker.next"), { desc = "Next diagnostic" })
    map("n", "[d", act("editor.action.marker.prev"), { desc = "Prev diagnostic" })
    map("n", "]c", act("workbench.action.editor.nextChange"), { desc = "Next change" })
    map("n", "[c", act("workbench.action.editor.previousChange"), { desc = "Prev change" })
    map("n", "za", act("editor.toggleFold"))
    map("n", "zR", act("editor.unfoldAll"))
    map("n", "zM", act("editor.foldAll"))

else
    -- ═══════════════════════════════════════════════════════════════════════
    --  STANDALONE NEOVIM
    -- ═══════════════════════════════════════════════════════════════════════
    opt.number = true
    opt.relativenumber = true
    opt.cursorline = true
    opt.signcolumn = "yes"
    opt.scrolloff = 5
    opt.termguicolors = true
    opt.mouse = "a"
    opt.wrap = false
    opt.colorcolumn = "100"
    opt.showmode = false
    opt.splitright = true
    opt.splitbelow = true
    opt.splitkeep = "screen"   -- text doesn't jump when a split opens
    opt.updatetime = 250
    opt.inccommand = "split"
    opt.confirm = true
    opt.winborder = "rounded"
    opt.laststatus = 3

    -- Kill the `~` end-of-buffer column and give folds proper glyphs.
    -- fillchars demands EXACTLY one character per field, so the glyphs are
    -- built from codepoints instead of being pasted in: a pasted glyph that
    -- gets stripped anywhere in transit becomes an empty string, and nvim
    -- then refuses to start (E1511).
    local glyph = function(cp, fallback)
        return vim.g.have_nerd_font and vim.fn.nr2char(cp) or fallback
    end
    opt.fillchars = {
        eob       = " ",
        fold      = " ",
        foldsep   = " ",
        foldopen  = glyph(0xf078, "v"),   -- chevron down
        foldclose = glyph(0xf054, ">"),   -- chevron right
    }
    opt.shortmess:append("I")   -- no :intro splash; the dashboard is the intro

    -- Monokai Pro palette — the same hex values doom-monokai-pro reads.
    -- Switching MONOKAI_FILTER at the top of this file switches these too.
    local PALETTES = {
        pro       = { bg="#2d2a2e", dim="#727072", red="#ff6188", orange="#fc9867",
                      yellow="#ffd866", green="#a9dc76", cyan="#78dce8", purple="#ab9df2" },
        spectrum  = { bg="#222222", dim="#69676c", red="#fc618d", orange="#fd9353",
                      yellow="#fce566", green="#7bd88f", cyan="#5ad4e6", purple="#948ae3" },
        octagon   = { bg="#282a3a", dim="#696d77", red="#ff657a", orange="#ff9b5e",
                      yellow="#ffd76d", green="#bad761", cyan="#9cd1bb", purple="#c39ac9" },
        machine   = { bg="#273136", dim="#6b7678", red="#ff6d7e", orange="#ffb270",
                      yellow="#ffed72", green="#a2e57b", cyan="#7cd5f1", purple="#baa0f8" },
        ristretto = { bg="#2c2525", dim="#72696a", red="#fd6883", orange="#f38d70",
                      yellow="#f9cc6c", green="#adda78", cyan="#85dacc", purple="#a8a9eb" },
        classic   = { bg="#272822", dim="#6e7066", red="#f92672", orange="#fd971f",
                      yellow="#e6db74", green="#a6e22e", cyan="#66d9ef", purple="#ae81ff" },
    }
    local mp = PALETTES[MONOKAI_FILTER] or PALETTES.pro

    -- Cursor — exactly what Doom does: ONE colour, taken from the theme,
    -- and only the SHAPE changes per state. Box in normal and visual, thin
    -- bar in insert, underline in replace. No blink; Doom turns
    -- blink-cursor-mode off and the steady cursor is half the reason it
    -- looks calm.
    --
    -- No colour overrides here on purpose. monokai-pro.nvim already sets the
    -- Cursor highlight from the palette, and overriding it is what made this
    -- look like a toy.
    opt.guicursor = "n-v-c:block-Cursor/lCursor,"
        .. "i-ci-ve:ver25-Cursor/lCursor,"
        .. "r-cr:hor20-Cursor/lCursor,"
        .. "o:hor50-Cursor/lCursor,"
        .. "a:blinkon0"

    -- Dashboard highlights. Nothing here is a hex value on purpose: every
    -- group LINKS to a syntax group the colourscheme already defines, which
    -- is how Doom does it (doom-dashboard-menu-title inherits a syntax face,
    -- banner and footer inherit comment). Swap COLORSCHEME and the dashboard
    -- repaints itself with no edits here.
    --
    -- The one thing that can't be automatic is WHICH group to borrow, because
    -- themes disagree about what "keyword" means. tomorrow-night puts its
    -- salmon on Identifier and its violet on Keyword; Monokai Pro puts its
    -- red on Keyword. So this table names the borrowed group per theme, and
    -- anything not listed falls back to Keyword / Constant.
    local DASH_HL = {
        ["base16-tomorrow-night"] = { item = "Identifier", key = "Keyword" },
        ["monokai-pro"]           = { item = "Keyword",    key = "Constant" },
        ["doom-one"]              = { item = "Keyword",    key = "Constant" },
        ["gruvbox"]               = { item = "Keyword",    key = "Constant" },
    }

    -- mini.starter defines its own groups when it loads, after ColorScheme
    -- has already fired, so this also runs on VimEnter to land last.
    local function apply_doom_hl()
        local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end
        -- Substring match as well as exact, because some themes append a
        -- variant to colors_name.
        local name = vim.g.colors_name or ""
        local t = DASH_HL[name]
        if t == nil then
            for k, v in pairs(DASH_HL) do
                if name:find(k, 1, true) then t = v end
            end
        end
        t = t or { item = "Keyword", key = "Constant" }

        hl("MiniStarterHeader",  { link = "Comment" })   -- banner: dim
        hl("MiniStarterItem",    { link = t.item })      -- labels
        hl("MiniStarterCurrent", { link = t.item })
        hl("MiniStarterKey",     { link = t.key })       -- key hints
        hl("MiniStarterFooter",  { link = "Comment" })

        -- THIS is what made the labels two-tone. mini.starter paints the
        -- shortest unique prefix of every item ("Open p" vs "Open pr") with
        -- MiniStarterItemPrefix, and left unset it falls back to a warning
        -- colour — hence the yellow heads on blue words. Linked to the item,
        -- each label is one colour, exactly like Doom's.
        hl("MiniStarterItemPrefix", { link = t.item })

        -- Only visible while you are actually typing to filter, so it should
        -- stand out from the items rather than match them.
        hl("MiniStarterQuery", { link = "Special" })

        hl("MiniIndentscopeSymbol", { link = "Comment" })
    end

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("doom-colours", { clear = true }),
        callback = apply_doom_hl,
    })
    vim.api.nvim_create_autocmd("VimEnter", { callback = apply_doom_hl })


    -- ── Folding (treesitter-based, so za/zR/zM actually work) ──────────────
    opt.foldmethod = "expr"
    opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    opt.foldtext = ""
    opt.foldlevel = 99
    opt.foldlevelstart = 99
    opt.foldnestmax = 6

    -- ── Move between splits ────────────────────────────────────────────────
    -- <C-hjkl> is NOT mapped here on purpose — vim-tmux-navigator (in the
    -- plugin list below) owns those four keys so the same motion crosses from
    -- an nvim split into a tmux pane with no prefix. Mapping them here would
    -- stop movement dead at the edge of the nvim window.

    -- Line start / end in insert mode.
    map("i", "<C-a>", "<C-o>^", { desc = "Line start" })
    map("i", "<C-e>", "<C-o>$", { desc = "Line end" })

    -- ── SPC f — file ───────────────────────────────────────────────────────
    map("n", "<leader>fs", "<cmd>write<CR>", { desc = "Save" })
    map("n", "<leader>fS", "<cmd>wall<CR>", { desc = "Save all" })
    map("n", "<leader>fp", "<cmd>edit $MYVIMRC<CR>", { desc = "Open config" })
    map("n", "<leader>fy", function()
        local p = vim.fn.expand("%:p")
        vim.fn.setreg("+", p)
        vim.notify(p)
    end, { desc = "Yank file path" })

    -- ── SPC w — window ─────────────────────────────────────────────────────
    map("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Split right" })
    map("n", "<leader>ws", "<cmd>split<CR>", { desc = "Split down" })
    map("n", "<leader>wh", "<C-w>h", { desc = "Window left" })
    map("n", "<leader>wj", "<C-w>j", { desc = "Window down" })
    map("n", "<leader>wk", "<C-w>k", { desc = "Window up" })
    map("n", "<leader>wl", "<C-w>l", { desc = "Window right" })
    map("n", "<leader>wH", "<C-w>H", { desc = "Move pane left" })
    map("n", "<leader>wL", "<C-w>L", { desc = "Move pane right" })
    map("n", "<leader>wd", "<cmd>close<CR>", { desc = "Close pane" })
    map("n", "<leader>wo", "<cmd>only<CR>", { desc = "Close other panes" })
    map("n", "<leader>wm", "<cmd>tab split<CR>", { desc = "Maximise pane (tab)" })
    map("n", "<leader>wM", "<cmd>tabclose<CR>", { desc = "Unmaximise" })
    map("n", "<leader>w=", "<C-w>=", { desc = "Equalise panes" })

    -- ── SPC b — buffer ─────────────────────────────────────────────────────
    map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
    map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Prev buffer" })

    -- ── SPC q — quit / session ─────────────────────────────────────────────
    map("n", "<leader>qq", "<cmd>qall<CR>", { desc = "Quit all" })
    map("n", "<leader>qQ", "<cmd>qall!<CR>", { desc = "Quit all, discard" })

    -- ── SPC h — help ───────────────────────────────────────────────────────
    map("n", "<leader>hc", "<cmd>checkhealth<CR>", { desc = "Checkhealth" })
    map("n", "<leader>hL", "<cmd>Lazy<CR>", { desc = "Lazy (plugins)" })
    map("n", "<leader>hM", "<cmd>Mason<CR>", { desc = "Mason (LSP installs)" })

    -- ── SPC t — toggle ─────────────────────────────────────────────────────
    map("n", "<leader>tn", function()
        vim.opt.number = not vim.o.number
        vim.opt.relativenumber = not vim.o.relativenumber
    end, { desc = "Line numbers" })
    map("n", "<leader>tw", function() vim.opt_local.wrap = not vim.wo.wrap end,
        { desc = "Wrap" })
    map("n", "<leader>ts", function() vim.opt_local.spell = not vim.wo.spell end,
        { desc = "Spell check" })

    -- ── SPC o t — terminal ─────────────────────────────────────────────────
    local function open_term()
        vim.cmd("botright 15split | terminal")
        vim.cmd("startinsert")
    end
    map("n", "<leader>ot", open_term, { desc = "Terminal" })
    map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })

    -- ═══════════════════════════════════════════════════════════════════════
    --  C++ BUILD AND RUN
    --
    --  SPC c c   build and run against ./in.txt if present
    --  SPC c C   syntax check only, no link
    --  SPC c s   build with sanitizers (clang++ only — see below)
    --  SPC c j   build with real g++ and the judge's debug macros
    --  SPC <CR>  same as SPC c c — the fast one for contests
    --
    --  The run window is reused, so repeated runs don't stack splits.
    -- ═══════════════════════════════════════════════════════════════════════
    -- macOS has no <bits/stdc++.h>: it is a libstdc++ (GCC) extension and
    -- Apple's toolchain ships libc++. Two independent consequences:
    --
    --   * clang++ needs the shim in ~/.local/include/bits to compile at all.
    --   * clangd needs the same path, which is set globally in
    --     ~/.config/clangd/config.yaml so it works in EVERY directory, not
    --     only ones where :CpInit has been run.
    --
    -- Real GCC has the header itself and needs neither.
    local CP_INCLUDE = vim.fn.expand("~/.local/include")

    -- Which compiler builds C++:
    --   "auto"     real Homebrew g++ if installed, else clang++
    --   "g++"      force GCC (fails loudly if it isn't there)
    --   "clang++"  force Apple clang
    local CP_COMPILER = "auto"

    -- Plain `g++` on macOS is Apple clang under another name, so the real one
    -- has to be found by its versioned name.
    local function real_gxx()
        for _, v in ipairs({ "g++-16", "g++-15", "g++-14", "g++-13", "g++-12" }) do
            if vim.fn.executable(v) == 1 then return v end
        end
        return nil
    end

    local function pick_compiler()
        if CP_COMPILER == "clang++" then return "clang++" end
        local gxx = real_gxx()
        if gxx then return gxx end
        if CP_COMPILER == "g++" then
            vim.notify("No real g++ found — run `brew install gcc`", vim.log.levels.ERROR)
            return nil
        end
        return "clang++"
    end

    local CXX_BASE = { "-std=c++20", "-O0", "-g", "-DLOCAL", "-Wall", "-Wextra" }
    -- Homebrew GCC on Apple Silicon ships no libasan/libubsan — the sanitizer
    -- runtimes are not supported on aarch64-apple-darwin, and linking dies
    -- with "library not found for -lasan". So sanitizers are clang++ only,
    -- and they live on their own key instead of being baked into every build.
    local CXX_SANITIZE = { "-fsanitize=address,undefined", "-fno-omit-frame-pointer" }
    local CXX_JUDGE = { "-std=c++20", "-O2", "-D_GLIBCXX_DEBUG", "-D_GLIBCXX_DEBUG_PEDANTIC" }

    local run_win = nil

    local function cpp_run(mode)
        if vim.bo.filetype ~= "cpp" then
            vim.notify("Not a C++ buffer", vim.log.levels.WARN)
            return
        end

        local compiler, flags, run_it
        if mode == "sanitize" then
            -- Always clang++: see the note above.
            compiler, run_it = "clang++", true
            flags = vim.deepcopy(CXX_BASE)
            vim.list_extend(flags, CXX_SANITIZE)
        elseif mode == "judge" then
            compiler, run_it = real_gxx(), true
            if compiler == nil then
                vim.notify("Judge mode needs real GCC — `brew install gcc`. "
                    .. "Under clang the _GLIBCXX_DEBUG flags do nothing.",
                    vim.log.levels.ERROR)
                return
            end
            flags = vim.deepcopy(CXX_JUDGE)
        elseif mode == "syntax" then
            compiler, run_it = pick_compiler(), false
            flags = vim.deepcopy(CXX_BASE)
            table.insert(flags, 1, "-fsyntax-only")
        else
            compiler, run_it = pick_compiler(), true
            flags = vim.deepcopy(CXX_BASE)
        end
        if compiler == nil then return end

        -- Only clang needs the shim; real GCC ships the header, and shadowing
        -- it with ours would be a downgrade.
        if compiler:match("clang") then
            table.insert(flags, 1, "-I" .. CP_INCLUDE)
        end

        vim.cmd("write")
        local src = vim.fn.expand("%:p")
        local out = vim.fn.expand("%:p:r")
        local parts = { compiler, table.concat(flags, " "), vim.fn.shellescape(src) }
        if mode ~= "syntax" then
            table.insert(parts, "-o")
            table.insert(parts, vim.fn.shellescape(out))
        end
        local cmd = table.concat(parts, " ")

        if run_it then
            local infile = vim.fn.expand("%:p:h") .. "/in.txt"
            local redirect = vim.fn.filereadable(infile) == 1
                and (" < " .. vim.fn.shellescape(infile)) or ""
            cmd = cmd .. " && " .. vim.fn.shellescape(out) .. redirect
        end

        if run_win and vim.api.nvim_win_is_valid(run_win) then
            vim.api.nvim_win_close(run_win, true)
        end
        vim.cmd("botright 15split | terminal " .. cmd)
        run_win = vim.api.nvim_get_current_win()
        vim.cmd("wincmd p")
    end

    map("n", "<leader>cc", function() cpp_run("debug") end, { desc = "Build and run" })
    map("n", "<leader><CR>", function() cpp_run("debug") end, { desc = "Build and run" })
    map("n", "<leader>cC", function() cpp_run("syntax") end, { desc = "Compile only" })
    map("n", "<leader>cs", function() cpp_run("sanitize") end, { desc = "Build with sanitizers (clang)" })
    map("n", "<leader>cj", function() cpp_run("judge") end, { desc = "Build with judge g++" })
    map("n", "<leader>cn", "ggdGi", { desc = "New solution (wipe buffer)" })

    -- clangd needs a dialect hint in a loose single-file CP directory.
    vim.api.nvim_create_user_command("CpInit", function()
        local path = vim.fn.expand("%:p:h") .. "/compile_flags.txt"
        vim.fn.writefile({
            "-std=c++20", "-DLOCAL", "-Wall", "-Wextra",
            "-I" .. CP_INCLUDE,   -- so clangd stops flagging <bits/stdc++.h>
        }, path)
        vim.notify("Wrote " .. path .. " — now run :LspRestart")
    end, { desc = "Write compile_flags.txt for clangd here" })

    -- ═══════════════════════════════════════════════════════════════════════
    --  :Doctor — one command for everything that can fail silently
    --
    --  :checkhealth covers plugins that are loaded. This covers the rest:
    --  external binaries, Mason packages, the macOS C++ shims, and the
    --  handful of things whose failure mode is "nothing happens".
    --  Also on SPC h D.
    -- ═══════════════════════════════════════════════════════════════════════
    vim.api.nvim_create_user_command("Doctor", function()
        local out, bad, warn = {}, 0, 0

        local function head(s)
            out[#out + 1] = ""
            out[#out + 1] = "── " .. s .. " " .. string.rep("─", math.max(0, 58 - #s))
        end
        local function row(state, name, note)
            if state == "MISS" then bad = bad + 1 end
            if state == "warn" then warn = warn + 1 end
            local tag = ({ ok = " ok ", MISS = "MISS", warn = "warn" })[state]
            out[#out + 1] = ("  [%s]  %-30s %s"):format(tag, name, note or "")
        end
        local function need(cmd, note)
            row(vim.fn.executable(cmd) == 1 and "ok" or "MISS", cmd, note)
        end
        local function want(cmd, note)   -- optional: warn, don't fail
            row(vim.fn.executable(cmd) == 1 and "ok" or "warn", cmd, note)
        end
        local function file(path, note)
            local p = vim.fn.expand(path)
            row(vim.fn.filereadable(p) == 1 and "ok" or "MISS", path, note)
        end

        head("compilers")
        local gxx = real_gxx()
        row(gxx and "ok" or "warn", "real g++",
            gxx or "brew install gcc — judge mode needs it")
        need("clang++", "sanitizer builds (SPC c s)")
        local chosen = pick_compiler()
        row(chosen and "ok" or "MISS", "SPC c c will use", tostring(chosen))

        head("macOS C++ shims")
        file("~/.local/include/bits/stdc++.h", "so clang++ can compile the include")
        file("~/.config/clangd/config.yaml", "so clangd works in EVERY directory")

        head("external tools")
        need("rg", "SPC s p — without it, search finds nothing")
        need("make", "telescope-fzf-native build")
        need("tree-sitter", "parser compilation")
        need("git", "fugitive, gitsigns, lazy")
        want("fd", "faster find_files")
        want("node", "pyright / ts_ls, some TS grammars")
        want("tmux", "vim-tmux-navigator")

        head("mason packages")
        local mbin = vim.fn.stdpath("data") .. "/mason/bin/"
        for _, t in ipairs({
            { "clangd", "C++ LSP" },
            { "lua-language-server", "Lua LSP" },
            { "pyright-langserver", "Python LSP" },
            { "ruff", "Python lint/format" },
            { "typescript-language-server", "TS LSP" },
            { "stylua", "Lua format" },
            { "prettierd", "web format" },
            { "clang-format", "C++ format" },
            { "codelldb", "C++ debugger" },
        }) do
            row(vim.fn.executable(mbin .. t[1]) == 1 and "ok" or "MISS", t[1], t[2])
        end
        local dbgpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy"
        row(vim.fn.isdirectory(dbgpy) == 1 and "ok" or "MISS", "debugpy", "Python debugger")

        head("treesitter parsers")
        local ok_ts, ts = pcall(require, "nvim-treesitter")
        if not ok_ts then
            row("warn", "nvim-treesitter", "not loaded — open a file, then rerun")
        else
            local ok_list, installed = pcall(ts.get_installed, "parsers")
            installed = ok_list and installed or {}
            for _, lang in ipairs({ "c", "cpp", "lua", "python", "markdown", "json" }) do
                row(vim.tbl_contains(installed, lang) and "ok" or "MISS", lang)
            end
        end

        head("plugin wiring")
        local ok_tel, tel = pcall(require, "telescope")
        row((ok_tel and tel.extensions and tel.extensions.fzf) and "ok" or "warn",
            "telescope fzf-native", "silent fallback to slow sorting")
        row(pcall(require, "conform") and "ok" or "warn", "conform",
            "loads on save / SPC c f")
        local hl = vim.api.nvim_get_hl(0, { name = "MiniStarterItemPrefix" })
        row(next(hl) ~= nil and "ok" or "warn", "dashboard highlights",
            "MiniStarterItemPrefix linked")

        head("editor")
        row(vim.g.have_nerd_font and "ok" or "warn", "nerd font", "icons in the dashboard")
        row(vim.fn.has("clipboard") == 1 and "ok" or "warn", "clipboard", vim.o.clipboard)
        row(vim.o.undofile and "ok" or "warn", "undofile", "persistent undo")

        table.insert(out, 1, ("  %d missing, %d warnings"):format(bad, warn))
        table.insert(out, 1, "  nvim doctor")
        out[#out + 1] = ""

        vim.cmd("botright new")
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].modifiable = false
        vim.api.nvim_buf_set_name(buf, "doctor")
    end, { desc = "Check every silent-failure point at once" })

    map("n", "<leader>hD", "<cmd>Doctor<CR>", { desc = "Doctor: check everything" })

    -- Stress test: expects compiled `gen`, `sol` and `brute` in this directory.
    vim.api.nvim_create_user_command("Stress", function(o)
        local n = tonumber(o.args) or 200
        local d = vim.fn.shellescape(vim.fn.expand("%:p:h"))
        vim.cmd(("botright 15split | terminal cd %s && for i in $(seq 1 %d); do "
            .. "./gen $i > t.in; ./sol < t.in > a.out; ./brute < t.in > b.out; "
            .. "diff -q a.out b.out > /dev/null || { echo \"FAIL on test $i\"; cat t.in; break; }; "
            .. "done; echo finished"):format(d, n))
    end, { nargs = "?", desc = "Stress test sol against brute using gen" })

    -- ── Markdown: your Obsidian vault, edited from here ────────────────────
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        group = vim.api.nvim_create_augroup("prose", { clear = true }),
        callback = function()
            vim.opt_local.wrap = true
            vim.opt_local.linebreak = true
            vim.opt_local.spell = true
            vim.opt_local.spelllang = "en_us,cs"
            vim.opt_local.colorcolumn = ""
            vim.opt_local.conceallevel = 2
        end,
    })

    -- ── Neovide: cosmetics only ────────────────────────────────────────────
    if vim.g.neovide then
        vim.o.guifont = GUI_FONT .. ":h14"
        vim.g.neovide_remember_window_size = true
        vim.g.neovide_cursor_animation_length = 0.03
        vim.g.neovide_scroll_animation_length = 0.15
        vim.g.neovide_padding_top, vim.g.neovide_padding_bottom = 4, 4
        vim.g.neovide_padding_left, vim.g.neovide_padding_right = 8, 8
        -- Option stays a normal macOS Option so it still types ø, ∆, é.
        vim.g.neovide_input_macos_option_key_is_meta = "none"
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  PLUGINS
--
--  The first five load in BOTH hosts — they're the vim features VS Code's
--  emulation doesn't ship. Everything after is standalone nvim only.
-- ═══════════════════════════════════════════════════════════════════════════

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
    if vim.v.shell_error ~= 0 then
        error("Could not clone lazy.nvim:\n" .. out)
    end
end
vim.opt.rtp:prepend(lazypath)

local nvim_only = not vim.g.vscode

require("lazy").setup({
    -- surround     cs"'  ds(  ysiw)     change / delete / add surroundings
    -- unimpaired   ]q [q  ]b [b  yo*    paired jumps and toggles
    -- abolish      crs crc cru crm      coerce snake / camel / UPPER
    -- targets      ci(  da,             from anywhere on the line
    -- sneak        s{char}{char}        two-char jump, S backwards
    { "tpope/vim-surround",   event = "VeryLazy" },
    { "tpope/vim-unimpaired", event = "VeryLazy" },
    { "tpope/vim-abolish",    event = "VeryLazy" },
    { "wellle/targets.vim",   event = "VeryLazy" },
    { "justinmk/vim-sneak",   event = "VeryLazy" },

    -- <C-hjkl> moves between nvim splits AND tmux panes, no prefix, no
    -- thinking about which one you are in. Needs the matching block in
    -- ~/.tmux.conf (see the setup notes).
    { "christoomey/vim-tmux-navigator",
      cond = nvim_only,
      cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
      keys = {
          { "<C-h>", "<cmd>TmuxNavigateLeft<CR>",  desc = "Window/pane left" },
          { "<C-j>", "<cmd>TmuxNavigateDown<CR>",  desc = "Window/pane down" },
          { "<C-k>", "<cmd>TmuxNavigateUp<CR>",    desc = "Window/pane up" },
          { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Window/pane right" },
      },
    },

    -- ── Colourscheme ───────────────────────────────────────────────────────
    -- tomorrow-night: the theme in the Doom screenshot. Doom calls it
    -- doom-tomorrow-night; the identical palette is base16's tomorrow-night,
    -- and base16-nvim ships it with treesitter, LSP and telescope groups
    -- already wired, which a bare port would not have.
    --   base00 #1d1f21  background     base08 #cc6666  salmon (Identifier)
    --   base03 #969896  comments       base0E #b294bb  violet (Keyword)
    {
        "RRethy/base16-nvim",
        cond = nvim_only and COLORSCHEME == "tomorrow-night",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("base16-tomorrow-night")
        end,
    },

    {
        "loctvl842/monokai-pro.nvim",
        cond = nvim_only,
        lazy = false,
        priority = 1000,
        config = function()
            require("monokai-pro").setup({
                filter = MONOKAI_FILTER,
                devicons = vim.g.have_nerd_font,
                styles = {
                    comment = { italic = false },
                    keyword = { italic = false },
                    type = { italic = false },
                },
                background_clear = { "float_win", "telescope", "toggleterm" },
            })
            if COLORSCHEME == "monokai-pro" then
                vim.cmd.colorscheme("monokai-pro")
            end
        end,
    },

    -- gruvbox: warm retro palette, lower contrast than Monokai Pro. The
    -- "hard" background is the darkest of the three variants.
    {
        "ellisonleao/gruvbox.nvim",
        cond = nvim_only and COLORSCHEME == "gruvbox",
        lazy = false,
        priority = 1000,
        config = function()
            require("gruvbox").setup({
                contrast = "hard",              -- "hard" | "" | "soft"
                italic = { strings = false, comments = false },
                bold = true,
            })
            vim.o.background = "dark"
            vim.cmd.colorscheme("gruvbox")
        end,
    },

    -- doom-one: the real Doom Emacs theme, ported. Near-black background,
    -- grey banner, salmon-red keywords — exactly the screenshot look.
    {
        "NTBBloodbath/doom-one.nvim",
        cond = nvim_only and COLORSCHEME == "doom-one",
        lazy = false,
        priority = 1000,
        config = function()
            vim.g.doom_one_cursor_coloring = false
            vim.g.doom_one_terminal_colors = true
            vim.g.doom_one_italic_comments = false
            vim.g.doom_one_telescope_highlights = true
            vim.cmd.colorscheme("doom-one")
        end,
    },

    -- ── which-key — the SPC menu, same idea as Doom's ──────────────────────
    {
        "folke/which-key.nvim",
        cond = nvim_only,
        event = "VeryLazy",
        opts = {
            delay = 300,
            triggers = {
                { "<auto>", mode = "nxso" },
                { "<leader>", mode = { "n", "v" } },
            },
            spec = {
                { "<leader>f", group = "file" },
                { "<leader>b", group = "buffer" },
                { "<leader>s", group = "search" },
                { "<leader>w", group = "window" },
                { "<leader>g", group = "git" },
                { "<leader>c", group = "code" },
                { "<leader>o", group = "open" },
                { "<leader>t", group = "toggle" },
                { "<leader>d", group = "debug" },
                { "<leader>q", group = "quit / session" },
                { "<leader>h", group = "help" },
                { "<leader>m", group = "marks / harpoon" },
            },
        },
    },

    -- ── mini.nvim — dashboard, icons, statusline, tabline, file tree ───────
    -- Deliberately NOT mini.surround (steals `s` from sneak) or mini.ai
    -- (fights targets.vim).
    {
        "nvim-mini/mini.nvim",
        cond = nvim_only,
        lazy = false,
        priority = 900,
        config = function()
            if vim.g.have_nerd_font then
                require("mini.icons").setup()
                MiniIcons.mock_nvim_web_devicons()
            end
            require("mini.statusline").setup({ use_icons = vim.g.have_nerd_font })
            require("mini.tabline").setup({ show_icons = vim.g.have_nerd_font })
            require("mini.files").setup()
            require("mini.bufremove").setup()

            -- ── Dashboard ──────────────────────────────────────────────────
            -- Laid out like Doom's splash: dim banner, an icon column, the
            -- labels in one colour, the key hints right-aligned in another,
            -- and the whole block centred in the window.
            --
            -- mini.starter only knows how to draw a list of item names. The
            -- icon column, the key column, the spacing and the centring are
            -- all added below as content hooks, which run over UNITS (the
            -- pieces each line is built from) rather than over the item names
            -- themselves. That distinction matters: the name stays pure text,
            -- so type-to-filter still works — type "fi" on the dashboard and
            -- it narrows to "Find file".
            local starter = require("mini.starter")

            --  label, nerd-font codepoint, key hint, action
            local DASH = {
                { "Recently opened files",      0xf1da, "SPC f r", "Telescope oldfiles" },
                { "Find file",                  0xf15b, "SPC SPC", "Telescope find_files" },
                { "Search project",             0xf002, "SPC s p", "Telescope live_grep" },
                { "Reload last session",        0xf021, "SPC q l", "lua require('persistence').load({ last = true })" },
                { "Open project tree",          0xf07b, "SPC o p", "lua MiniFiles.open(vim.uv.cwd())" },
                { "Open private configuration", 0xf013, "SPC f p", "edit $MYVIMRC" },
                { "Open documentation",         0xf02d, "SPC h h", "Telescope help_tags" },
            }

            -- Codepoints, not literal glyphs, so the file survives being
            -- copied through anything that mangles UTF-8. nr2char is used
            -- instead of a \\u escape because it works on every Lua build.
            local items, meta = {}, {}
            for _, d in ipairs(DASH) do
                items[#items + 1] = { name = d[1], action = d[4], section = "" }
                meta[d[1]] = {
                    icon = vim.g.have_nerd_font and (vim.fn.nr2char(d[2]) .. "  ") or "",
                    key  = d[3],
                }
            end

            local KEY_GAP = 6   -- columns between the longest label and the keys

            -- Hook 1: one blank line after the banner and one before the
            -- footer. Doom's splash breathes; a wall of text does not.
            local function breathe(content)
                local last_header, first_footer
                for n, line in ipairs(content) do
                    for _, u in ipairs(line) do
                        if u.type == "header" then last_header = n end
                        if u.type == "footer" and first_footer == nil then first_footer = n end
                    end
                end
                local blank = function() return { { string = "", type = "empty" } } end
                -- Footer first: inserting there does not shift the header index.
                if first_footer then table.insert(content, first_footer, blank()) end
                if last_header then table.insert(content, last_header + 1, blank()) end
                return content
            end

            -- Hook 2: icon in front of every item, key hint padded out behind
            -- it so the hints form a straight column.
            local function decorate(content)
                local label_w = 0
                for _, line in ipairs(content) do
                    for _, u in ipairs(line) do
                        if u.type == "item" and meta[u.string] then
                            label_w = math.max(label_w, vim.fn.strdisplaywidth(u.string))
                        end
                    end
                end

                for _, line in ipairs(content) do
                    for i = #line, 1, -1 do
                        local u = line[i]
                        local m = (u.type == "item") and meta[u.string] or nil
                        if m then
                            local pad = label_w - vim.fn.strdisplaywidth(u.string) + KEY_GAP
                            table.insert(line, i + 1, {
                                string = string.rep(" ", pad) .. m.key,
                                type = "keyhint",
                                hl = "MiniStarterKey",
                            })
                            if m.icon ~= "" then
                                table.insert(line, i, {
                                    string = m.icon,
                                    type = "icon",
                                    hl = "MiniStarterItem",
                                })
                            end
                        end
                    end
                end
                return content
            end

            -- Hook 3: centre the short lines under the banner.
            --
            -- gen_hook.aligning centres the block as a WHOLE — it pads every
            -- line by the same amount, so the items and footer end up hugging
            -- the banner's left edge instead of sitting under its middle.
            -- That was the off-centre look. Pad the short lines first, then
            -- let aligning centre the result. Banner lines are skipped or the
            -- ASCII art would tear.
            local function centre_short_lines(content)
                local widths, has_header, max_w = {}, {}, 0
                for n, line in ipairs(content) do
                    local w = 0
                    for _, u in ipairs(line) do
                        w = w + vim.fn.strdisplaywidth(u.string)
                        if u.type == "header" then has_header[n] = true end
                    end
                    widths[n] = w
                    max_w = math.max(max_w, w)
                end
                for n, line in ipairs(content) do
                    if not has_header[n] and widths[n] > 0 and widths[n] < max_w then
                        table.insert(line, 1, {
                            string = string.rep(" ", math.floor((max_w - widths[n]) / 2)),
                            type = "pad",
                        })
                    end
                end
                return content
            end

            starter.setup({
                -- The banner is a long-bracket string, so backslashes and
                -- quotes need NO escaping — paste any ASCII art in as-is.
                -- Swap it by replacing everything between [[ and ]].
                -- Doom Emacs ASCII banner, from doomemacs/core lisp/doom.el (MIT).
                -- Long-bracket string: no escaping, edit the art freely. Keep
                -- every line 78 columns or the centering goes crooked.
                header = [[
=================     ===============     ===============   ========  ========
\\ . . . . . . .\\   //. . . . . . .\\   //. . . . . . .\\  \\. . .\\// . . //
||. . ._____. . .|| ||. . ._____. . .|| ||. . ._____. . .|| || . . .\/ . . .||
|| . .||   ||. . || || . .||   ||. . || || . .||   ||. . || ||. . . . . . . ||
||. . ||   || . .|| ||. . ||   || . .|| ||. . ||   || . .|| || . | . . . . .||
|| . .||   ||. _-|| ||-_ .||   ||. . || || . .||   ||. _-|| ||-_.|\ . . . . ||
||. . ||   ||-'  || ||  `-||   || . .|| ||. . ||   ||-'  || ||  `|\_ . .|. .||
|| . _||   ||    || ||    ||   ||_ . || || . _||   ||    || ||   |\ `-_/| . ||
||_-' ||  .|/    || ||    \|.  || `-_|| ||_-' ||  .|/    || ||   | \  / |-_.||
||    ||_-'      || ||      `-_||    || ||    ||_-'      || ||   | \  / |  `||
||    `'         || ||         `'    || ||    `'         || ||   | \  / |   ||
||            .===' `===.         .==='.`===.         .===' /==. |  \/  |   ||
||         .=='   \_|-_ `===. .==='   _|_   `===. .===' _-|/   `==  \/  |   ||
||      .=='    _-'    `-_  `='    _-'   `-_    `='  _-'   `-_  /|  \/  |   ||
||   .=='    _-'          '-__\._-'         '-_./__-'         `' |. /|  |   ||
||.=='    _-'                                                     `' |  /==.||
=='    _-'                                                            \/   `==
\   _-'                   DOOM EMACS, MINUS THE EMACS                  `-_   /
 `''                                                                      ``'
]],
                items = items,
                footer = function()
                    local ok, lazy = pcall(require, "lazy")
                    if not ok then return "" end
                    local s = lazy.stats()
                    return ("Neovim loaded %d/%d plugins in %.0fms")
                        :format(s.loaded, s.count, s.startuptime)
                end,
                -- pcall'd: if mini's unit format ever changes, the dashboard
                -- loses a decoration instead of failing to start.
                content_hooks = {
                    function(c) local ok, o = pcall(breathe, c);            return ok and o or c end,
                    function(c) local ok, o = pcall(decorate, c);           return ok and o or c end,
                    function(c) local ok, o = pcall(centre_short_lines, c); return ok and o or c end,
                    starter.gen_hook.aligning("center", "center"),
                },
            })

            -- Doom's splash has no modeline, no tab bar and no cursor block
            -- parked in the margin. Match that, and put all three back the
            -- moment the buffer is left, so nothing leaks into normal editing.
            vim.api.nvim_create_autocmd("User", {
                pattern = "MiniStarterOpened",
                callback = function(ev)
                    local ls, stl, gc = vim.o.laststatus, vim.o.showtabline, vim.o.guicursor
                    vim.o.laststatus, vim.o.showtabline = 0, 0
                    vim.api.nvim_set_hl(0, "MiniStarterCursor", { blend = 100, nocombine = true })
                    vim.o.guicursor = "a:MiniStarterCursor"
                    vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
                        buffer = ev.buf,
                        once = true,
                        callback = function()
                            vim.o.laststatus, vim.o.showtabline, vim.o.guicursor = ls, stl, gc
                        end,
                    })
                end,
            })

            -- Startup time isn't computed until lazy's UIEnter hook has run,
            -- and refresh() must be given a VALID starter buffer or it errors
            -- with "not an identifier of valid Starter buffer". Both fixed:
            -- wait for VeryLazy, then refresh only real ministarter buffers.
            vim.api.nvim_create_autocmd("User", {
                pattern = "VeryLazy",
                callback = function()
                    vim.defer_fn(function()
                        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                            if vim.api.nvim_buf_is_valid(buf)
                                and vim.bo[buf].filetype == "ministarter" then
                                pcall(MiniStarter.refresh, buf)
                            end
                        end
                    end, 50)
                end,
            })


            -- Indent guides, off where they'd be noise.
            -- mini.indentscope is REMOVED. It drew a vertical guide that kept
            -- appearing on the dashboard no matter how it was disabled, and an
            -- indent guide is not worth debugging. If you ever want it back:
            --
            --   require("mini.indentscope").setup({ symbol = "│" })
            --
            -- ...and if the guide reappears where it should not, run :Inspect
            -- with the cursor on it to get the real highlight group rather
            -- than assuming which plugin drew it.

            -- Close a buffer without wrecking the split layout.
            map("n", "<leader>bd", function() MiniBufremove.delete() end,
                { desc = "Close buffer, keep layout" })
            map("n", "<leader>bo", function()
                local cur = vim.api.nvim_get_current_buf()
                for _, b in ipairs(vim.api.nvim_list_bufs()) do
                    if b ~= cur and vim.bo[b].buflisted then MiniBufremove.delete(b) end
                end
            end, { desc = "Close other buffers" })

            -- Renaming in the tree must tell the language server, or every
            -- import pointing at the file breaks silently.
            vim.api.nvim_create_autocmd("User", {
                pattern = "MiniFilesActionRename",
                callback = function(ev)
                    local from, to = ev.data.from, ev.data.to
                    for _, client in ipairs(vim.lsp.get_clients()) do
                        if client:supports_method("workspace/willRenameFiles") then
                            local res = client:request_sync("workspace/willRenameFiles", {
                                files = { {
                                    oldUri = vim.uri_from_fname(from),
                                    newUri = vim.uri_from_fname(to),
                                } },
                            }, 1000, 0)
                            if res and res.result then
                                vim.lsp.util.apply_workspace_edit(res.result, client.offset_encoding)
                            end
                        end
                    end
                end,
            })

            -- SPC o e / SPC o p / SPC e — file tree
            local function tree_here()
                if not MiniFiles.close() then
                    MiniFiles.open(vim.api.nvim_buf_get_name(0))
                end
            end
            map("n", "<leader>e", tree_here, { desc = "Toggle file tree" })
            map("n", "<leader>oe", tree_here, { desc = "File tree (current file)" })
            map("n", "<leader>op", function()
                if not MiniFiles.close() then MiniFiles.open(vim.uv.cwd()) end
            end, { desc = "Project tree" })
        end,
    },

    -- ── Git signs ──────────────────────────────────────────────────────────
    {
        "lewis6991/gitsigns.nvim",
        cond = nvim_only,
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            local gs = require("gitsigns")
            gs.setup({
                signs = { add = { text = "+" }, change = { text = "~" }, delete = { text = "_" } },
                on_attach = function(bufnr)
                    local function b(l, r, d)
                        map("n", l, r, { buffer = bufnr, desc = d })
                    end
                    b("]c", function() gs.nav_hunk("next") end, "Next change")
                    b("[c", function() gs.nav_hunk("prev") end, "Prev change")
                    b("<leader>gp", gs.preview_hunk, "Preview hunk")
                    b("<leader>gb", gs.blame_line, "Blame line")
                    b("<leader>gr", gs.reset_hunk, "Reset hunk")
                    b("<leader>gs", gs.stage_hunk, "Stage hunk")
                    b("<leader>tb", gs.toggle_current_line_blame, "Inline blame")
                end,
            })
        end,
    },

    -- ── Telescope — SPC SPC, SPC f, SPC s ──────────────────────────────────
    {
        "nvim-telescope/telescope.nvim",
        cond = nvim_only,
        event = "VeryLazy",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope-ui-select.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make",
              cond = function() return vim.fn.executable("make") == 1 end },
        },
        config = function()
            local t = require("telescope")
            t.setup({
                extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() } },
            })
            pcall(t.load_extension, "fzf")
            pcall(t.load_extension, "ui-select")

            local pick = require("telescope.builtin")

            -- The three fast ones
            map("n", "<leader><leader>", pick.find_files, { desc = "Find file" })
            map("n", "<leader>.", pick.find_files, { desc = "Find file" })
            map("n", "<leader>,", pick.buffers, { desc = "Switch buffer" })

            -- SPC f — file
            map("n", "<leader>ff", pick.find_files, { desc = "Find file" })
            map("n", "<leader>fr", pick.oldfiles, { desc = "Recent files" })

            -- SPC b — buffer
            map("n", "<leader>bb", pick.buffers, { desc = "Switch buffer" })

            -- SPC s — search
            map("n", "<leader>sp", pick.live_grep, { desc = "Search project" })
            map("n", "<leader>ss", pick.lsp_document_symbols, { desc = "Symbol in file" })
            map("n", "<leader>sS", pick.lsp_dynamic_workspace_symbols, { desc = "Symbol in project" })
            map("n", "<leader>sw", pick.grep_string, { desc = "Search word under cursor" })
            map("n", "<leader>sb", pick.current_buffer_fuzzy_find, { desc = "Search this buffer" })
            map("n", "<leader>sd", pick.diagnostics, { desc = "Diagnostics" })
            map("n", "<leader>sm", pick.marks, { desc = "Marks" })
            map("n", "<leader>sy", pick.registers, { desc = "Registers (yank history)" })
            map("n", "<leader>sq", pick.quickfix, { desc = "Quickfix list" })
            map("n", "<leader>sR", pick.resume, { desc = "Resume last search" })

            -- SPC h — help
            map("n", "<leader>hh", pick.help_tags, { desc = "Help tags" })
            map("n", "<leader>hk", pick.keymaps, { desc = "Keymaps" })
            map("n", "<leader>hm", pick.man_pages, { desc = "Man pages" })
        end,
    },

    -- ── Treesitter ─────────────────────────────────────────────────────────
    {
        "nvim-treesitter/nvim-treesitter",
        cond = nvim_only,
        branch = "main",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local ts = require("nvim-treesitter")
            ts.install({
                "bash", "c", "cpp", "css", "diff", "html", "javascript", "json",
                "jsdoc", "lua", "luadoc", "markdown", "markdown_inline", "python",
                "query", "tsx", "typescript", "vim", "vimdoc", "yaml", "latex",
            })

            local function attach(buf, lang)
                if not vim.treesitter.language.add(lang) then return end
                vim.treesitter.start(buf, lang)
                if vim.treesitter.query.get(lang, "indents") ~= nil then
                    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end
            end

            local available = ts.get_available()
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    if vim.b[args.buf].bigfile then return end   -- FIX: guard
                    local lang = vim.treesitter.language.get_lang(args.match)
                    if not lang then return end
                    if vim.tbl_contains(ts.get_installed("parsers"), lang) then
                        attach(args.buf, lang)
                    elseif vim.tbl_contains(available, lang) then
                        ts.install(lang):await(function() attach(args.buf, lang) end)
                    else
                        attach(args.buf, lang)
                    end
                end,
            })
        end,
    },

    -- ── Treesitter text objects — daf, cif, vac, dia ───────────────────────
    -- targets.vim covers brackets and quotes. This adds functions, classes
    -- and arguments, which is where the real leverage is in C++ and Python.
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        cond = nvim_only,
        branch = "main",
        event = "BufReadPost",
        config = function()
            local ok, tso = pcall(require, "nvim-treesitter-textobjects")
            if not ok then return end
            pcall(tso.setup, {})
            local sel_ok, sel = pcall(require, "nvim-treesitter-textobjects.select")
            if not sel_ok then return end
            local objs = {
                ["af"] = "@function.outer",  ["if"] = "@function.inner",
                ["ac"] = "@class.outer",     ["ic"] = "@class.inner",
                ["aa"] = "@parameter.outer", ["ia"] = "@parameter.inner",
            }
            for lhs, q in pairs(objs) do
                map({ "x", "o" }, lhs, function()
                    sel.select_textobject(q, "textobjects")
                end, { desc = "Textobject " .. q })
            end
        end,
    },

    -- ── Markdown rendering — the Obsidian vault, readable in here ──────────
    {
        "MeanderingProgrammer/render-markdown.nvim",
        cond = nvim_only,
        ft = { "markdown" },
        dependencies = { "nvim-mini/mini.nvim" },
        opts = {
            -- LaTeX rendering needs `latex2text` (pip install pylatexenc).
            -- Off by default so it doesn't error if that isn't installed.
            latex = { enabled = false },
            heading = { sign = false },
            code = { sign = false },
        },
    },

    -- ── Completion — Tab accepts, Enter is always a newline ────────────────
    {
        "saghen/blink.cmp",
        cond = nvim_only,
        version = "1.*",
        event = "InsertEnter",
        dependencies = { { "L3MON4D3/LuaSnip", version = "2.*" } },
        opts = {
            keymap = { preset = "super-tab" },
            appearance = { nerd_font_variant = "mono" },
            completion = { documentation = { auto_show = true, auto_show_delay_ms = 300 } },
            sources = { default = { "lsp", "path", "snippets" } },
            snippets = { preset = "luasnip" },
            fuzzy = { implementation = "lua" },
            signature = { enabled = true },
        },
    },

    -- ── Mason, as its own spec ─────────────────────────────────────────────
    -- It is also a dependency of nvim-lspconfig below, but lspconfig only
    -- loads on BufReadPre — so from the dashboard, with no file open, :Mason
    -- did not exist yet. Declaring it here with `cmd` makes the commands
    -- available from anywhere. lazy.nvim merges the two specs.
    {
        "mason-org/mason.nvim",
        cond = nvim_only,
        cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
        opts = {},
    },

    -- ── LSP ────────────────────────────────────────────────────────────────
    {
        "neovim/nvim-lspconfig",
        cond = nvim_only,
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "mason-org/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
        },
        config = function()
            vim.diagnostic.config({
                severity_sort = true,
                float = { border = "rounded", source = "if_many" },
                virtual_text = { source = "if_many", spacing = 2 },
            })

            map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end,
                { desc = "Next diagnostic" })
            map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end,
                { desc = "Prev diagnostic" })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
                callback = function(ev)
                    -- FIX: don't run a language server on a huge file.
                    if vim.b[ev.buf].bigfile then
                        vim.schedule(function()
                            pcall(vim.lsp.buf_detach_client, ev.buf, ev.data.client_id)
                        end)
                        return
                    end

                    local function b(l, r, d)
                        map("n", l, r, { buffer = ev.buf, desc = "LSP: " .. d })
                    end

                    -- Non-leader standards
                    b("gd", vim.lsp.buf.definition, "Definition")
                    b("gD", vim.lsp.buf.declaration, "Declaration")
                    b("gr", vim.lsp.buf.references, "References")
                    b("gi", vim.lsp.buf.implementation, "Implementation")
                    b("gy", vim.lsp.buf.type_definition, "Type definition")
                    b("K", vim.lsp.buf.hover, "Hover docs")

                    -- SPC c — code
                    b("<leader>cd", vim.lsp.buf.definition, "Definition")
                    b("<leader>cD", vim.lsp.buf.declaration, "Declaration")
                    b("<leader>cR", vim.lsp.buf.references, "References")
                    b("<leader>ci", vim.lsp.buf.implementation, "Implementation")
                    b("<leader>ct", vim.lsp.buf.type_definition, "Type definition")
                    b("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
                    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action,
                        { buffer = ev.buf, desc = "LSP: Code action" })

                    local client = vim.lsp.get_client_by_id(ev.data.client_id)

                    -- Highlight other occurrences of the symbol under the
                    -- cursor, the way VS Code does by default.
                    if client and client:supports_method("textDocument/documentHighlight") then
                        local hg = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            buffer = ev.buf, group = hg, callback = vim.lsp.buf.document_highlight,
                        })
                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = ev.buf, group = hg, callback = vim.lsp.buf.clear_references,
                        })
                    end

                    if client and client:supports_method("textDocument/inlayHint") then
                        b("<leader>ti", function()
                            vim.lsp.inlay_hint.enable(
                                not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }))
                        end, "Toggle inlay hints")
                    end
                end,
            })

            ---@type table<string, vim.lsp.Config>
            local servers = {
                clangd = {
                    cmd = { "clangd", "--background-index", "--clang-tidy",
                            "--header-insertion=never", "--fallback-style=llvm" },
                },
                pyright = {
                    settings = {
                        pyright = { disableOrganizeImports = true },
                        python = { analysis = { typeCheckingMode = "basic" } },
                    },
                },
                ruff = {},
                ts_ls = {},
                html = {},
                cssls = {},
                jsonls = {},
                lua_ls = {
                    settings = {
                        Lua = {
                            completion = { callSnippet = "Replace" },
                            diagnostics = { globals = { "vim", "MiniFiles", "MiniIcons",
                                                        "MiniBufremove" } },
                        },
                    },
                },
            }

            require("mason-lspconfig").setup({ automatic_enable = false })

            local ensure = vim.tbl_keys(servers)
            -- The debug adapters are listed here too, not only in
            -- mason-nvim-dap. That spec loads on SPC d, so until you had
            -- actually opened the debugger once, codelldb and debugpy were
            -- never requested and :Mason showed them missing.
            vim.list_extend(ensure, {
                "stylua", "prettierd", "clang-format",
                "codelldb", "debugpy",
            })
            require("mason-tool-installer").setup({ ensure_installed = ensure })

            for name, cfg in pairs(servers) do
                vim.lsp.config(name, cfg)
                vim.lsp.enable(name)
            end
        end,
    },

    -- ── Formatting — manual by default, SPC c f ────────────────────────────
    {
        "stevearc/conform.nvim",
        cond = nvim_only,
        event = "BufWritePre",
        -- Without these two the plugin only existed after the first save of a
        -- session: :ConformInfo was an unknown command and SPC c f / SPC t f
        -- silently did nothing, because both are defined inside config().
        -- Listing the keys here (no rhs) makes lazy load the plugin and then
        -- replay the keypress, which is the same trick the dap and harpoon
        -- specs use.
        cmd = "ConformInfo",
        keys = {
            { "<leader>cf", mode = { "n", "v" }, desc = "Format" },
            { "<leader>tf", desc = "Format on save" },
        },
        config = function()
            vim.g.format_on_save = FORMAT_ON_SAVE

            require("conform").setup({
                -- Errors are surfaced: a missing formatter binary used to be
                -- completely silent, which looks identical to a file that
                -- simply needed no changes.
                notify_on_error = true,
                -- Read from vim.g, not from the constant: the constant is
                -- only the STARTING value. Gating on the constant meant
                -- SPC t f could never switch format-on-save on, because the
                -- outer `if` short-circuited before the toggle was consulted.
                format_on_save = function(bufnr)
                    if not vim.g.format_on_save then return nil end
                    if vim.b[bufnr].disable_autoformat then return nil end
                    return { timeout_ms = 1000, lsp_format = "fallback" }
                end,
                formatters_by_ft = {
                    lua = { "stylua" },
                    python = { "ruff_fix", "ruff_format" },
                    javascript = { "prettierd" },
                    javascriptreact = { "prettierd" },
                    typescript = { "prettierd" },
                    typescriptreact = { "prettierd" },
                    html = { "prettierd" },
                    css = { "prettierd" },
                    json = { "prettierd" },
                    c = { "clang-format" },
                    cpp = { "clang-format" },
                    -- NO markdown: prettier reflows prose and mangles $$...$$
                    -- blocks and Obsidian callouts.
                },
            })

            map({ "n", "v" }, "<leader>cf", function()
                require("conform").format({ async = true, lsp_format = "fallback" })
            end, { desc = "Format" })

            map("n", "<leader>tf", function()
                vim.g.format_on_save = not vim.g.format_on_save
                vim.notify("Format on save: " .. (vim.g.format_on_save and "ON" or "OFF"))
            end, { desc = "Format on save" })
        end,
    },

    -- ── Git beyond hunks ───────────────────────────────────────────────────
    --   SPC g g   status — stage with s, unstage with u, commit with cc
    --   SPC g m   three-way diff for a merge conflict
    --             :diffget //2  takes the target branch
    --             :diffget //3  takes the merged branch
    {
        "tpope/vim-fugitive",
        cond = nvim_only,
        cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gwrite", "Gread", "Glog" },
        keys = {
            { "<leader>gg", "<cmd>Git<CR>",               desc = "Git status" },
            { "<leader>gl", "<cmd>Git log --oneline<CR>", desc = "Git log" },
            { "<leader>gc", "<cmd>Git commit<CR>",        desc = "Git commit" },
            { "<leader>gd", "<cmd>Gvdiffsplit<CR>",       desc = "Diff against index" },
            { "<leader>gm", "<cmd>Gvdiffsplit!<CR>",      desc = "Merge conflict, three-way" },
        },
    },

    -- ── Undo tree ──────────────────────────────────────────────────────────
    -- Vim's undo is a tree, not a line. With undofile on, that history
    -- survives restarts, so this is worth more here than it would be by default.
    {
        "mbbill/undotree",
        cond = nvim_only,
        cmd = "UndotreeToggle",
        keys = { { "<leader>tu", "<cmd>UndotreeToggle<CR>", desc = "Undo tree" } },
    },

    -- ── Sticky function header ─────────────────────────────────────────────
    {
        "nvim-treesitter/nvim-treesitter-context",
        cond = nvim_only,
        event = "BufReadPost",
        opts = { max_lines = 3, multiline_threshold = 1 },
    },

    -- ── Session restore ────────────────────────────────────────────────────
    {
        "folke/persistence.nvim",
        cond = nvim_only,
        event = "BufReadPre",
        -- Declaring the keys here does two things: lazy loads the plugin when
        -- one is pressed, and registers the description so SPC q lists them
        -- even before the plugin exists. Defined only inside config(), they
        -- were invisible from the dashboard — which is exactly where you want
        -- to restore a session from.
        keys = {
            { "<leader>qs", desc = "Restore session for this directory" },
            { "<leader>ql", desc = "Restore last session" },
        },
        opts = {},
        -- config's second argument IS opts. Without naming it, `opts` in here
        -- was a nil global and setup() silently got nothing.
        config = function(_, opts)
            require("persistence").setup(opts)
            map("n", "<leader>qs", function() require("persistence").load() end,
                { desc = "Restore session for this directory" })
            map("n", "<leader>ql", function() require("persistence").load({ last = true }) end,
                { desc = "Restore last session" })
        end,
    },

    -- ── Project-wide find and replace ──────────────────────────────────────
    {
        "MagicDuck/grug-far.nvim",
        cond = nvim_only,
        cmd = "GrugFar",
        opts = {},
        keys = {
            { "<leader>sr", function() require("grug-far").open() end,
              desc = "Replace in project" },
            { "<leader>sr", function() require("grug-far").with_visual_selection() end,
              mode = "v", desc = "Replace selection in project" },
        },
    },

    -- ── Debugger — SPC d ───────────────────────────────────────────────────
    {
        "mfussenegger/nvim-dap",
        cond = nvim_only,
        dependencies = {
            { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
            "jay-babu/mason-nvim-dap.nvim",
        },
        keys = { "<leader>d", "<leader>db", "<leader>dc" },
        config = function()
            local dap, dapui = require("dap"), require("dapui")

            require("mason-nvim-dap").setup({
                ensure_installed = { "codelldb", "python" },
                automatic_installation = true,
                handlers = {},
            })

            dapui.setup()
            dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
            dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
            dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

            -- codelldb debugs the binary, so build it first with SPC c c.
            local mason = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = { command = mason, args = { "--port", "${port}" } },
            }
            dap.configurations.cpp = { {
                name = "Launch this file's binary",
                type = "codelldb",
                request = "launch",
                program = function() return vim.fn.expand("%:p:r") end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
                args = {},
                runInTerminal = false,
            } }
            dap.configurations.c = dap.configurations.cpp

            local dbgpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
            dap.adapters.python = {
                type = "executable", command = dbgpy, args = { "-m", "debugpy.adapter" },
            }
            dap.configurations.python = { {
                type = "python", request = "launch", name = "Launch this file",
                program = "${file}", console = "integratedTerminal",
            } }

            local function m(l, r, d) map("n", l, r, { desc = "Debug: " .. d }) end
            m("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
            m("<leader>dB", function()
                dap.set_breakpoint(vim.fn.input("Condition: "))
            end, "Conditional breakpoint")
            m("<leader>dc", dap.continue,  "Start / continue")
            m("<leader>ds", dap.step_over, "Step over")
            m("<leader>di", dap.step_into, "Step into")
            m("<leader>do", dap.step_out,  "Step out")
            m("<leader>dq", dap.terminate, "Stop")
            m("<leader>du", dapui.toggle,  "Toggle debugger UI")
        end,
    },

    -- ── Harpoon — the CP navigation answer ─────────────────────────────────
    -- Pin sol.cpp, in.txt and your template once, then jump by number. This
    -- is what telescope is bad at: you do not want to fuzzy-search four files
    -- you switch between every thirty seconds.
    --   SPC m a  pin this file      SPC m m  the pin menu
    --   SPC m 1..4  jump to pin N
    {
        "ThePrimeagen/harpoon",
        cond = nvim_only,
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = { "<leader>m" },
        config = function()
            local h = require("harpoon")
            h:setup()
            map("n", "<leader>ma", function() h:list():add() end, { desc = "Pin this file" })
            map("n", "<leader>mm", function()
                h.ui:toggle_quick_menu(h:list())
            end, { desc = "Pin menu" })
            for i = 1, 4 do
                map("n", "<leader>m" .. i, function() h:list():select(i) end,
                    { desc = "Jump to pin " .. i })
            end
        end,
    },

    -- ── Snippets ───────────────────────────────────────────────────────────
    -- Type `cp` in a .cpp buffer and press Tab. Edit the block to match your
    -- real template.
    {
        "rafamadriz/friendly-snippets",
        cond = nvim_only,
        event = "InsertEnter",
        config = function()
            require("luasnip.loaders.from_vscode").lazy_load()

            local ls = require("luasnip")
            local s, t, i = ls.snippet, ls.text_node, ls.insert_node
            ls.add_snippets("cpp", {
                s("cp", {
                    t({
                        "#include <bits/stdc++.h>",
                        "using namespace std;",
                        "",
                        "#define all(x) (x).begin(), (x).end()",
                        "using ll = long long;",
                        "",
                        "void solve() {",
                        "    ",
                    }),
                    i(1),
                    t({
                        "",
                        "}",
                        "",
                        "int main() {",
                        "    ios::sync_with_stdio(false);",
                        "    cin.tie(nullptr);",
                        "    int t = 1;",
                        "    // cin >> t;",
                        "    while (t--) solve();",
                        "    return 0;",
                        "}",
                    }),
                }),
            })
        end,
    },
}, {
    ui = { border = "rounded" },
    change_detection = { notify = false },
    rocks = { enabled = false },
})
