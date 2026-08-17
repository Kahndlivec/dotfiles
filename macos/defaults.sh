#!/bin/bash
# The `defaults write` tweaks you otherwise redo from memory on every new Mac.
# Add to this as you notice yourself changing things in System Settings.
set -u

# Key repeat — matters a lot in a Vim setup. 2/15 is faster than the System
# Settings slider can go.
defaults write NSGlobalDomain KeyRepeat -int 2
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
