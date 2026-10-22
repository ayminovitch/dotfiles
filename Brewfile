# Everything the setup needs. My personal apps are in Brewfile.apps.
#
#   brew bundle --file ~/dotfiles/Brewfile
#
# Claude Code isn't here: Anthropic's own installer keeps it up to date (bootstrap installs it).

# CLI basics
brew "git"
brew "git-lfs"            # model weights, datasets
brew "gh"
brew "lazygit"
brew "just"               # task runner the project template uses
brew "direnv"             # loads .envrc per project
brew "jq"
brew "yq"
brew "ripgrep"
brew "fd"
brew "bat"
brew "fzf"
brew "lsd"
brew "tree"
brew "wget"
brew "shellcheck"
brew "gitleaks"           # pre-commit secret scan
brew "git-delta"          # nicer git diffs
brew "btop"
brew "tlrc"               # tldr pages
brew "dust"               # disk usage

# Python and JS
brew "uv"
brew "node"               # MCP servers (npx) and the odd frontend
brew "pnpm"

# AI
brew "ollama"
brew "gemini-cli"

# RAG and document processing
brew "libpq"              # psql (Postgres itself runs in Docker)
brew "ffmpeg"
brew "tesseract"          # OCR
brew "poppler"            # pdftotext and friends
brew "pandoc"

# Cloud
brew "awscli"
brew "kubernetes-cli"
brew "k9s"

# Editor and containers
cask "visual-studio-code"
cask "orbstack"           # Docker, much lighter than Docker Desktop

# Security tools from Objective-See (free)
cask "lulu"               # asks before an unknown app connects out
cask "blockblock"         # warns when something installs itself to run at login

# Fonts
cask "font-jetbrains-mono"
cask "font-meslo-lg-nerd-font"   # icons in the Powerlevel10k prompt
