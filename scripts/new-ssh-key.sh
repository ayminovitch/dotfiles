#!/bin/bash
# Create an SSH key for GitHub, keep its passphrase in the macOS Keychain, sign commits with it,
# and upload it to GitHub (for both login and signing).
#
#   bash ~/dotfiles/scripts/new-ssh-key.sh
#
# If it replaces an older key, delete the old one at https://github.com/settings/keys afterwards.
set -euo pipefail

say() { printf '\033[36m→ %s\033[0m\n' "$*"; }

email="$(git config --global user.email || true)"
read -r -p "Email for the key [${email:-you@example.com}]: " input
email="${input:-$email}"
[ -n "$email" ] || { echo "Need an email."; exit 1; }

key="$HOME/.ssh/id_ed25519_$(date +%Y)"
[ -e "$key" ] && { echo "$key already exists, nothing to do."; exit 1; }

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
say "Creating $key (pick a passphrase, it goes in the Keychain so you won't type it again)"
ssh-keygen -t ed25519 -a 100 -C "$email" -f "$key"

say "Adding it to the Keychain"
ssh-add --apple-use-keychain "$key"

config="$HOME/.ssh/config"
if ! grep -q "IdentityFile $key" "$config" 2>/dev/null; then
  say "Updating ~/.ssh/config"
  touch "$config" && chmod 600 "$config"
  {
    printf '\n# added by dotfiles/scripts/new-ssh-key.sh\n'
    printf 'Host *\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile %s\n' "$key"
  } >> "$config"
fi

say "Signing commits and tags with it"
allowed="$HOME/.ssh/allowed_signers"
printf '%s %s\n' "$email" "$(cat "$key.pub")" >> "$allowed"
git config --global gpg.format ssh
git config --global user.signingkey "$key.pub"
git config --global gpg.ssh.allowedSignersFile "$allowed"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  say "Uploading to GitHub"
  gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key
  gh ssh-key add "$key.pub" --title "MacBook $(date +%Y-%m-%d)" --type authentication
  gh ssh-key add "$key.pub" --title "MacBook signing $(date +%Y-%m-%d)" --type signing
else
  echo
  echo "gh isn't logged in. Either run 'gh auth login' and then the two 'gh ssh-key add' lines in"
  echo "this script, or paste the key below at https://github.com/settings/ssh/new twice"
  echo "(once as Authentication, once as Signing):"
  echo
  cat "$key.pub"
fi

echo
say "Done. Test it with: ssh -T git@github.com"
