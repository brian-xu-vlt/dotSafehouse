# dotSafehouse

Thin wrapper around [eugene1g/agent-safehouse](https://github.com/eugene1g/agent-safehouse)
that defines how to run `claude` and `codex` safely. Ships the `--enable`
feature set, a small deny-only append-profile, and shell-agnostic `safe-*`
commands (zsh, fish, bash…).

No hand-rolled sandbox profile is kept here — all policy comes from upstream
`agent-safehouse`; this repo only layers on the deltas.

## What gets installed

| Thing | Destination | Source |
|---|---|---|
| `agent-safehouse` clone | `~/.local/share/agent-safehouse/` | [upstream](https://github.com/eugene1g/agent-safehouse) |
| `safehouse` CLI symlink | `~/.local/bin/safehouse` | `<clone>/bin/safehouse.sh` |
| Hardening deny append-profile | `~/.config/dotSafehouse/hardening-denies.sb` | `append/hardening-denies.template.sb` (with `__HOME__` substituted for your `$HOME`) |
| `safe-*` commands | symlinks `~/.local/bin/safe-{claude,codex,shell,policy,explain,logs}` | `bin/safe` (config in `shell/safehouse.env`) |

Older installs wrote a zsh block between `# >>> dotSafehouse (managed) >>>`
markers in `~/.zshrc`. `install.sh` removes it, so the functions no longer
shadow the commands.

## Enabled Safehouse features

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
```

Then open a new shell. Requires `~/.local/bin` on `PATH`.

`install.sh` is idempotent — rerun anytime. It also pulls the latest
`agent-safehouse` each run. Pin a specific ref via env:

```bash
DOTSAFEHOUSE_SAFEHOUSE_REF=<sha-or-tag> ~/dotSafehouse/install.sh
```

## Usage

```bash
cd /path/to/your/repo
safe-claude           # Claude Code, sandboxed to this repo
safe-codex            # Codex CLI, sandboxed to this repo
safe-shell            # interactive zsh under the same sandbox (debugging)
safe-policy           # page through the generated sandbox policy
safe-explain          # explain the effective grants
safe-logs             # tail sandbox denials in another terminal
safe claude           # same as safe-claude (any subcommand works this way)
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

- **More features / dirs**: edit `DOTSAFEHOUSE_ENABLE`, `DOTSAFEHOUSE_RW` or `DOTSAFEHOUSE_RO`
  in `shell/safehouse.env`. Takes effect on the next launch, no reinstall needed.
- **Extra RO / RW dirs per launch**: `safe-claude --add-dirs-ro=/path` / `--add-dirs=/path`
  (Safehouse passes the flags through).
- **Different denies**: edit `append/hardening-denies.template.sb` and rerun `install.sh`.
