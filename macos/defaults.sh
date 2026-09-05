#!/bin/bash
# The `defaults write` tweaks you otherwise redo from memory on every new Mac.
# Add to this as you notice yourself changing things in System Settings.
set -u

# Key repeat — matters a lot in a Vim setup. 2/15 is faster than the System
# Settings slider can go.
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Kill press-and-hold accent menu so held keys actually repeat in Vim.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Show all filenames and hidden files in Finder.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true

# Full keyboard access, and no "smart" quotes/dashes mangling code.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

killall Finder 2>/dev/null || true
echo "macOS defaults applied — log out and back in for key repeat to take hold."

# ── appended by macos-extra-defaults.sh ──────────────────────────
defaults write -g KeyRepeat -int 1            # 15ms between repeats
defaults write -g InitialKeyRepeat -int 15    # 225ms before repeating starts
defaults write -g ApplePressAndHoldEnabled -bool false   # repeat, not accents

# ── Text: every one of these corrupts code ───────────────────────────────────
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false

# ── Trackpad ─────────────────────────────────────────────────────────────────
defaults write -g com.apple.trackpad.scaling -float 2.5
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write -g com.apple.swipescrolldirection -bool true   # natural scroll

# ── Dock ─────────────────────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock tilesize -int 56
defaults write com.apple.dock orientation -string bottom
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false   # don't reorder Spaces

# ── Hot corners ──────────────────────────────────────────────────────────────
# 0 none · 2 Mission Control · 3 app windows · 4 desktop
# 5 screensaver · 10 display sleep · 11 Launchpad · 12 Notification Centre
defaults write com.apple.dock wvous-br-corner -int 0   # bottom-right disabled:
defaults write com.apple.dock wvous-br-modifier -int 0 # it fires by accident
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0

# ── Finder ───────────────────────────────────────────────────────────────────
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # this folder
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Screenshots ──────────────────────────────────────────────────────────────
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ── Misc ─────────────────────────────────────────────────────────────────────
defaults write -g NSWindowResizeTime -float 0.001        # instant window resize
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write com.apple.CrashReporter DialogType -string "none"

killall Dock Finder SystemUIServer 2>/dev/null || true
echo "Applied. Some settings need a log out to take full effect."
