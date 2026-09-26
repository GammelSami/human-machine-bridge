#!/usr/bin/env bash
# Symlinks the configs in this repo to where the programs expect them.
# Idempotent; existing real files are moved to *.bak-<date> first, never deleted.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$repo/$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok       $dst"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    local bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$bak"
    echo "backed up $dst → $bak"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked   $dst → $src"
}

link espanso                   "$HOME/.config/espanso"
link keymapper/keymapper.conf  "$HOME/.config/keymapper.conf"
link run-or-raise/shortcuts.conf "$HOME/.config/run-or-raise/shortcuts.conf"
link scripts/clipboard-qr "$HOME/.local/bin/clipboard-qr"
link immich-screenshots "$HOME/.config/immich-screenshots"
link immich-screenshots/immich-screenshots.service "$HOME/.config/systemd/user/immich-screenshots.service"
