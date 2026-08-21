# Steam Deck OLED — operator manual

Owner guide for **सत्यBrave**. This is the single document for everything added on top of a **stock SteamOS** image on this Deck.

**Last verified:** 2026-08-20 19:40 PDT, live SSH to `deck@10.0.0.143` (`audit.sh` + inventory). Hardware is **Galileo** (OLED). SteamOS **3.8.16** (`BUILD_ID=20260716.1`, branch `stable`, `steamos-readonly` **enabled**).

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
| This repo’s helpers (Deck copy) | `~/.config/steamdeck/` (real files, not Mac symlinks) | yes | `source ~/.bashrc` (already wired). Resync from Mac after edits. |
| Mac control plane | `~/.config/steamdeck` → `/Users/wizops/DIPI/steam/helpers/` | n/a (Mac) | `source ~/.bashrc` then `deck …` |
| Distrobox CLI | `~/.local/bin/distrobox` (1.8.2.5) | yes | `deck bootstrap` reinstalls if missing |
| Distrobox `ai-box` | `archlinux:latest` container, `$HOME` storage | yes (container store in `$HOME`) | `deck box-ai` / `distrobox enter ai-box` |
| Distrobox `arch-tools` | **not created** | — | Optional: `deck bootstrap --with-container` |
| Ollama 0.32.14 | inside `ai-box`; models `~/.ollama` | yes | `deck ollama start\|stop\|restart` or `systemctl --user … ollama.service` |
| `~/.local/bin/ollama` | Distrobox **wrapper** (must not be a host ELF) | yes | `ollama list` / `ollama pull …` |
| Open WebUI | Quadlet `~/.config/containers/systemd/open-webui.container`; data `~/containers/open-webui` | yes | `deck webui start\|stop\|restart` |
| Podman user socket | `podman.socket` (user) | image binary; enable is user | `systemctl --user start\|stop podman.socket` |
| User linger | `loginctl` linger for `deck` | usually yes; re-check | `sudo loginctl enable-linger deck` once |
| Decky Loader v3.2.6 | `~/homebrew/` + **system** `plugin_loader.service` | tree yes; **unit re-check** | `sudo systemctl start\|stop plugin_loader`; after updates: `install-decky.sh` |
| bonsAI 0.4.9 | `~/homebrew/plugins/bonsAI` | yes | Enable in QAM (Decky plug). Chat only. |
| decky-ollama (patched) | `~/homebrew/plugins/decky-ollama` | yes | QAM start/stop → user `ollama.service` on `127.0.0.1` |
| Cursor Agent CLI | `~/.local/bin/agent` → `~/.local/share/cursor-agent/` (2026.08.11-e8db854) | yes | Desktop **Cursor Agent**, or `agent` / `deckagent` |
| Cursor IDE | `~/Applications/cursor/Cursor-3.16.29-x86_64.AppImage` + `~/.local/bin/cursor` | yes | Desktop **Cursor** |
| Grok CLI | `~/.grok/bin/grok` (1.0.5) | yes | Desktop **Grok CLI**, or `grok` / `deckgrok` |
| GitHub CLI | `~/.local/bin/gh` (2.97.0) | yes | `gh` |
| Chrome Flatpak | `com.google.Chrome` **system** (151.x) | typically yes (`/var`) | Desktop **Google Chrome** (our launcher) |
| Chrome Open WebUI new-tab + bookmark | `~/.local/share/steamdeck/chrome-open-webui-newtab` + `~/.local/bin/google-chrome` + user `.desktop` | yes | Fully quit Chrome, then Desktop **Google Chrome**; new tab button + bookmarks bar |
| Firefox Flatpak | `org.mozilla.firefox` **system** (154.0) | typically yes | Discover / app menu (http(s) is **not** the default) |
| `xdg-open` wrapper | `~/.local/bin/xdg-open` → Chrome for `http(s)` | yes | used by Cursor / login flows |
| EmuDeck AppImage | `~/Applications/EmuDeck.AppImage` + `~/.local/bin/emudeck` | yes | Desktop **EmuDeck** |
| Emulator AppImages | `~/Applications/*.AppImage` (see §7) | yes | matching `.desktop` launchers |
| EmuDeck Flatpaks | user Flatpaks (Dolphin, PPSSPP, melonDS, …) | yes | Discover / Steam ROM Manager |
| Steam RetroArch | `~/.steam/steam/steamapps/common/RetroArch` | yes | Steam library (stock-style install) |
| Flatpak RetroArch | `org.libretro.RetroArch` (user, 1.22.2) | yes | EmuDeck / Discover — **not** the Steam one |
| Gyro DSU | `~/sdgyrodsu/` + user `sdgyrodsu.service` | yes | `systemctl --user start\|stop sdgyrodsu`; Desktop update/uninstall helpers |
| Passwordless sudo | `/etc/sudoers.d/zz-deck-nopasswd` | **re-check** | must sort **after** `wheel` |
| SSH | `sshd` enabled; Mac key login | image + `$HOME/.ssh` | `sudo systemctl start\|stop sshd` |
| Desktop shortcuts | `~/Desktop/` + `~/.local/share/applications/` | yes | see §6 |

