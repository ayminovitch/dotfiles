#!/bin/bash
# A few macOS defaults I like for development. All of them can be changed back in Settings.
#   bash ~/dotfiles/macos/defaults.sh
set -u

echo "Applying macOS defaults..."

# Finder: file extensions, path bar, status bar, list view, folders on top
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# No .DS_Store files on network shares and USB drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# No smart quotes or dashes, they break code and commands you paste
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Screenshots as PNG in ~/Pictures/Screenshots instead of the Desktop
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"

killall Finder SystemUIServer >/dev/null 2>&1 || true
echo "Done. Key repeat changes need a log out and back in."
