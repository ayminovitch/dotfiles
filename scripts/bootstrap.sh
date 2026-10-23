#!/bin/bash
# Set up a Mac from this repo, or bring an existing one back in sync.
#
#   bash ~/dotfiles/scripts/bootstrap.sh
#
# Every step asks first and skips what's already done, so it's fine to run it again.
# Files it replaces are kept as *.backup-<timestamp>.
set -uo pipefail

DOTFILES="$HOME/dotfiles"
STAMP="$(date +%Y%m%d-%H%M%S)"
OLLAMA_CHAT_MODEL="${OLLAMA_CHAT_MODEL:-gemma4:12b}"               # ~8 GB, fits a 16 GB Mac
OLLAMA_EMBED_MODEL="${OLLAMA_EMBED_MODEL:-embeddinggemma-2:270m}"  # ~0.3 GB, for RAG

bold=$'\033[1m'; cyan=$'\033[36m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'
step()  { printf '\n%s== %s%s\n' "$bold" "$*" "$reset"; }
info()  { printf '%s→%s %s\n' "$cyan" "$reset" "$*"; }
ok()    { printf '%s✓%s %s\n' "$green" "$reset" "$*"; }
warn()  { printf '%s!%s %s\n' "$yellow" "$reset" "$*"; }
fail()  { printf '%s✗%s %s\n' "$red" "$reset" "$*"; }
FAILED=""
failed() { FAILED="$FAILED\n  - $*"; fail "$*"; }

# ask "question" [Y|N]: the second argument is the default
ask() {
  local default="${2:-Y}" hint="[Y/n]" reply
  [ "$default" = "N" ] && hint="[y/N]"
  read -r -p "$(printf '%s?%s %s %s ' "$yellow" "$reset" "$1" "$hint")" reply </dev/tty
  case "${reply:-$default}" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# link SRC DST: point DST at SRC, moving whatever was at DST out of the way first
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then ok "$dst already linked"; return; fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.backup-$STAMP" && info "Moved the old $dst to $dst.backup-$STAMP"
  fi
  ln -s "$src" "$dst" && ok "Linked $dst"
}

# copy_once EXAMPLE DST: start a personal file from its example, never overwrite it
copy_once() {
  [ -e "$2" ] && { ok "$2 already exists"; return; }
  mkdir -p "$(dirname "$2")" && cp "$1" "$2" && ok "Created $2 (edit it, it's yours)"
}

