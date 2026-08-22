# Steam Deck OLED — operator manual

Owner guide for **सत्यBrave**. This is the single document for everything added on top of a **stock SteamOS** image on this Deck.

**Last verified:** 2026-08-22, live SSH to `deck@10.0.0.143` (Flatpak RetroArch + official ES-DE AppImage). Hardware is **Galileo** (OLED). SteamOS **3.8.16** (`BUILD_ID=20260716.1`, branch `stable`, `steamos-readonly` **enabled**).

Related short notes: [architecture.md](architecture.md) (layout only) and the [repo README](../README.md) (Mac helpers). This manual is the operator book.

No passwords, API keys, or SSH private keys are stored in this repo.

---

## 1. What stock SteamOS already was

Valve’s image is an Arch-like, **A/B immutable OS**. You did not start from a normal desktop Linux install.

| Stock piece | What it means |
| --- | --- |
| Immutable `/usr` | `steamos-readonly` is enabled. Do not `pacman -S` tools into `/usr`. Image updates replace the OS partition. |
| User `deck` | uid 1000, in `wheel`. Desktop Mode is KDE; default session is **Game Mode** (Gamescope + Steam). |
| Game Mode | `gamescope-session.service`, Steam Big Picture / QAM, controller-first. “Return to Gaming Mode” is stock. |
| Desktop Mode | Plasma + Konsole + Discover. Switch from Game Mode (power menu) or the Steam + … combo. |
| Discover / Flatpak | Stock app store. System Flatpaks live under `/var/lib/flatpak`; user Flatpaks under `~/.local/share/flatpak`. |
| Steam library | `~/.steam/steam` → `~/.local/share/Steam`. Games, Proton, and **Steam RetroArch** persist under `$HOME`. |
| Podman on the image | SteamOS 3.8 ships **Podman 5.5.2**. The *user* socket and Quadlets are what we added. |
| SSH server | `sshd` is a SteamOS unit. We enabled it and added a key. It listens on `0.0.0.0:22` (LAN SSH is intentional). |
| `wheel` sudo | `/etc/sudoers.d/wheel` is `%wheel ALL=(ALL) ALL` (password required). Our nopasswd file is a later drop-in. |
| Devkit listener | Stock `steamos-devkit-service.py` on `0.0.0.0:32000`. Not part of the local-AI stack. |

**Rule of the house:** `/usr` is disposable. Persistent work lives under `$HOME` (`/home/deck`). `/etc` is *not* `$HOME` — SteamOS updates can drop system units (Decky’s `plugin_loader.service` is the usual casualty) and can reset `/etc/sudoers.d`.

---

## 2. Inventory

Survive column: **yes** = under `$HOME` or user Flatpak store. **re-check** = `/etc` or a system unit; confirm after a SteamOS image update. **image** = comes back with SteamOS / does not need us.

