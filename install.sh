#!/bin/bash
# dotSafehouse installer — clones agent-safehouse, symlinks its CLI, renders
# the hardening-denies append-profile for this machine's $HOME, and symlinks
# the shell-agnostic safe-* commands. Idempotent: rerun after `git pull` to refresh.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SAFEHOUSE_SRC="${DOTSAFEHOUSE_SAFEHOUSE_SRC:-$HOME/.local/share/agent-safehouse}"
SAFEHOUSE_REF="${DOTSAFEHOUSE_SAFEHOUSE_REF:-main}"
SAFEHOUSE_REPO_URL="${DOTSAFEHOUSE_SAFEHOUSE_URL:-https://github.com/eugene1g/agent-safehouse.git}"
SAFEHOUSE_BIN_DST="$HOME/.local/bin/safehouse"
APPEND_TEMPLATE="$REPO_DIR/append/hardening-denies.template.sb"
APPEND_DST_DIR="$HOME/.config/dotSafehouse"
APPEND_DST="$APPEND_DST_DIR/hardening-denies.sb"
SAFE_SRC="$REPO_DIR/bin/safe"
SAFE_COMMANDS=(safe-claude safe-codex safe-shell safe-policy safe-explain safe-logs)
ZSHRC="$HOME/.zshrc"
MARK_BEGIN="# >>> dotSafehouse (managed) >>>"
MARK_END="# <<< dotSafehouse (managed) <<<"

log()  { printf '\033[1;36m[dotSafehouse]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dotSafehouse]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[dotSafehouse]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "dotSafehouse targets macOS only (sandbox-exec)."
command -v git >/dev/null || fail "git required"
[[ -x /usr/bin/sandbox-exec ]] || fail "/usr/bin/sandbox-exec missing"
[[ -f "$APPEND_TEMPLATE" ]] || fail "missing template: $APPEND_TEMPLATE"
[[ -x "$SAFE_SRC"        ]] || fail "missing command:  $SAFE_SRC"

# 1. Clone or update agent-safehouse
mkdir -p "$(dirname "$SAFEHOUSE_SRC")"
if [[ -d "$SAFEHOUSE_SRC/.git" ]]; then
  log "updating $SAFEHOUSE_SRC"
  git -C "$SAFEHOUSE_SRC" fetch --quiet origin
  git -C "$SAFEHOUSE_SRC" checkout --quiet "$SAFEHOUSE_REF"
  git -C "$SAFEHOUSE_SRC" pull --ff-only --quiet || true
else
  log "cloning $SAFEHOUSE_REPO_URL -> $SAFEHOUSE_SRC (ref: $SAFEHOUSE_REF)"
  git clone --quiet "$SAFEHOUSE_REPO_URL" "$SAFEHOUSE_SRC"
  git -C "$SAFEHOUSE_SRC" checkout --quiet "$SAFEHOUSE_REF"
fi

# 2. Install a wrapper into ~/.local/bin (NOT a symlink: safehouse.sh resolves
#    lib/ via dirname "$BASH_SOURCE", which would point at ~/.local/bin/lib
#    through a symlink and blow up).
mkdir -p "$(dirname "$SAFEHOUSE_BIN_DST")"
rm -f "$SAFEHOUSE_BIN_DST"
cat > "$SAFEHOUSE_BIN_DST" <<EOF
#!/usr/bin/env bash
exec "$SAFEHOUSE_SRC/bin/safehouse.sh" "\$@"
EOF
chmod +x "$SAFEHOUSE_BIN_DST"
log "wrote wrapper $SAFEHOUSE_BIN_DST -> $SAFEHOUSE_SRC/bin/safehouse.sh"

# 3. Render hardening-denies with this machine's $HOME
mkdir -p "$APPEND_DST_DIR"
sed "s|__HOME__|$HOME|g" "$APPEND_TEMPLATE" > "$APPEND_DST"
log "rendered $APPEND_DST"

# 4. Symlink safe-* commands into ~/.local/bin (works from any shell)
for command_name in "${SAFE_COMMANDS[@]}"; do
  ln -sfn "$SAFE_SRC" "$HOME/.local/bin/$command_name"
done
log "linked ${SAFE_COMMANDS[*]} -> $SAFE_SRC"

# 5. Remove the legacy zshrc block (its functions would shadow the commands)
if [[ -f "$ZSHRC" ]] && grep -qF "$MARK_BEGIN" "$ZSHRC"; then
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
  ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
  log "removed legacy dotSafehouse block from $ZSHRC"
fi

# 6. PATH sanity
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn "~/.local/bin is not in PATH; add it in your shell config (zsh: ~/.zprofile, fish: fish_add_path ~/.local/bin)" ;;
esac

# 7. Smoke-test: safehouse prints its help
if "$SAFEHOUSE_BIN_DST" --help >/dev/null 2>&1; then
  log "safehouse CLI ok"
else
  warn "safehouse --help returned non-zero; check \`$SAFEHOUSE_BIN_DST --help\` manually"
fi

log "done. Open a new shell (zsh, fish, bash...) then try, from a project dir:"
printf '    safe-shell -c "echo ok > /tmp/t && cat /tmp/t"\n'
printf '    safe-claude\n'
printf '    safe-codex\n'
printf '    safe-logs        # tail denials in another terminal\n'