**Not installed:** Distrobox `arch-tools` (audit warning only). Optional if you want a general Arch toolbox besides `ai-box`.

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
| `0.0.0.0:32000` | stock SteamOS devkit | Valve, not ours |

Do **not** move Ollama or Open WebUI to `0.0.0.0` to “reach them from the Mac.” Use an SSH tunnel instead:

```bash
ssh -L 3000:127.0.0.1:3000 -L 11434:127.0.0.1:11434 deck@10.0.0.143
```

Then on the Mac: `http://127.0.0.1:3000` (WebUI) and `http://127.0.0.1:11434` (Ollama API).

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
deck ollama            # status + user unit
deck ollama start|stop|restart|logs
deck webui             # http://127.0.0.1:3000 + status
deck webui start|stop|restart|logs
deck audit             # ~/.config/steamdeck/audit.sh
deck bootstrap         # dirs, podman.socket, Distrobox
deck bootstrap --with-ai
deck box-ai            # distrobox enter ai-box
deck df                # disk + library sizes
deck games             # steamapps/common folder names
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
- **Plugins running:** bonsAI, decky-ollama (both under `~/homebrew/plugins/`).
- **QAM:** Game Mode → … (Quick Access) → plug icon. If the icon is missing, **restart Game Mode once** (or reboot).
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

---

## 6. Desktop apps / AppImages / browsers

Switch to **Desktop Mode** for these. Game Mode can launch some of them via Steam/non-Steam shortcuts; Cursor’s wrapper already special-cases Steam’s reaper.

### Shortcuts you added

| Name | Desktop (`~/Desktop`) | App menu | Opens |
| --- | --- | --- | --- |
| Grok CLI | yes | yes | Konsole → `grok` |
| Cursor Agent | yes | yes | Konsole → `agent` |
| Cursor | yes | yes | `~/.local/bin/cursor` (extracted AppImage, `--no-sandbox`) |
| Google Chrome | yes (**our** launcher, not the Discover symlink) | yes | Flatpak Chrome + `--load-extension` (Open WebUI new tab) |
| Open WebUI | yes | yes | `~/.local/bin/google-chrome http://127.0.0.1:3000` |

Also on the Desktop (stock or EmuDeck): **Return to Gaming Mode**, **Steam**, **Konsole**, **EmuDeck**, leftover **Install EmuDeck**, GyroDSU update/uninstall.

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
| `~/Applications/Cemu.AppImage` | Wii U |
| `~/Applications/DuckStation.AppImage` | PS1 |
| `~/Applications/pcsx2-Qt.AppImage` | PS2 |
| `~/Applications/rpcs3.AppImage` | PS3 |
| `~/Applications/azahar.AppImage` | 3DS |
| `~/Applications/Shadps4-qt.AppImage` | PS4 |
| `~/Applications/Vita3K/` | PS Vita |
| `~/.local/bin/cursor` | launcher |
| `~/.local/bin/emudeck` | launcher |
| `~/.local/bin/agent` / `cursor-agent` | Cursor Agent |
| `~/.local/bin/google-chrome` | Flatpak Chrome + Open WebUI new-tab extension |
| `~/.local/bin/gh` | GitHub CLI |
| `~/.grok/bin/grok` | Grok CLI |

