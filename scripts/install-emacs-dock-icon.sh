#!/usr/bin/env bash
# Build a Dock-able "Emacs" app that talks to your running daemon.
#
# Why not just symlink emacs-plus's Emacs.app into /Applications:
#   - a symlinked .app isn't indexed by Spotlight and won't show in Launchpad
#   - worse, clicking it starts a SECOND, independent Emacs — cold start, its
#     own buffers, none of your daemon's state. The whole point of the daemon
#     is that a frame opens instantly and shares one session.
#
# This builds a tiny AppleScript applet that calls `emacsclient -c` instead,
# wearing the real Emacs icon. Clicking it (or dropping files on it) opens a
# frame in your existing session.
#
# Usage:  bash install-emacs-dock-icon.sh
set -euo pipefail

FORMULA="${1:-emacs-plus@31}"
APP="/Applications/Emacs.app"

PREFIX="$(brew --prefix "$FORMULA")"
SRC_APP="$PREFIX/Emacs.app"
EMACSCLIENT="$(brew --prefix)/bin/emacsclient"

[[ -d "$SRC_APP" ]]      || { echo "No app bundle at $SRC_APP — is $FORMULA installed?"; exit 1; }
[[ -x "$EMACSCLIENT" ]]  || { echo "emacsclient not found at $EMACSCLIENT"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/emacs-client.applescript" <<APPLESCRIPT
-- Launch a GUI frame from the running daemon. -a '' starts a daemon if
-- none is up, so this works even on a cold boot.
on run
    do shell script "$EMACSCLIENT -c -n -a '' > /dev/null 2>&1 &"
end run

-- Files dropped on the Dock icon, or "Open With > Emacs" from Finder.
on open theFiles
    repeat with f in theFiles
        do shell script "$EMACSCLIENT -n -a '' " & quoted form of POSIX path of f & " > /dev/null 2>&1 &"
    end repeat
end open
APPLESCRIPT

echo "Compiling applet..."
rm -rf "$APP"
osacompile -o "$APP" "$WORK/emacs-client.applescript"

# Wear the real Emacs icon rather than the generic AppleScript one.
# Pick the app icon, not the first .icns alphabetically — the bundle also
# ships document.icns, which is the file-type icon and looks like a blank page.
ICON=""
for cand in "$SRC_APP/Contents/Resources/Emacs.icns" \
            "$SRC_APP/Contents/Resources/emacs.icns"; do
  [[ -f "$cand" ]] && { ICON="$cand"; break; }
done
if [[ -z "$ICON" ]]; then
  # Fall back to whatever CFBundleIconFile actually names.
  NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' \
          "$SRC_APP/Contents/Info.plist" 2>/dev/null || true)"
  [[ -n "$NAME" ]] && ICON="$SRC_APP/Contents/Resources/${NAME%.icns}.icns"
  [[ -f "$ICON" ]] || ICON=""
fi
if [[ -n "$ICON" ]]; then
  cp "$ICON" "$APP/Contents/Resources/applet.icns"
  echo "Icon: $(basename "$ICON")"
else
  echo "No .icns found in the source bundle — keeping the default icon."
fi

# Declare that it accepts dropped files, and give it a sane name/id.
/usr/libexec/PlistBuddy -c "Set :CFBundleName Emacs"                 "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Emacs"          "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.gnu.EmacsClient" "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string org.gnu.EmacsClient" "$APP/Contents/Info.plist"

# Force Finder/Dock to notice the new icon (they cache aggressively).
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$APP" 2>/dev/null || true
killall Dock 2>/dev/null || true

echo
echo "Done: $APP"
echo "Open it once from Spotlight, then right-click its Dock icon -> Options -> Keep in Dock."