| Item | Where it lives | Survives SteamOS update? | How to start / stop |
| --- | --- | --- | --- |
| This repo’s helpers (Deck copy) | `~/.config/steamdeck/` (real files, not Mac symlinks) | yes | `source ~/.bashrc` (already wired). Resync from Mac after edits. Includes `game-focus.sh` / `ai-focus.sh`. |
| Mac control plane | `~/.config/steamdeck` → `/Users/wizops/DIPI/steam/helpers/` | n/a (Mac) | `source ~/.bashrc` then `deck …` |
| Distrobox CLI | `~/.local/bin/distrobox` (1.8.2.5) | yes | `deck bootstrap` reinstalls if missing |
| Distrobox `ai-box` | `archlinux:latest` container, `$HOME` storage | yes (container store in `$HOME`) | `deck box-ai` / `distrobox enter ai-box` |
| Distrobox `dev` | `ubuntu:24.04` container, `$HOME` + `~/src` | yes (container store in `$HOME`) | `deck dev` / `deck box-dev` / `distrobox enter dev` |
| VS Code | user Flatpak `com.visualstudio.code` + `~/.local/bin/code` | yes | Desktop **Visual Studio Code**, `code`, `deck vscode` |
| Continue | `~/.continue/` → Ollama `127.0.0.1:11434` | yes | VS Code Continue pane (does not start Ollama) |
| kubectl / helm | `~/.local/bin` (official static bins) | yes | on PATH in `dev` (shared `$HOME`) |
| Distrobox `arch-tools` | **not created** | — | Optional: `deck bootstrap --with-container` |
| Ollama 0.32.14 | inside `ai-box`; models `~/.ollama` | yes | `deck ollama start\|stop\|restart` or `systemctl --user … ollama.service` |
| `~/.local/bin/ollama` | Distrobox **wrapper** (must not be a host ELF) | yes | `ollama list` / `ollama pull …` |
| Open WebUI | Quadlet `~/.config/containers/systemd/open-webui.container`; data `~/containers/open-webui` | yes | `deck webui start\|stop\|restart` |
| Jellyfin | Quadlet `~/.config/containers/systemd/jellyfin.container`; config `~/containers/jellyfin/config`; media `~/media` | yes | `deck jellyfin start\|stop\|restart` |
| Jellyfin Desktop | user Flatpak `org.jellyfin.JellyfinDesktop` 2.0.0 (client only) | yes | Desktop **Jellyfin**; Steam non-Steam **Jellyfin** (TV fullscreen) |
| *arr (Radarr / Sonarr / Prowlarr / Bazarr) | Quadlets `~/.config/containers/systemd/{radarr,sonarr,prowlarr,bazarr}.container`; config `~/containers/<name>`; libraries `~/media/{movies,tv}` | yes | `deck arr` / `deck arr start\|stop\|restart` |
| Podman user socket | `podman.socket` (user) | image binary; enable is user | `systemctl --user start\|stop podman.socket` |
| User linger | `loginctl` linger for `deck` | usually yes; re-check | `sudo loginctl enable-linger deck` once |
| Decky Loader v3.2.6 | `~/homebrew/` + **system** `plugin_loader.service` | tree yes; **unit re-check** | `sudo systemctl start\|stop plugin_loader`; after updates: `install-decky.sh` |
| bonsAI 0.4.9 | `~/homebrew/plugins/bonsAI` | yes | Enable in QAM (Decky plug). Chat only. |
| decky-ollama (patched) | `~/homebrew/plugins/decky-ollama` | yes | QAM start/stop → user `ollama.service` on `127.0.0.1` |
| Deck Focus | `~/homebrew/plugins/deck-focus` | yes | QAM **Game focus (stop AI)** / **AI focus (start stack)** → `game-focus.sh` / `ai-focus.sh` |
| Cursor Agent CLI | `~/.local/bin/agent` → `~/.local/share/cursor-agent/` (2026.08.11-e8db854) | yes | Desktop **Cursor Agent**, or `agent` / `deckagent` |
| Cursor IDE | `~/Applications/cursor/Cursor-3.16.29-x86_64.AppImage` + `~/.local/bin/cursor` | yes | Desktop **Cursor** |
| Grok CLI | `~/.grok/bin/grok` (1.0.5) | yes | Desktop **Grok CLI**, or `grok` / `deckgrok` |
| GitHub CLI | `~/.local/bin/gh` (2.97.0) | yes | `gh` |
| Chrome Flatpak | `com.google.Chrome` **system** (151.x) | typically yes (`/var`) | Desktop **Google Chrome** (our launcher) |
| Chrome Open WebUI new-tab + bookmark | `~/.local/share/steamdeck/chrome-open-webui-newtab` + `~/.local/bin/google-chrome` + user `.desktop` | yes | Fully quit Chrome, then Desktop **Google Chrome**; new tab button + bookmarks bar |
| Firefox Flatpak | `org.mozilla.firefox` **system** (154.0) | typically yes | Discover / app menu (http(s) is **not** the default) |
| `xdg-open` wrapper | `~/.local/bin/xdg-open` → Chrome for `http(s)` | yes | used by Cursor / login flows |
| EmuDeck AppImage | `~/Applications/EmuDeck.AppImage` + `~/.local/bin/emudeck` | yes | Desktop **EmuDeck** |
| ES-DE AppImage | `~/Applications/ES-DE.AppImage` (official 3.4.1 Steam Deck build) | yes | Desktop **ES-DE**; Steam **EmulationStationDE** |
| Live ROM tree | `~/Downloads/emulatorom/Emulation` (not the empty `~/Emulation` stub) | yes | ES-DE / EmuDeck launchers |
| Emulator AppImages | `~/Applications/*.AppImage` (see §8) | yes | matching `.desktop` launchers |
| EmuDeck Flatpaks | user Flatpaks (Dolphin, PPSSPP, melonDS, …) | yes | Discover / Steam ROM Manager |
| Steam RetroArch | leftover `~/.steam/steam/steamapps/common/RetroArch` (~804 MB, app 1118310) | yes | Steam library only — **not** wired to EmuDeck |
| Flatpak RetroArch | `org.libretro.RetroArch` (user, 1.22.2) | yes | EmuDeck launchers + Desktop **RetroArch** |
| Gyro DSU | `~/sdgyrodsu/` + user `sdgyrodsu.service` | yes | `systemctl --user start\|stop sdgyrodsu`; Desktop update/uninstall helpers |
| Protontricks | user Flatpak `com.github.Matoking.protontricks` 1.14.1 + `~/.local/bin/protontricks` | yes | `protontricks -l` / `bash ~/.config/steamdeck/install-protontricks.sh` |
| Passwordless sudo | `/etc/sudoers.d/zz-deck-nopasswd` | **re-check** | must sort **after** `wheel` |
| SSH | `sshd` enabled; Mac key login | image + `$HOME/.ssh` | `sudo systemctl start\|stop sshd` |
| Desktop shortcuts | `~/Desktop/` + `~/.local/share/applications/` | yes | see §7 |

**Not installed:** Distrobox `arch-tools` (audit warning only). Optional if you want a general Arch toolbox besides `ai-box` / `dev`.

---

## 3. Network / SSH / sudo

### LAN identity

| | |
| --- | --- |
| User | `deck` |
| IP (this LAN) | `10.0.0.143` |
| SSH | passwordless from the Mac (`BatchMode` works) |
| Mac Host aliases | `ssh steamdeck` or `ssh deck` (`~/.ssh/config` → `10.0.0.143`) |

Override from any Mac shell: `STEAMDECK_HOST`, `STEAMDECK_USER`, `STEAMDECK_SSH`.

### What is on the network vs localhost

| Bind | Service | Intent |
| --- | --- | --- |
| `0.0.0.0:22` | `sshd` | Mac control plane. Keep it. |
| `127.0.0.1:11434` | Ollama | **localhost only** — not on the LAN |
| `127.0.0.1:3000` | Open WebUI (pasta publishes host port) | **localhost only** |
| `127.0.0.1:1337` | Decky PluginLoader | localhost |
| `0.0.0.0:8096` | Jellyfin | LAN UI; media `~/media` |
| `127.0.0.1:7878` | Radarr | **localhost only** — movies library manager |
| `127.0.0.1:8989` | Sonarr | **localhost only** — TV library manager |
| `127.0.0.1:9696` | Prowlarr | **localhost only** — indexer manager (you add indexers) |
| `127.0.0.1:6767` | Bazarr | **localhost only** — subtitles |
| `0.0.0.0:32000` | stock SteamOS devkit | Valve, not ours |

Do **not** move Ollama or Open WebUI to `0.0.0.0` to “reach them from the Mac.” Use an SSH tunnel instead:

```bash
ssh -L 3000:127.0.0.1:3000 -L 11434:127.0.0.1:11434 \
  -L 7878:127.0.0.1:7878 -L 8989:127.0.0.1:8989 \
  -L 9696:127.0.0.1:9696 -L 6767:127.0.0.1:6767 \
  deck@10.0.0.143
```

Then on the Mac: `http://127.0.0.1:3000` (WebUI), `http://127.0.0.1:11434` (Ollama API), and the *arr UIs on `7878` / `8989` / `9696` / `6767`.

### Sudo

- Stock: `wheel` requires a password.
- Added: `/etc/sudoers.d/zz-deck-nopasswd` → `deck ALL=(ALL) NOPASSWD: ALL`.
- The `zz-` prefix is required so this file is read **after** `wheel`. A name that sorts *before* `wheel` would lose.
- This file is under `/etc`. After a SteamOS image update, run `sudo -n true` from SSH. If it fails, recreate the drop-in on the Deck (Desktop Konsole or interactive SSH), then `sudo chmod 440 /etc/sudoers.d/zz-deck-nopasswd`.

