# dotSafehouse

Thin wrapper around [eugene1g/agent-safehouse](https://github.com/eugene1g/agent-safehouse)
that defines how to run `claude` and `codex` safely for the `inato-marketplace`
workflow. Ships the `--enable` feature set, a small deny-only append-profile,
and zsh shortcuts.

No hand-rolled sandbox profile is kept here — all policy comes from upstream
`agent-safehouse`; this repo only layers on the deltas.

## What gets installed

| Thing | Destination | Source |
|---|---|---|
| `agent-safehouse` clone | `~/.local/share/agent-safehouse/` | [upstream](https://github.com/eugene1g/agent-safehouse) |
| `safehouse` CLI symlink | `~/.local/bin/safehouse` | `<clone>/bin/safehouse.sh` |
| Hardening deny append-profile | `~/.config/dotSafehouse/hardening-denies.sb` | `append/hardening-denies.template.sb` (with `__HOME__` substituted for your `$HOME`) |
| Shell aliases | block in `~/.zshrc` between `# >>> dotSafehouse (managed) >>>` markers | `shell/zshrc.snippet` |

## Enabled Safehouse features for inato-marketplace

`--enable=shell-init,ssh,docker,clipboard`

- `shell-init` — zsh startup files (`~/.zshrc`, `~/.zprofile`, completions)
- `ssh` — SSH agent socket + `known_hosts` writes (so `git push` works)
- `docker` — Docker/OrbStack/Rancher sockets (HIGH-RISK, opted in)
- `clipboard` — `pbcopy` / `pbpaste`

Not enabled: `1password`, `vscode`, `keychain`, `xcode`, `macos-gui`,
`microphone`, `spotlight`, `browser-native-messaging`, `chromium-*`.

Agent profiles (`claude-code.sb`, `codex.sb`) and toolchains (node, bun, etc.)
are auto-selected by Safehouse from the command after `--`.

## Hardening denies layered on top

The append-profile blocks (regardless of upstream changes):

- `~/.ssh/id_*`, `~/.ssh/*.pem`
- `~/.aws`, `~/.config/gcloud`
- `~/Library/Keychains`
- `~/Library/Application Support/{Slack,1Password}`

Trade-off: denying `~/Library/Keychains` means Codex can't use
macOS-Keychain-backed auth. Its OAuth tokens live under `~/.codex` (granted
RW by Safehouse's `codex.sb`), so interactive login still works.

## Install (any Mac)

```bash
git clone git@github.com:brian-xu-vlt/dotSafehouse.git ~/dotSafehouse
~/dotSafehouse/install.sh
exec zsh -l
```

`install.sh` is idempotent — rerun anytime. It also pulls the latest
`agent-safehouse` each run. Pin a specific ref via env:

```bash
DOTSAFEHOUSE_SAFEHOUSE_REF=<sha-or-tag> ~/dotSafehouse/install.sh
```

## Usage

```bash
cd ~/CODE/inato-marketplace
safe-claude           # Claude Code, sandboxed to this repo
safe-codex            # Codex CLI, sandboxed to this repo
safe-shell            # interactive zsh under the same sandbox (debugging)
safe-logs             # tail sandbox denials in another terminal
```

Safehouse infers the workdir from `pwd -P` and auto-emits ancestor literals
plus the workdir RW grant, so your current directory is always the one
granted read/write.

## Uninstall

```bash
~/dotSafehouse/uninstall.sh
```

(The cloned `agent-safehouse` source stays; remove it manually if you want.)

## Tweaking

- **More features**: edit `DOTSAFEHOUSE_ENABLE` in `shell/zshrc.snippet`, rerun `install.sh`.
- **Extra RO / RW dirs per launch**: `safe-claude --add-dirs-ro=/path` / `--add-dirs=/path`
  (Safehouse passes the flags through).
- **Different denies**: edit `append/hardening-denies.template.sb` and rerun `install.sh`.
