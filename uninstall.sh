#!/bin/bash
# Remove the zshrc block, the rendered hardening-denies file, and the
# safehouse symlink. The cloned agent-safehouse source is left intact (edit
# $DOTSAFEHOUSE_SAFEHOUSE_SRC / rm -rf yourself if you want it gone too).

set -euo pipefail

SAFEHOUSE_BIN_DST="$HOME/.local/bin/safehouse"
APPEND_DST="$HOME/.config/dotSafehouse/hardening-denies.sb"
ZSHRC="$HOME/.zshrc"
MARK_BEGIN="# >>> dotSafehouse (managed) >>>"
MARK_END="# <<< dotSafehouse (managed) <<<"

log() { printf '\033[1;36m[dotSafehouse]\033[0m %s\n' "$*"; }

if [[ -L "$SAFEHOUSE_BIN_DST" ]]; then
  rm "$SAFEHOUSE_BIN_DST"
  log "removed symlink $SAFEHOUSE_BIN_DST"
fi

if [[ -f "$APPEND_DST" ]]; then
  rm "$APPEND_DST"
  log "removed $APPEND_DST"
fi

if [[ -f "$ZSHRC" ]] && grep -qF "$MARK_BEGIN" "$ZSHRC"; then
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
  ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
  log "removed dotSafehouse block from $ZSHRC"
fi

log "done. 'exec zsh -l' to refresh the shell."
log "note: cloned agent-safehouse source not removed (DOTSAFEHOUSE_SAFEHOUSE_SRC default: ~/.local/share/agent-safehouse)"