step "Checking the basics"
[ "$(uname -s)" = "Darwin" ] || { fail "This only works on macOS."; exit 1; }
[ -d "$DOTFILES" ] || { fail "Clone the repo to $DOTFILES first."; exit 1; }
chmod +x "$DOTFILES"/bin/* "$DOTFILES"/scripts/*.sh "$DOTFILES"/macos/*.sh \
  "$DOTFILES"/claude/*.sh "$DOTFILES"/claude/hooks/*.sh 2>/dev/null
if ! xcode-select -p >/dev/null 2>&1; then
  warn "The Xcode Command Line Tools are missing, an installer window will open."
  xcode-select --install
  echo "Run this script again when it's done."; exit 1
fi
ok "Command Line Tools"
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

# Let Homebrew take over apps that were installed by dragging them to /Applications, so
# `brew upgrade` keeps them current. If the versions differ, offer to swap in Homebrew's copy.
adopt_casks() {
  local c out app
  for c in $(grep -E '^cask "' "$1" | cut -d'"' -f2); do
    brew list --cask "$c" >/dev/null 2>&1 && continue
    if out="$(brew install --cask --adopt "$c" 2>&1)"; then ok "Homebrew now manages $c"; continue; fi
    app="$(printf '%s\n' "$out" | grep -o 'for /Applications/.*\.app!' | sed -e 's/^for //' -e 's/!$//' | tail -1)"
    [ -n "$app" ] && [ -d "$app" ] || continue
    if ask "$(basename "$app") is a different version from Homebrew's. Replace it? (the old app goes to the Trash, your settings stay)" Y; then
      osascript -e "quit app \"$(basename "$app" .app)\"" >/dev/null 2>&1; sleep 1
      if mv "$app" "$HOME/.Trash/$(basename "$app" .app)-$STAMP.app" && brew install --cask "$c" >/dev/null 2>&1; then
        ok "$c replaced"
      else failed "Couldn't replace $app, install it yourself: brew install --cask $c"; fi
    fi
  done
}

step "Apps and command line tools"
if ask "Install everything in Brewfile (things you already have are skipped)" Y; then
  adopt_casks "$DOTFILES/Brewfile"
  if brew bundle --file "$DOTFILES/Brewfile" --no-upgrade; then ok "Brewfile done"
  else failed "Some Brewfile items failed (see above). Usually an app that was installed outside Homebrew"; fi
fi
if [ -f "$DOTFILES/Brewfile.apps" ] && ask "Also install the apps in Brewfile.apps (my everyday apps, edit the list first if you like)" N; then
  adopt_casks "$DOTFILES/Brewfile.apps"
  brew bundle --file "$DOTFILES/Brewfile.apps" --no-upgrade || failed "Some apps in Brewfile.apps failed (see above)"
fi

step "Shell: zsh, oh-my-zsh, Powerlevel10k"
if ask "Link ~/.zshrc and ~/.zprofile to the ones in this repo" Y; then
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing oh-my-zsh"
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  [ -d "$custom/themes/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
  [ -d "$custom/plugins/zsh-autosuggestions" ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
  [ -d "$custom/plugins/zsh-syntax-highlighting" ] || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"

  # Keep an existing Powerlevel10k look by moving its config into the repo
  if [ -f "$HOME/.p10k.zsh" ] && [ ! -L "$HOME/.p10k.zsh" ] && [ ! -f "$DOTFILES/zsh/p10k.zsh" ]; then
    cp "$HOME/.p10k.zsh" "$DOTFILES/zsh/p10k.zsh"
  fi
  [ -f "$DOTFILES/zsh/p10k.zsh" ] && link "$DOTFILES/zsh/p10k.zsh" "$HOME/.p10k.zsh"
  link "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"
  link "$DOTFILES/zsh/zprofile" "$HOME/.zprofile"
  copy_once "$DOTFILES/zsh/zshrc.local.example" "$HOME/.zshrc.local"

  # Generate completions once instead of on every shell start
  mkdir -p "$HOME/.zfunc"
  if command -v uv >/dev/null; then
    uv generate-shell-completion zsh > "$HOME/.zfunc/_uv" 2>/dev/null
    uvx --generate-shell-completion zsh > "$HOME/.zfunc/_uvx" 2>/dev/null
    ok "uv completions"
  fi
fi

step "Git"
if ask "Use the shared git settings in git/gitconfig (your name and email stay in ~/.gitconfig)" Y; then
  if ! git config --global --get-all include.path 2>/dev/null | grep -qx "$DOTFILES/git/gitconfig"; then
    git config --global --add include.path "$DOTFILES/git/gitconfig"
  fi
  ok "Included $DOTFILES/git/gitconfig"
  [ -n "$(git config --global user.name)" ] || { read -r -p "Your name for git commits: " n </dev/tty; git config --global user.name "$n"; }
  [ -n "$(git config --global user.email)" ] || { read -r -p "Your email for git commits: " e </dev/tty; git config --global user.email "$e"; }
  ok "Committing as $(git config --global user.name) <$(git config --global user.email)>"
  [ "$(git config --global commit.gpgsign)" = "true" ] \
    || warn "Commits aren't signed yet. Afterwards run: bash ~/dotfiles/scripts/new-ssh-key.sh"
fi

step "Python (uv)"
if command -v uv >/dev/null && ask "Install Python 3.12 and 3.13 plus ruff, pre-commit and llm" Y; then
  uv python install 3.12 3.13 && ok "Python 3.12 and 3.13"
  uv tool install --quiet ruff && ok "ruff"
  uv tool install --quiet pre-commit && ok "pre-commit"
  # llm talks to every provider from the terminal: OpenAI built in, plus these plugins
  uv tool install --quiet llm --with llm-anthropic --with llm-gemini --with llm-ollama \
    && ok "llm (keys: llm keys set openai|anthropic|gemini)"
  uv tool update-shell >/dev/null 2>&1 || true
fi

step "Coding agents"
if [ -x "$HOME/.local/bin/claude" ] || command -v claude >/dev/null; then
  ok "Claude Code installed"
elif ask "Install Claude Code (Anthropic's installer, updates itself)" Y; then
  curl -fsSL https://claude.ai/install.sh | bash && ok "Claude Code installed, run 'claude' to log in"
fi
if command -v gemini >/dev/null; then ok "Gemini CLI installed"; else warn "Gemini CLI missing (brew install gemini-cli)"; fi
if ask "Set up both agents: rules, skills, sandbox, hooks, status line, reviewer subagent" Y; then
  copy_once "$DOTFILES/agents/about-me.example.md" "$HOME/.config/dotfiles/about-me.md"
  "$DOTFILES/bin/agent-sync" || failed "agent-sync failed. Install jq (brew install jq) and run agent-sync"
fi

step "Local models (Ollama)"
if command -v ollama >/dev/null; then
  brew services start ollama >/dev/null 2>&1 && ok "Ollama running (starts at login)"
  sleep 2
  if ask "Download $OLLAMA_EMBED_MODEL (RAG embeddings, ~0.3 GB)" Y; then
    ollama pull "$OLLAMA_EMBED_MODEL" && ok "$OLLAMA_EMBED_MODEL"
  fi
  if ask "Download $OLLAMA_CHAT_MODEL (local chat model, ~8 GB)" N; then
    ollama pull "$OLLAMA_CHAT_MODEL" && ok "$OLLAMA_CHAT_MODEL"
  fi
else
  warn "Ollama isn't installed (it's in the Brewfile)"
fi

step "VS Code"
CODE="$(command -v code || echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code")"
if [ -x "$CODE" ]; then
  if ask "Use vscode/settings.json and the Python file templates (your current ones get backed up)" Y; then
    link "$DOTFILES/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
    link "$DOTFILES/vscode/snippets/python.json" "$HOME/Library/Application Support/Code/User/snippets/python.json"
  fi
  if ask "Install the extensions in vscode/extensions.txt (and offer to remove the rest)" Y; then
    "$DOTFILES/bin/vscode-sync"
  fi
else
  warn "VS Code not found"
fi

step "PyCharm"
pycharm="${PYCHARM_APP:-PyCharm}.app"
if [ -d "/Applications/$pycharm" ] || [ -d "$HOME/Applications/$pycharm" ]; then
  if ask "Install the PyCharm plugins in jetbrains/plugins.txt (and offer to remove the rest)" Y; then
    "$DOTFILES/bin/pycharm-sync"
  fi
  info "For PyCharm's settings, sign in to your JetBrains account and turn on Settings > Backup and Sync"
else
  info "PyCharm isn't installed (JetBrains Toolbox in Brewfile.apps installs it), skipping"
fi

step "Projects folder"
projects="${NEWPROJ_DIR:-${CODE_DIR:-$HOME/Projects}}"
mkdir -p "$projects" && ok "$projects (newproj creates projects here, change it in ~/.zshrc.local)"

step "macOS preferences"
if ask "Apply my macOS tweaks (Finder, key repeat, no smart quotes, screenshots folder)" N; then
  bash "$DOTFILES/macos/defaults.sh"
fi

step "Done"
[ -n "$FAILED" ] && printf '%sHave a look at:%s%b\n' "$yellow" "$reset" "$FAILED"
cat <<EOF

Next steps:
  1. Open a new terminal tab so the new shell config loads
  2. gh auth login
  3. bash ~/dotfiles/scripts/new-ssh-key.sh     SSH key for GitHub + signed commits
  4. Edit ~/.zshrc.local and ~/.config/dotfiles/about-me.md
  5. secret set GROQ_API_KEY                    if you use hosted models (keys live in the Keychain)
  6. ai-doctor                                  everything should be green
  7. Open LuLu and BlockBlock once and allow them in System Settings > Privacy & Security

After that, run dotup once a week.
EOF
