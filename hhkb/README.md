# HHKB Professional Classic (PD-KB401W) — Linux layout

The layout is stored **in the keyboard**, not on the computer. Flash it once
and it's the same on the desktop, the ThinkPad, or anything else you plug into.

## Target

```
Row 3 (Caps position):   Ctrl            ← was ◇ Cmd on the Mac
Bottom row:   [ ◇ Super ] [ Fn ] [      Space      ] [ Alt ] [ Alt ]
                  ↑ was Ctrl                            ↑ was ◇ Cmd
```

Why Ctrl goes back to the Caps position: on Linux, Ctrl does the job Cmd did on
the Mac — copy/paste, tmux (C-Space), Emacs, VS Code, C-h/j/k/l pane moves — so
it stays under the same pinky, and Ctrl+C/V stays same-hand. Super only
launches apps and switches workspaces, so the outer-left thumb slot is enough.

Keep unchanged: the Fn layer (IJKL arrows, U/O Home/End, Y/H PgUp/PgDn,
N Backspace, M Enter, A/S/D/F media) and the stock Fn right of right Shift.
The far-right key can stay Alt; nothing depends on it.

## Flashing

PFU's Keymap Tool only runs on macOS and Windows, so do this on the MacBook
with the patched tool (or any Windows PC).

1. Unplug the HHKB. Check the DIP switches underneath: **SW1 off, SW2 off**
   (HHK mode — not Mac mode). **SW4 and SW5 off**, so the keymap is the only
   thing moving modifiers around. SW3 (Delete → Backspace) is your choice.
2. Plug it into the Mac and open the Keymap Tool. `HHKB_VIM_MAC.hks` in this
   folder is the old layout if you want to start from it.
3. Change the three keys above, keep the Fn layer, **write to the keyboard**.
   Export the result here as `HHKB_LINUX.hks` and commit it.
4. Plug it into Linux and check what each key sends:

   ```bash
   wev -f wl_keyboard:key
   ```

   Caps position → `Control_L`, outer-left → `Super_L`, inner-right → `Alt_R`
   (or `Alt_L`). Ctrl+C in the terminal closes wev.