---

## 7. Emulation (legal dumps only)

Two stacks exist. They are **not** the same RetroArch.

| Stack | What it is | Use |
| --- | --- | --- |
| **Steam RetroArch** | Already in the Steam library: `~/.steam/steam/steamapps/common/RetroArch` | Steam-managed cores; launch from Game Mode like any Steam app. |
| **EmuDeck** | AppImage + `~/Emulation/{roms,bios,saves,storage,tools,hdpacks}` + Steam ROM Manager + extra emulators | Front-end / per-system emulators. ROMs you place yourself. |

EmuDeck also installed **user Flatpaks** (Dolphin, PrimeHack, melonDS, PPSSPP, ScummVM, xemu, Supermodel, Flatpak RetroArch) and Desktop launchers (Cemu, DuckStation, PCSX2, RPCS3, Azahar, ShadPS4, Vita3K, Ryujinx, Xenia, Steam ROM Manager, Model 2 via Proton). **Gyro DSU** (`sdgyrodsu.service`) exposes the Deck gyro to emulators that speak cemuhook/DSU.

**Legal only.** Use dumps and BIOS you are allowed to have (your own hardware, licensed archives, or files the emulator’s authors say you may redistribute). This manual will not list ROM sites, “all-in-one” packs, or SteamRIP-style installers. Do not ask the helpers to fetch copyrighted BIOS/ROMs.

Typical owner workflow:

1. Put **your** dumps in the matching folder under `~/Emulation/roms/<system>/`.
2. Put **your** BIOS in `~/Emulation/bios/` when a system requires it (see that emulator’s official docs).
3. Run **EmuDeck** or **Steam ROM Manager** to refresh Game Mode tiles.
4. Prefer **Steam RetroArch** if you already configured it in Steam; use EmuDeck when you want the per-system AppImages/Flatpaks.

---

## 8. Persistence rules and what gets wiped

| Layer | Fate | Examples |
| --- | --- | --- |
| `/usr` | **Wiped / replaced** on image update | Anything installed with `pacman` on the host |
| `/etc` | **Can be reset** | `plugin_loader.service`, `zz-deck-nopasswd` — re-check |
| `$HOME` | **Keeps** | `~/.local`, `~/.config`, `~/.ollama`, `~/Applications`, `~/containers`, `~/homebrew`, `~/Emulation`, Steam library, `~/.grok` |
| User Flatpaks | **Keeps** | EmuDeck emulators |
| System Flatpaks | **Usually keeps** (`/var`) | Chrome, Firefox — still confirm after a big SteamOS jump |
| Distrobox / Podman storage | **Keeps** (`~/.local/share/containers`) | `ai-box`, Open WebUI image layers |
| This git repo | Mac only | Helpers are copied to the Deck; git metadata is not |

**Wiped or broken after a typical SteamOS update:**

- Host `/usr` tools you should not have installed anyway.
- Decky’s **system** unit → QAM plug disappears until `install-decky.sh`.
- Sometimes passwordless sudo or linger — verify `sudo -n true` and `loginctl show-user deck -p Linger`.

**Not wiped:** models in `~/.ollama`, WebUI data, EmuDeck trees, Cursor/Grok installs, helper scripts (unless you overwrite them).

---

## 9. Daily ops

### Start the AI stack (Desktop or SSH)

```bash
# from Mac
deck ping
deck ollama start
deck webui start
deck ai
```

On the Deck: Game Mode QAM → Decky → bonsAI (chat) and/or Chrome → `http://127.0.0.1:3000`.

### Stop before heavy games

Local inference and Open WebUI steal RAM and CPU from Gamescope.