This repo does **not** store the sudoers fragment.

### Linger

`loginctl show-user deck -p Linger` is **yes**. Headless user units (`ollama.service`, Quadlets, `podman.socket`) start at boot even in Game Mode. If linger is ever `no`:

```bash
sudo loginctl enable-linger deck
```

---

## 4. Mac control plane (`deck` commands)

Canonical tree: `/Users/wizops/DIPI/steam`. On the Mac, `~/.config/steamdeck/*` are **symlinks** into `helpers/`. `~/.bashrc` sources `steamdeck.bash` so new terminals get `deck`.

On the Deck, the same scripts are **real files** under `~/.config/steamdeck/`. Do not symlink the Deck at the Mac repo. `~/.bashrc` and `~/.bash_profile` put `~/.local/bin` and `~/.grok/bin` on `PATH` and source `deck-remote.bashrc`.

### Everyday Mac commands

```bash
deck help              # full map
deck ping              # SSH reachability (alias: dping)
deck ssh               # interactive shell (aliases: decksh, dsh)
deck ai                # Ollama + Decky + Open WebUI status
deck game              # Game focus: stop Ollama + Open WebUI (same as QAM STOP)
deck ai-off            # same as deck game
deck ai-on             # AI focus: start Ollama, then Open WebUI (same as QAM START)
deck ollama            # status + user unit
deck ollama start|stop|restart|logs
deck webui             # http://127.0.0.1:3000 + status
deck webui start|stop|restart|logs
deck jellyfin          # http://127.0.0.1:8096 and http://10.0.0.143:8096
deck jellyfin start|stop|restart|logs
deck arr               # Radarr/Sonarr/Prowlarr/Bazarr on 127.0.0.1
deck arr start|stop|restart|logs|install
deck audit             # ~/.config/steamdeck/audit.sh
deck bootstrap         # dirs, podman.socket, Distrobox
deck bootstrap --with-ai
deck box-ai            # distrobox enter ai-box
deck dev               # distrobox enter dev (Ubuntu toolchain)
deck box-dev           # same as deck dev
deck vscode            # launch host VS Code on the Deck
deck vscode install    # re-run Flatpak + Continue installer
deck df                # disk + library sizes
deck games             # steamapps/common folder names
deck protontricks …    # Protontricks on the Deck (Flatpak wrapper)
```

### Copy files

```bash
deckpush LOCAL [REMOTE]          # default remote: ~/Downloads
deckpull REMOTE [LOCAL]          # default local: .
deckpushgame GAME_FOLDER_NAME    # Mac Steam library → Deck (then Install to verify)
deckpullgame GAME_FOLDER_NAME
deckpullsaves [DIR]              # default ~/Backups/steamdeck-saves
deckpushsaves [DIR]
deckscreenshots [DIR]
```

### Remote CLIs

```bash
deckagent [args]       # Cursor Agent on the Deck
deckgrok [args]        # Grok CLI on the Deck
```

### Resync helpers after you edit this repo

```bash
rsync -avh --progress \
  /Users/wizops/DIPI/steam/helpers/ \
  deck@10.0.0.143:~/.config/steamdeck/
```

(`steamdeck.bash` is Mac-oriented; shipping it to the Deck is harmless. The Deck uses `deck-remote.bashrc`.)

---

## 5. Local AI stack

All of this is **CPU inference**, localhost only. It **competes with games** (RAM + cores). Open WebUI alone was ~2.2 GiB RSS when last checked; stop it before a heavy title.

```
QAM bonsAI / decky-ollama
        │
        ▼
  127.0.0.1:11434   Ollama 0.32.14 in Distrobox ai-box
        ▲                  (OLLAMA_NO_GPU=1)
        │                  models: ~/.ollama
        │
  pasta 10.0.2.2:11434  ← Open WebUI Quadlet
        │
  127.0.0.1:3000
```

### Ollama

- **Where:** official Ollama **inside** `ai-box` (`docker.io/library/archlinux:latest`).
- **Unit:** `~/.config/systemd/user/ollama.service` → `distrobox enter -T ai-box -- env OLLAMA_HOST=127.0.0.1:11434 OLLAMA_NO_GPU=1 ollama serve`.
- **CLI:** `~/.local/bin/ollama` must stay a Distrobox wrapper. If `file` says ELF, bonsAI (or a host tarball) replaced it — fix that, do not run two servers.
- **Marker:** `~/.config/steamdeck/ollama-managed-by-distrobox` (Deck-only; not in git).
- **Model pulled:** `qwen2.5:1.5b` (~0.9 GiB). Do not pull 30B-class models on this handheld.
- **GPU later (experimental):** drop `OLLAMA_NO_GPU=1`, optionally `OLLAMA_VULKAN=1`, recreate `ai-box` with `--device=/dev/dri`. **Do not enable ROCm.**

```bash
deck ai
deck ollama status
deck ollama logs
# on Deck:
ollama list
ollama pull qwen2.5:1.5b
```

### Decky QAM

- **Loader:** v3.2.6, `~/homebrew/services/PluginLoader`, system unit `plugin_loader.service` (`/etc/systemd/system/`).
- **Plugins running:** bonsAI, decky-ollama, **Deck Focus** (all under `~/homebrew/plugins/`).
- **QAM:** Game Mode → … (Quick Access) → plug icon. If the icon is missing, **restart Game Mode once** (or reboot).
- **Deck Focus:** QAM → Decky → **Deck Focus**. Two large buttons:
  - **Game focus (stop AI)** — runs `~/.config/steamdeck/game-focus.sh` as user `deck` (not root). Stops `open-webui.service`, `ollama.service`, `jellyfin.service`, `radarr` / `sonarr` / `prowlarr` / `bazarr` if present, then our rootless Podman containers `open-webui` and `ai-box`. Does **not** stop Steam, `plugin_loader`, Flatpak Chrome/Firefox, or `sdgyrodsu`.
  - **AI focus (start stack)** — runs `~/.config/steamdeck/ai-focus.sh` as `deck`. Starts `ollama.service`, waits until `127.0.0.1:11434` answers, then starts `open-webui.service`.
  Same actions from the Mac: `deck game` / `deck ai-off` (stop) and `deck ai-on` (start). Plugin source lives in this repo at `plugins/deck-focus/`.
