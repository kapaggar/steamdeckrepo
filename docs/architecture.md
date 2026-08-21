# Steam Deck OLED — update-surviving layout

SteamOS image updates wipe `/usr`. Persistent tools live under `$HOME`. This file is the short architecture note for the helpers in this repo.

## Principle

| Layer | Fate | Examples |
| --- | --- | --- |
| `/usr` | Disposable (SteamOS image) | Do not `pacman -S` tools here |
| `$HOME` | Persistent | `~/.local/bin`, `~/.config`, `~/Applications`, `~/containers`, `~/.ollama`, `~/src` |

Bootstrap (`helpers/bootstrap.sh`) creates the baseline dirs, enables `podman.socket`, and can install Distrobox into `~/.local`.

```
deck bootstrap                    # dirs + podman.socket + ~/.local distrobox
deck bootstrap --with-container   # also create Distrobox arch-tools
deck bootstrap --with-ai          # also create Distrobox ai-box
deck bootstrap --with-dev         # also create Distrobox dev (ubuntu:24.04)
deck audit                        # checklist
```

Headless user units at boot need linger once (password on the Deck):

```
sudo loginctl enable-linger deck
```

## Distrobox

| Box | Image | Role |
| --- | --- | --- |
| `arch-tools` | `archlinux:latest` | General user-space Arch tools (`deck box`) |
| `ai-box` | `archlinux:latest` | Official Ollama lives **inside** this box (`deck box-ai`) |
| `dev` | `ubuntu:24.04` | Compile toolchain (`deck dev` / `deck box-dev`). Project tree is host `~/src`. Independent of `ai-box`. |

Distrobox itself is installed at `~/.local/bin/distrobox` so it survives image updates. Toolchains in `dev` do **not** touch SteamOS `/usr`. Project sources stay on the host at `~/src` (shared `$HOME`; no container copies).

## Ollama — `127.0.0.1:11434`

- Host unit: `~/.config/systemd/user/ollama.service` (`systemctl --user`)
- `OLLAMA_HOST=127.0.0.1:11434` — localhost only, not on the LAN
- Models persist on the host at `~/.ollama` (bind-mounted into `ai-box`)
- CLI wrapper: `~/.local/bin/ollama` must be a Distrobox wrapper, **not** a host ELF
- Marker: `~/.config/steamdeck/ollama-managed-by-distrobox` (Deck-side; not committed)

Do **not** use bonsAI **Install Ollama**. That drops a host tarball under `~/.local/lib/ollama` and fights `ai-box`.

GPU later (do not enable ROCm): drop `OLLAMA_NO_GPU=1`, optionally `OLLAMA_VULKAN=1`, recreate `ai-box` with `--device=/dev/dri`.

```
deck ai
deck ollama status|logs|start|stop|restart
```

Local inference competes with running games.

## Open WebUI — `127.0.0.1:3000`

- Rootless Podman Quadlet: `~/.config/containers/systemd/open-webui.container`
- User unit: `open-webui.service`
- Persist dir: `~/containers/open-webui`
- Pasta host-loopback; listen on `127.0.0.1:3000` only (not `0.0.0.0`)
- Desktop Chrome: unpacked new-tab extension + bookmarks-bar favorite (see operator manual)

```
deck webui
deck webui start|stop|restart|logs
```

SSH tunnel from the Mac if you need the UI remotely. Do not publish it on the LAN.

## Decky (Gaming Mode QAM)

- User-space tree: `~/homebrew/` (PluginLoader + plugins)
- System unit: `plugin_loader.service` (SteamOS updates can drop `/etc` units)
- Plugins: bonsAI (chat UI), decky-ollama (must talk to `127.0.0.1` + the user `ollama.service`), and Deck Focus (QAM stop/start of the AI stack)
- Deck Focus backend runs `~/.config/steamdeck/game-focus.sh` / `ai-focus.sh` as user `deck` (PluginLoader is root; it uses `runuser -u deck`)
- After a SteamOS image update, re-run `helpers/install-decky.sh` on the Deck and recopy `plugins/deck-focus/`
- Restart Game Mode once if the QAM plug icon is missing

bonsAI chat is fine. Skip bonsAI install/update of Ollama; keep `decky-ollama` from binding `0.0.0.0` or `pkill`ing the Distrobox unit.

## Quadlets

User Quadlets live in `~/.config/containers/systemd/*.container`. After adding one:

```
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
```

`bootstrap.sh` writes commented `example.container`, `example-postgres.container`, and `example-redis.container` if missing. Do **not** enable postgres/redis/localstack by default (handheld RAM).

Docker-compatible API (not every Docker extension works):

```
systemctl --user enable --now podman.socket
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

## Development and coding

```
SteamOS host
├─ Cursor              → ~/Applications/cursor (cloud-heavy AI)
├─ VS Code             → user Flatpak; Continue → 127.0.0.1:11434
├─ Distrobox: dev      → ubuntu:24.04 (gcc/python/node/go; ~/src)
└─ rootless Podman     → podman.socket; Quadlet examples only
```

```
deck dev
deck vscode
deck vscode install
```

## What this repo does not store

No `auth.json`, sudoers fragments, API keys, `~/.grok` state, SSH keys, Ollama models, or `*.elf` quarantine binaries. Those stay on the Deck or in Mac home dirs outside git.
