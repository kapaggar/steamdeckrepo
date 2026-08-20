# Steam Deck OLED helpers

Mac-managed tooling for a Steam Deck OLED on the LAN (`deck@10.0.0.143`).
This repo is **not** DIPI Staff Android — it only holds Deck helpers, bootstrap, and local-AI layout notes.

Canonical tree is this repository. On the Mac, `~/.config/steamdeck/*` are symlinks into `helpers/` so existing `source ~/.config/steamdeck/steamdeck.bash` keeps working.

## Layout

```
helpers/                 Mac + Deck scripts
  steamdeck.bash         Mac `deck` / `deckping` / push-pull (sourced from ~/.bashrc)
  deck-help.bash         Shared help text
  deck-remote.bashrc     On-Deck aliases and `deck` (Konsole / Desktop Mode)
  bootstrap.sh           $HOME-first bootstrap (podman, distrobox, optional boxes)
  audit.sh               Update-surviving layout checklist
  ai-status.sh           Ollama + Decky + Open WebUI status
  install-decky.sh       Finish Decky Loader after SteamOS updates
docs/architecture.md     $HOME-first, Distrobox, Ollama, Decky, Open WebUI
```

## Mac setup

`~/.bashrc` sources `~/.config/steamdeck/steamdeck.bash` (symlink → this repo). New shells get `deck`:

```bash
deck help          # Mac + Deck command map
deck ping          # SSH reachability
deck ssh           # interactive shell on the Deck
deck ai            # local AI status
```

Override the target with `STEAMDECK_HOST`, `STEAMDECK_USER`, or `STEAMDECK_SSH`.

## Sync helpers to the Deck

After editing files here, copy the helpers (not this git metadata) to the Deck:

```bash
rsync -avh --progress \
  /Users/wizops/DIPI/steam/helpers/ \
  deck@10.0.0.143:~/.config/steamdeck/
```

On the Deck, `~/.bashrc` should `source ~/.config/steamdeck/deck-remote.bashrc`.
Keep Deck copies as real files (SteamOS `$HOME`); do not symlink the Deck at the Mac repo.

## Local AI (Deck localhost only)

| Piece | Bind |
| --- | --- |
| Ollama (Distrobox `ai-box`) | `127.0.0.1:11434` |
| Open WebUI (rootless Quadlet) | `127.0.0.1:3000` |
| Decky + bonsAI | Gaming Mode QAM; talk to the Distrobox unit |

Do not use bonsAI **Install Ollama**. Do not bind these services on `0.0.0.0`.
Local inference competes with running games.

See [docs/architecture.md](docs/architecture.md).