- **bonsAI:** chat UI pointed at `http://127.0.0.1:11434`. **Never tap Install Ollama or Update installed.** That drops a host tarball in `~/.local/lib/ollama` (~2 GiB CUDA/Vulkan junk) and fights `ai-box`.
- **decky-ollama:** patched so start/stop is `systemctl --user start|stop ollama.service` and the API is `127.0.0.1:11434`. It must **not** reinstall host Ollama, bind `0.0.0.0`, or `pkill` the Distrobox server. If a plugin update reverts that, restore the patched `main.py` and re-check `deck ai`.

### Open WebUI

- **Image:** `ghcr.io/open-webui/open-webui:main` (rootless Quadlet).
- **Host URL:** `http://127.0.0.1:3000` (Desktop: **Open WebUI**, or Chrome new-tab / bookmarks bar).
- **Why `10.0.2.2`:** pasta `--map-host-loopback 10.0.2.2` reaches host `127.0.0.1:11434`. `host.containers.internal` was connection-refused because Ollama is localhost-only. Do not “fix” that by binding Ollama on `0.0.0.0`.
- **Persist:** `~/containers/open-webui`.
- **From the Mac:** SSH tunnel (§3), not a LAN publish.

```bash
deck webui
deck webui start|stop|restart
deck webui logs
```

First WebUI visit may ask you to create a **local** admin account. That stays on the Deck in `~/containers/open-webui`. It is not in this repo.

### Jellyfin