```bash
deck webui stop
deck ollama stop
```

Leave Decky running (small). Start Ollama again when you want QAM chat. If a game is already stuttering, stop WebUI first (it was the large one).

### Reboot checks (30 seconds)

After any reboot or SteamOS update:

```bash
deck ping
deck audit
deck ai
```

Expect: linger yes, `ollama.service` active, API on `127.0.0.1:11434`, `qwen2.5:1.5b` listed, `plugin_loader` active, Open WebUI on `127.0.0.1:3000` **or** stopped if you left it off. One known-good warning today: **no `arch-tools` box** (optional).

If the QAM plug is missing: restart Game Mode once. If it is still missing: §10 Decky reinstall.

### Disk

Internal `/home` was ~928 GiB, ~118 GiB used (13%) at last check. `deck df` anytime.

---

## 10. Recovery

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

After you pull or edit on the Mac, only `helpers/` needs to land on the Deck (see rsync above). Then `deck audit`.

### Recreate Open WebUI

If the Quadlet file is missing, restore `~/.config/containers/systemd/open-webui.container` (same content as last verified: publish `127.0.0.1:3000:8080`, `OLLAMA_BASE_URL=http://10.0.2.2:11434`, `PodmanArgs=--network=pasta:--map-host-loopback,10.0.2.2`), then:

```bash
systemctl --user daemon-reload
systemctl --user restart open-webui.service
```

Data in `~/containers/open-webui` is kept if you do not delete it.

### Recreate linger / sudo after an update

```bash
sudo loginctl enable-linger deck
# if sudo now asks a password, recreate /etc/sudoers.d/zz-deck-nopasswd (zz- after wheel)
sudo chmod 440 /etc/sudoers.d/zz-deck-nopasswd
```

---

## 11. Do-not list

| Do not | Why |
| --- | --- |
| bonsAI **Install Ollama** / **Update installed** | Host tarball in `~/.local/bin` + `~/.local/lib/ollama`; second server; fights `ai-box`. Chat UI is fine. |
| Bind Ollama or Open WebUI on `0.0.0.0` | Exposes a local LLM UI/API on the LAN. Use SSH `-L` instead. |
| Let decky-ollama `pkill` Ollama or install a host binary | Breaks the Distrobox unit. Keep the patched plugin. |
| `pacman -S` onto host `/usr` | Gone on the next SteamOS image. Use Distrobox / Flatpak / `$HOME`. |
| Disable `steamos-readonly` “just to install things” | Fights the A/B image. Not how this Deck is set up. |
| Pull **30B** (or other huge) models | Handheld RAM/CPU; `qwen2.5:1.5b` is the sized model. |
| Enable **ROCm** for Ollama | Unsupported path on this setup. Vulkan later, if ever. |
| Symlink the Deck’s `~/.config/steamdeck` at the Mac repo | SteamOS `$HOME` should keep real files. |
| Commit secrets into this repo | No `auth.json`, sudoers copies, `~/.grok` state, keys, models, AppImages. |
| Use piracy / SteamRIP / random “ROM packs” | Legal dumps and BIOS only (§7). |
| Leave Open WebUI up for AAA games | ~2 GiB+ and CPU; `deck webui stop` first. |

---

## Quick reference

| I want to… | Do this |
| --- | --- |
| See if the Deck is up | `deck ping` |
| See if AI is healthy | `deck ai` / `deck audit` |
| Chat in Game Mode | QAM → Decky → bonsAI (Ollama must be running) |
| Chat like ChatGPT | Desktop **Google Chrome** (our icon) → new tab button or bookmarks bar **Open WebUI** |
| Use WebUI from the Mac | `ssh -L 3000:127.0.0.1:3000 deck@10.0.0.143` |
| Free resources for a game | `deck webui stop` and `deck ollama stop` |
| After SteamOS update | `deck bootstrap` → Decky `install-decky.sh` → restart Game Mode → `deck audit` |
| After editing helpers | `rsync` `helpers/` → `deck@10.0.0.143:~/.config/steamdeck/` |