Manual Quadlet (`jellyfin.service`), not the official SteamOS installer (that script is interactive; `~/src/jellyfin-on-steamOS` is a leftover clone only — do not re-run it). URLs: [http://127.0.0.1:8096](http://127.0.0.1:8096) on the Deck or [http://10.0.0.143:8096](http://10.0.0.143:8096) on the LAN. Libraries read `~/media` (mounted read-only). Game focus stops `jellyfin.service`; AI focus does not start it.

**First-run wizard:** already completed on this Deck. Sign in at those URLs; no leftover admin wizard.

**Gaming Mode client:** user Flatpak `org.jellyfin.JellyfinDesktop` 2.0.0. It is a client only — do **not** install `org.jellyfin.JellyfinServer`. Desktop **Jellyfin**; Steam library **Jellyfin** launches `--fullscreen --tv`. First client launch: add server `http://127.0.0.1:8096`.

### *arr library managers (localhost)

Library managers next to Jellyfin. **Configure indexers yourself; we do not ship any.** No pirate indexer lists, torrent-site configs, Usenet keys, or download clients (qBittorrent / SABnzbd were skipped — none already on this Deck).

| App | Unit | URL (Deck / SSH `-L`) | Data | Library bind |
| --- | --- | --- | --- | --- |
| Radarr | `radarr.service` | [http://127.0.0.1:7878](http://127.0.0.1:7878) | `~/containers/radarr` | `~/media/movies` |
| Sonarr | `sonarr.service` | [http://127.0.0.1:8989](http://127.0.0.1:8989) | `~/containers/sonarr` | `~/media/tv` |
| Prowlarr | `prowlarr.service` | [http://127.0.0.1:9696](http://127.0.0.1:9696) | `~/containers/prowlarr` | — |
| Bazarr | `bazarr.service` | [http://127.0.0.1:6767](http://127.0.0.1:6767) | `~/containers/bazarr` | movies + tv |

**Compatibility (Galileo OLED, SteamOS 3.8.16, x86_64):**

- Official **linux/amd64** linuxserver images work on this Deck. It is not ARM.
- Idle RAM is modest: Radarr ~235 MiB, Sonarr ~200 MiB, Prowlarr ~225 MiB, Bazarr ~330 MiB (~1 GiB together). **Jellyfin transcoding + *arr + Ollama together will fight the 15W APU** (Jellyfin was ~2 GiB and Open WebUI ~2.3 GiB when last checked). Game focus must stop *arr (and already stops Jellyfin / Ollama / Open WebUI).
- Rootless Podman Quadlets under `$HOME`, same pattern as `jellyfin.container`.
- Images listen `0.0.0.0` inside the container; host publish is `127.0.0.1:PORT:PORT` (admin tools on a handheld that also games). Not on the LAN.
- `PUID=1000` `PGID=1000` `TZ=America/Los_Angeles`, `UserNS=keep-id`, pasta `--map-host-loopback 10.0.2.2`.
- Empty stubs: `~/media/movies`, `~/media/tv`, `~/media/downloads`. No copyrighted media is installed.

When linking apps **inside** a container (Prowlarr → Radarr/Sonarr, Bazarr → Radarr/Sonarr), use `http://10.0.2.2:<port>` — the same pasta host-loopback as Open WebUI → Ollama. `127.0.0.1` inside a box is that box, not the host.

**Skipped:** Readarr (troubled project), Whisparr, Lidarr (extra RAM; add later if you want music), qBittorrent / SABnzbd (no download client already present).

```bash
deck arr
deck arr start|stop|restart
# re-apply Quadlets after a SteamOS wipe of nothing (they live in $HOME):
deck arr install
```

From the Mac, tunnel (§3); do not move these binds to `0.0.0.0`.

---

## 6. Development and coding

Host editors + Distrobox toolchains. **Independent** of `ai-box`, Ollama, Open WebUI, Decky, and Jellyfin. Game focus does **not** stop `dev` or VS Code. SteamOS **`/usr` stays untouched.**

```
SteamOS host
├─ Cursor              → ~/Applications/cursor (cloud-heavy AI)
├─ VS Code             → user Flatpak com.visualstudio.code
│   └─ Continue        → local Ollama at 127.0.0.1:11434  (qwen2.5:1.5b)
├─ Distrobox: dev      → ubuntu:24.04
│   ├─ compilers / language runtimes / CLIs
│   └─ kubectl / helm  → ~/.local/bin (shared $HOME)
└─ rootless Podman
    ├─ podman.socket user (enable --now)
    └─ Quadlet examples for later project services (not started)
```

Project tree is host **`~/src`**. Distrobox bind-mounts `$HOME` — **no container copies** of source. Clone real repos as `~/src/<name>`.

### Distrobox `dev`

| | |
| --- | --- |
| Name | `dev` |
| Image | `ubuntu:24.04` (`docker.io/library/ubuntu:24.04`) |
| Home | host `$HOME` (`/home/deck`) |
| Enter (Deck) | `deck dev` / `deck box-dev` / `distrobox enter dev` |
| Enter (Mac) | `deck dev` / `deck box-dev` |

Packages inside the box (apt, not SteamOS): `build-essential` `git` `curl` `python3` `python3-venv` `nodejs` `npm` `golang-go`, plus `ca-certificates` `unzip` `jq` `ripgrep` `fd-find` (`fdfind`).

`kubectl` / `helm` are **not** in Ubuntu 24.04 repos. Official static binaries live in `~/.local/bin` (visible in the box). Reinstall: `bash ~/.config/steamdeck/install-dev-clis.sh`.

Do **not** `apt install` VS Code inside the box (snap-heavy). rustup was skipped; install later inside `dev` if you want Rust.

If `dev` already exists, **reuse it**. Never recreate `ai-box` for this.

```bash
distrobox create --name dev --image ubuntu:24.04 --yes
deck bootstrap --with-dev    # create only, if missing
```

### VS Code (host)

User Flatpak — not `/usr`, not snap. Filesystem override `home` so it sees `~/src` and Distrobox. Terminals enter the box via **`flatpak-spawn --host`** (sandbox cannot run host `podman` directly).

| | |
| --- | --- |
| Launch | Desktop **Visual Studio Code**, `code`, or `deck vscode` (Mac or Deck) |
| Reinstall | `deck vscode install` / `bash ~/.config/steamdeck/install-vscode.sh` |
| Terminal profile | **`distrobox-dev`** (default) → `distrobox enter dev` |
| Settings | `~/.var/app/com.visualstudio.code/config/Code/User/settings.json` |

Cursor stays the cloud-heavy AI editor (`~/Applications/cursor`). Use VS Code when you want Continue against **local** Ollama.

### Continue → local Ollama

| | |
| --- | --- |
| Extension | `Continue.continue` |
| Config | `~/.continue/config.yaml` (current) and `~/.continue/config.json` (legacy) |
| Provider | `ollama` |
| URL | `http://127.0.0.1:11434` |
| Model | `qwen2.5:1.5b` (already pulled) |

**Do not** bind Ollama on `0.0.0.0`. Continue does not start the server — `deck ollama start` / QAM AI focus if it is down. First workspace index is leftover: open a folder under `~/src` and let Continue index once.

### Podman socket (Docker-compatible API)

```bash
systemctl --user enable --now podman.socket   # already on this Deck
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
# or: unix:///run/user/$(id -u)/podman/podman.sock
```

Docker-API compatible **≠** every Docker VS Code extension works (Portainer / Docker Desktop assumptions). Prefer `podman` / Quadlets.

Commented Quadlet examples (not enabled, not started — no surprise RAM):

- `~/.config/containers/systemd/example.container`
- `~/.config/containers/systemd/example-postgres.container`
- `~/.config/containers/systemd/example-redis.container`

Copy, uncomment, `systemctl --user daemon-reload`, then `start` only when a project needs them. Bind `127.0.0.1`. Do **not** start postgres / redis / localstack by default.

---

## 7. Desktop apps / AppImages / browsers

Switch to **Desktop Mode** for these. Game Mode can launch some of them via Steam/non-Steam shortcuts; Cursor’s wrapper already special-cases Steam’s reaper.

### Shortcuts you added

| Name | Desktop (`~/Desktop`) | App menu | Opens |
| --- | --- | --- | --- |
| Grok CLI | yes | yes | Konsole → `grok` |
| Cursor Agent | yes | yes | Konsole → `agent` |
| Cursor | yes | yes | `~/.local/bin/cursor` (extracted AppImage, `--no-sandbox`) |
| Visual Studio Code | yes | yes | `~/.local/bin/code` → user Flatpak; terminal **distrobox-dev** |
| Google Chrome | yes (**our** launcher, not the Discover symlink) | yes | Flatpak Chrome + `--load-extension` (Open WebUI new tab) |
| Open WebUI | yes | yes | `~/.local/bin/google-chrome http://127.0.0.1:3000` |
| Jellyfin | yes | yes | user Flatpak `org.jellyfin.JellyfinDesktop` → Quadlet `:8096` |
| RetroArch | yes (Flatpak, not Steam) | yes (`RetroArch.desktop`) | `flatpak run org.libretro.RetroArch` |
| ES-DE | yes | yes | `…/Emulation/tools/launchers/es-de/es-de.sh` → `~/Applications/ES-DE.AppImage` |

Also on the Desktop (stock or EmuDeck): **Return to Gaming Mode**, **Steam**, **Konsole**, **EmuDeck**, leftover **Install EmuDeck**, **RetroArch** (Flatpak), **ES-DE**, GyroDSU update/uninstall.

### Browsers

- **Chrome** (system Flatpak) is the browser that works. `~/.local/bin/xdg-open` sends `http`/`https` here because Firefox on this Deck often opened blank for CLI logins (`grok login`, `agent login`).
- **Firefox** (system Flatpak) is installed via Discover; leave it as backup, not the OAuth default.

#### Chrome → Open WebUI (bookmark + new-tab button)

Local Open WebUI is `http://127.0.0.1:3000` only. Do not change the Ollama bind to reach it.

Installed under `$HOME` (survives SteamOS updates):

| Piece | Path |
| --- | --- |
| Unpacked MV3 new-tab extension | `~/.local/share/steamdeck/chrome-open-webui-newtab/` (also `~/Applications/chrome-extensions/open-webui-newtab` → same) |
| Chrome wrapper | `~/.local/bin/google-chrome` (always `--load-extension=…`) |
| App menu + Desktop launcher | `~/.local/share/applications/com.google.Chrome.desktop` copied to `~/Desktop/com.google.Chrome.desktop` |
| Bookmarks bar favorite | Chrome profile `Default/Bookmarks` title **Open WebUI** |
| Fallbacks | Desktop **Open WebUI**; `Open-WebUI-bookmark.html` (open *inside Chrome*, drag the link); `Open-WebUI-bookmarks-import.html` (Chrome → Bookmarks manager → Import) |

**How to see the big button:** fully **quit** Chrome (not just close a window — the Flatpak process must exit). Then launch **Google Chrome from the Desktop icon** (or the app-menu entry that lives in `~/.local/share/applications`). A new tab is a dark OLED page with one huge **Open WebUI** button. The bookmarks bar should show **Open WebUI** and stay visible (`bookmark_bar.show_on_all_tabs`).

`--load-extension` does not stick if an already-running Chrome was started without that flag (new windows join the old process). The official Discover/system `.desktop` under `/var/lib/flatpak/exports/…` still launches **without** the flag — that is why **our** file is the one on `~/Desktop`.

Homepage / startup URL was **not** forced in Preferences: Chrome SuperMAC would ignore or reset those keys. Re-apply after a profile reset:

```bash
bash ~/.config/steamdeck/install-chrome-open-webui.sh
```

If Chrome is running, the installer updates the extension/wrapper/desktop files and skips Bookmarks/Preferences so the profile is not corrupted. Quit Chrome and run it again to inject the favorite. Chrome may show a one-time “developer mode extension” banner; keep the extension.

First-time CLI login (Desktop Konsole or `ssh -t`):

```bash
grok login
agent login
agent status
```

### AppImages and user bins (`~/Applications`, `~/.local/bin`)

| Path | Role |
| --- | --- |
| `~/Applications/cursor/Cursor-3.16.29-x86_64.AppImage` | Cursor IDE (extracted to `squashfs-root` so Steam’s reaper does not eat a FUSE AppImage) |
| `~/Applications/EmuDeck.AppImage` | EmuDeck manager |
| `~/Applications/ES-DE.AppImage` | official ES-DE Steam Deck frontend 3.4.1 |
| `~/Applications/Cemu.AppImage` | Wii U |
| `~/Applications/DuckStation.AppImage` | PS1 |
| `~/Applications/pcsx2-Qt.AppImage` | PS2 |
| `~/Applications/rpcs3.AppImage` | PS3 |
| `~/Applications/azahar.AppImage` | 3DS |
| `~/Applications/Shadps4-qt.AppImage` | PS4 |
| `~/Applications/Vita3K/` | PS Vita |
| `~/.local/bin/cursor` | launcher |
| `~/.local/bin/code` | VS Code user Flatpak wrapper |
| `~/.local/bin/emudeck` | launcher |
| `~/.local/bin/agent` / `cursor-agent` | Cursor Agent |
| `~/.local/bin/google-chrome` | Flatpak Chrome + Open WebUI new-tab extension |
| `~/.local/bin/gh` | GitHub CLI |
| `~/.grok/bin/grok` | Grok CLI |

---

## 8. Emulation (legal dumps only)

Two RetroArch installs exist. They are **not** the same binary. **EmuDeck uses the Flatpak.**

| Stack | What it is | Use |
| --- | --- | --- |
| **Flatpak RetroArch** | user `org.libretro.RetroArch` 1.22.2; 93 cores; host+network override | EmuDeck `retroarch.sh` and Desktop **RetroArch**. |
| **Steam RetroArch** | leftover `steamapps/common/RetroArch` (~804 MB, app 1118310) | Steam library only. Left installed; does not block EmuDeck. |
| **EmuDeck** | AppImage + standalones in `~/Applications` + user Flatpaks | Manager + per-system emulators. |
| **ES-DE** | official Steam Deck AppImage `~/Applications/ES-DE.AppImage` (3.4.1) | Game Mode **EmulationStationDE**; Desktop **ES-DE**. No official Flatpak (upstream dropped it on SteamOS). |

**Live tree** is `~/Downloads/emulatorom/Emulation/{roms,bios,saves,storage,tools}`. `~/Emulation` is an empty first-run stub (0 ROM files). Do not wipe or “migrate” the live tree onto the stub. EmuDeck `settings.sh` already points `emulationPath` / `romsPath` / `biosPath` at the live tree. Flatpak RetroArch `rgui_browser_directory` / `system_directory` do too.

EmuDeck also installed **user Flatpaks** (Dolphin, PrimeHack, melonDS, PPSSPP, ScummVM, xemu, Supermodel) and Desktop launchers (Cemu, DuckStation, PCSX2, RPCS3, Azahar, ShadPS4, Vita3K, Ryujinx, Xenia, Steam ROM Manager, Model 2 via Proton). **Gyro DSU** (`sdgyrodsu.service`) exposes the Deck gyro to emulators that speak cemuhook/DSU.

**Legal only.** Use dumps and BIOS you are allowed to have (your own hardware, licensed archives, or files the emulator’s authors say you may redistribute). This manual will not list ROM sites, “all-in-one” packs, or SteamRIP-style installers. Do not ask the helpers to fetch copyrighted BIOS/ROMs.

Typical owner workflow:

1. Put **your** dumps in `~/Downloads/emulatorom/Emulation/roms/<system>/`.
2. Put **your** BIOS in `~/Downloads/emulatorom/Emulation/bios/` when a system requires it (that emulator’s official docs).
3. Game Mode: **EmulationStationDE**. Desktop: **ES-DE** or **EmuDeck**.
4. Steam ROM Manager parse is still a **Desktop tap** if you want per-game Steam tiles (`doSetupSRM=false` from first-run). Restart Game Mode once after adding the ES-DE AppImage so the existing shortcut actually launches.

If Steam rewrites `~/.local/share/applications/RetroArch.desktop` back to `steam://rungameid/1118310`, use the Desktop **RetroArch** icon (Flatpak) or `flatpak run org.libretro.RetroArch`.

---

## 9. Windows redistributables (Protontricks)

Windows titles on SteamOS run under **Proton**. Valve’s layer already includes **DXVK** (Direct3D) and a `d3dcompiler`. You almost never need Microsoft’s DirectX web installer (`dxwebsetup.exe`). What *does* sometimes go missing is a **Visual C++** runtime inside that game’s Wine prefix.

**Do not** copy a Windows dump / `_CommonRedist` / `setup.exe` / Steam-emulator DLLs onto the Deck. A real Steam library export is `steamapps/common/<Game>/` plus `steamapps/appmanifest_<appid>.acf`. Push that with `deckpushgame` from a Mac Steam library, then on the Deck tap **Install** (Steam verifies existing files). Loose folders without an acf are not imports. Then, if a prefix is missing a runtime, apply the matching **winetricks** verb with Protontricks.

Protontricks is the **user Flatpak** `com.github.Matoking.protontricks` (Discover / Flathub — official install path for Steam Deck). That lives under `$HOME` and does **not** need `steamos-readonly disable`. Wrappers: `~/.local/bin/protontricks` and `protontricks-launch`. Reinstall/repair:

```bash
bash ~/.config/steamdeck/install-protontricks.sh
```

A Windows `_CommonRedist` folder (names only — do not run those EXEs on the Deck) maps like this:

| File | What it is | Verb / action |
| --- | --- | --- |
| `vcredist_2015-2019_x64.exe` / `_x86.exe` | Visual C++ 2015–2019 | `vcrun2019` (or `vcrun2022`, a superset — **pick one**) |
| `vcredist_x64.exe` / `vcredist_x86.exe` | Visual C++ 2010 | `vcrun2010` only if that title actually needs it |
| `dxwebsetup.exe` | DirectX End-User Runtime web installer | **Skip** — Proton already ships DXVK / d3dcompiler |
| `dotNetFx40_Full_setup.exe` | .NET Framework 4.0 | `dotnet40` only if a prefix is missing it |
| `xnafx40_redist.msi` | XNA Framework 4.0 | `xna40` — original Overcooked, not typically AYCE |
| `oalinst.exe` | OpenAL | `openal` only if the game asks |

**Overcooked! All You Can Eat** Steam appid is **1243830**. Not in this Deck’s library and not in the Mac Steam library (`~/Library/Application Support/Steam/steamapps`). After Steam has the title (Install + one launch, which creates `compatdata/1243830`), apply VC++ 2015–2019:

```bash
# quiet / non-interactive; can take several minutes
protontricks -q 1243830 vcrun2019

# equivalent
protontricks -c "winetricks -q vcrun2019" 1243830

# same via helper
bash ~/.config/steamdeck/install-protontricks.sh --apply 1243830
```

From the Mac: `deck protontricks -q 1243830 vcrun2019`. Extra library on an SD card needs a Flatpak filesystem override (see the [Flathub Protontricks page](https://github.com/flathub/com.github.Matoking.protontricks)).

---

## 10. Persistence rules and what gets wiped

| Layer | Fate | Examples |
| --- | --- | --- |
| `/usr` | **Wiped / replaced** on image update | Anything installed with `pacman` on the host |
| `/etc` | **Can be reset** | `plugin_loader.service`, `zz-deck-nopasswd` — re-check |
| `$HOME` | **Keeps** | `~/.local`, `~/.config`, `~/.ollama`, `~/Applications`, `~/containers`, `~/homebrew`, `~/Downloads/emulatorom/Emulation` (live ROMs), `~/Emulation` (empty stub), `~/src`, Steam library, `~/.grok` |
| User Flatpaks | **Keeps** | EmuDeck emulators |
| System Flatpaks | **Usually keeps** (`/var`) | Chrome, Firefox — still confirm after a big SteamOS jump |
| Distrobox / Podman storage | **Keeps** (`~/.local/share/containers`) | `ai-box`, `dev`, Open WebUI / *arr image layers |
| User Flatpak VS Code | **Keeps** (`~/.local/share/flatpak`) | `com.visualstudio.code` + `~/.continue` |
| This git repo | Mac only | Helpers are copied to the Deck; git metadata is not |

**Wiped or broken after a typical SteamOS update:**

- Host `/usr` tools you should not have installed anyway.
- Decky’s **system** unit → QAM plug disappears until `install-decky.sh`.
- Sometimes passwordless sudo or linger — verify `sudo -n true` and `loginctl show-user deck -p Linger`.

**Not wiped:** models in `~/.ollama`, WebUI data, *arr config under `~/containers/{radarr,sonarr,prowlarr,bazarr}`, EmuDeck trees, Cursor/Grok installs, helper scripts (unless you overwrite them).

---

## 11. Daily ops

### Start the AI stack (Desktop or SSH)

```bash
# from Mac
deck ping
deck ai-on
deck ai
```

On the Deck: Game Mode QAM → Decky → **Deck Focus → AI focus (start stack)**, then bonsAI (chat) and/or Chrome → `http://127.0.0.1:3000`. From the Mac: `deck ai-on`.

### Stop before heavy games

Local inference and Open WebUI steal RAM and CPU from Gamescope.

**In Game Mode:** QAM → … → Decky plug → **Deck Focus** → **Game focus (stop AI)**.

From the Mac (same scripts):

```bash
deck game          # or: deck ai-off
# equivalent:
#   deck webui stop && deck ollama stop
```

Leave Decky running (small). Start the stack again with QAM **AI focus (start stack)** or `deck ai-on` when you want QAM chat. AI focus does **not** start Jellyfin or *arr — `deck jellyfin start` / `deck arr start` if you want those again. If a game is already stuttering, stop WebUI first (it was the large one). Deck Focus does not kill Steam or the QAM plug.

### Reboot checks (30 seconds)

After any reboot or SteamOS update:

```bash
deck ping
deck audit
deck ai
```

Expect: linger yes, `ollama.service` active, API on `127.0.0.1:11434`, `qwen2.5:1.5b` listed, `plugin_loader` active, Open WebUI on `127.0.0.1:3000` **or** stopped if you left it off, Distrobox `ai-box` **and** `dev`. One known-good warning today: **no `arch-tools` box** (optional).

If the QAM plug is missing: restart Game Mode once. If it is still missing: §12 Decky reinstall.

### Disk

Internal `/home` was ~928 GiB, ~118 GiB used (13%) at last check. `deck df` anytime.

---

## 12. Recovery

### Re-run user-space bootstrap

Helpers must already be on the Deck (`~/.config/steamdeck/`). From the Mac:

```bash
# 1) resync scripts
rsync -avh --progress \
  /Users/wizops/DIPI/steam/helpers/ \
  deck@10.0.0.143:~/.config/steamdeck/

# 2) dirs + podman.socket + Distrobox CLI
deck bootstrap

# 3) recreate ai-box only if missing (does not reinstall Ollama inside)
deck bootstrap --with-ai

# 4) recreate Ubuntu dev box only if missing (does not apt-install the toolchain)
deck bootstrap --with-dev
```

On the Deck, `~/.bashrc` must still contain:

```bash
export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
[[ -f ~/.config/steamdeck/deck-remote.bashrc ]] && . ~/.config/steamdeck/deck-remote.bashrc
```

If `ai-box` exists but Ollama does not answer: `deck ollama restart`, then `deck ai`. If the wrapper became a host ELF or `~/.local/lib/ollama` appeared, remove the tarball leftovers and restore the Distrobox wrapper — do not use bonsAI Install.

### Reinstall Decky after a SteamOS update

User-space files in `~/homebrew/` usually survive. The **system unit** often does not.

```bash
# from Mac after helpers are synced
ssh -t deck@10.0.0.143 'bash ~/.config/steamdeck/install-decky.sh'
```

That script needs working sudo (`sudo -n true`). Then **restart Game Mode**. In QAM: enable bonsAI + decky-ollama; bonsAI base URL `http://127.0.0.1:11434`; skip Install Ollama.

### Resync this repo → Deck

After you pull or edit on the Mac, `helpers/` needs to land on the Deck (see rsync above). After Deck Focus edits, also copy `plugins/deck-focus/` (skip `node_modules`) to `~/homebrew/plugins/deck-focus/` and `sudo systemctl restart plugin_loader`. Then `deck audit`.

### Recreate Open WebUI

If the Quadlet file is missing, restore `~/.config/containers/systemd/open-webui.container` (same content as last verified: publish `127.0.0.1:3000:8080`, `OLLAMA_BASE_URL=http://10.0.2.2:11434`, `PodmanArgs=--network=pasta:--map-host-loopback,10.0.2.2`), then:

```bash
systemctl --user daemon-reload
systemctl --user restart open-webui.service
```

Data in `~/containers/open-webui` is kept if you do not delete it.

### Recreate *arr

```bash
bash ~/.config/steamdeck/install-arr.sh
# or from the Mac:
deck arr install
```

Config in `~/containers/{radarr,sonarr,prowlarr,bazarr}` is kept if you do not delete it. The script still does not add indexers or download clients.

### Recreate linger / sudo after an update

```bash
sudo loginctl enable-linger deck
# if sudo now asks a password, recreate /etc/sudoers.d/zz-deck-nopasswd (zz- after wheel)
sudo chmod 440 /etc/sudoers.d/zz-deck-nopasswd
```

---

## 13. Do-not list

| Do not | Why |
| --- | --- |
| bonsAI **Install Ollama** / **Update installed** | Host tarball in `~/.local/bin` + `~/.local/lib/ollama`; second server; fights `ai-box`. Chat UI is fine. |
| Bind Ollama, Open WebUI, or *arr on `0.0.0.0` | Exposes admin UIs on the LAN. Use SSH `-L` instead. |
| Commit indexer lists / Usenet keys / torrent-site configs | *arr are library managers only. Configure indexers yourself; this repo ships none. |
| Let decky-ollama `pkill` Ollama or install a host binary | Breaks the Distrobox unit. Keep the patched plugin. |
| `pacman -S` onto host `/usr` | Gone on the next SteamOS image. Use Distrobox / Flatpak / `$HOME`. |
| Disable `steamos-readonly` “just to install things” | Fights the A/B image. Not how this Deck is set up. |
| Pull **30B** (or other huge) models | Handheld RAM/CPU; `qwen2.5:1.5b` is the sized model. |
| Enable **ROCm** for Ollama | Unsupported path on this setup. Vulkan later, if ever. |
| Symlink the Deck’s `~/.config/steamdeck` at the Mac repo | SteamOS `$HOME` should keep real files. |
| Commit secrets into this repo | No `auth.json`, sudoers copies, `~/.grok` state, keys, models, AppImages. |
| Use piracy / SteamRIP / random “ROM packs” | Legal dumps and BIOS only (§8). |
| Copy a Windows game dump / `_CommonRedist` / `setup.exe` onto the Deck | Sideload is not how Proton games are installed. Steam + Protontricks verbs only (§9). |
| Leave Open WebUI / Jellyfin transcode / *arr up for AAA games | RAM + the 15W APU; QAM **Deck Focus → Game focus** or `deck game` first. |
| Stop or recreate `ai-box` / Jellyfin / Ollama for `dev` work | They are independent. `dev` only shares `$HOME`. |
| `apt install` VS Code / Cursor inside `dev` | Snap-heavy. Use host Desktop Cursor / VS Code and attach, or `distrobox-export`. |
| Enable postgres / redis / localstack Quadlets by default | Surprise RAM on a handheld. Examples stay commented. |
| Bind Ollama on `0.0.0.0` so Continue can “reach it from the Mac” | Use SSH `-L 11434` instead. |

---

## Quick reference

| I want to… | Do this |
| --- | --- |
| See if the Deck is up | `deck ping` |
| See if AI is healthy | `deck ai` / `deck audit` |
| Chat in Game Mode | QAM → Decky → bonsAI (Ollama must be running) |
| Stop AI before a game | QAM → Decky → **Deck Focus** → Game focus, or `deck game` |
| Start AI stack again | QAM → Decky → **Deck Focus** → AI focus, or `deck ai-on` |
| Chat like ChatGPT | Desktop **Google Chrome** (our icon) → new tab button or bookmarks bar **Open WebUI** |
| Use WebUI / *arr from the Mac | `ssh -L` tunnel (§3) — not LAN publish |
| *arr status | `deck arr` |
| Free resources for a game | `deck game` (or `deck webui stop` and `deck ollama stop`) |
| After SteamOS update | `deck bootstrap` → Decky `install-decky.sh` → restart Game Mode → `deck audit` |
| After editing helpers | `rsync` `helpers/` → `deck@10.0.0.143:~/.config/steamdeck/` |
| Compile / git / node / go | `deck dev` (or `deck box-dev`); projects in `~/src` |
| Edit with local Ollama | Desktop **Visual Studio Code** / `deck vscode`; Continue → `127.0.0.1:11434` |
| Install Protontricks / VC++ for a Proton game | `bash ~/.config/steamdeck/install-protontricks.sh`; then `protontricks -q <appid> vcrun2019` (§9) |
