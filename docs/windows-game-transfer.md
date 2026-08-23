# Windows Steam library → this Deck

How to pack installed Steam games on a **Windows** PC and land them on this Steam Deck OLED (`deck@10.0.0.143`) without re-downloading the whole title.

Owner: **सत्यBrave**. Companion to the [operator manual](MANUAL.md) (§4 `deckpushgame`, §9 Protontricks). Architecture notes stay in [architecture.md](architecture.md).

**What this is:** a procedure. Windows game files run on Deck through **Proton**. You copy the Windows install, not a Linux rebuild.

No passwords, API keys, or Steam credentials belong in this repo.

---

## 0. What Steam actually needs

For every game, pack **both** pieces. The folder alone is not an install.

| Piece | Windows location | Why |
| --- | --- | --- |
| Game folder | `steamapps\common\<GameName>\` | The files |
| Manifest | `steamapps\appmanifest_<AppID>.acf` | Tells Steam it is installed, which folder, which version |

Without the `.acf`, Steam ignores the folder and will re-download.

A real library export looks like this (names must stay exact):

```text
steamapps\
  appmanifest_1091500.acf
  common\
    Cyberpunk 2077\
```

On this Deck the internal library is:

```text
/home/deck/.steam/steam/steamapps/
```

(`~/.local/share/Steam/steamapps` is the same tree via Steam’s usual symlink.) SD-card libraries live under `/run/media/deck/<card>/steamapps/` after Steam has formatted the card as a library.

### Pack

- `steamapps\workshop\` — Workshop mods, if you care

### Do not pack

| Skip | Why |
| --- | --- |
| `userdata` | Account/session. Use Steam Cloud for saves. |
| `compatdata` / Proton prefixes | Windows prefixes are useless on SteamOS. |
| `shadercache` | Huge; Deck rebuilds them. |
| `downloading`, `temp`, `logs` | Incomplete or junk. |
| The Steam client itself | Already on the Deck. |
| `_CommonRedist`, `setup.exe`, Steam-emulator DLLs | Not how Proton titles are installed. See [MANUAL.md §9](MANUAL.md). |

---

## 1. Quit Steam on Windows

Fully exit (tray icon → Exit). Copying while Steam is running can lock or truncate files.

---

## 2. Find every library

Games are often split across drives. Open:

```text
C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf
```

Each `"path"` is a library root. Typical ones:

- `C:\Program Files (x86)\Steam`
- `D:\SteamLibrary`
- `E:\SteamLibrary`

Inside each library you only care about `steamapps\`.

---

## 3. Pack on Windows (USB / portable drive)

Use **exFAT** (or NTFS). Do **not** use FAT32 — many game files are larger than 4 GB.

On the stick, keep this layout:

```text
SteamTransfer\
  steamapps\
    appmanifest_570.acf
    appmanifest_1091500.acf
    common\
      dota 2 beta\
      Cyberpunk 2077\
```

That `steamapps` folder is what you merge onto the Deck later.

### All games from one library

Copy the whole `steamapps` tree, then delete `downloading`, `temp`, and `shadercache`.

### Selected games

For each title:

1. In Steam → right-click game → **Properties** → **Updates** — note the **App ID** (or the store URL: `store.steampowered.com/app/1091500`).
2. Open `appmanifest_<AppID>.acf` in Notepad.
3. Read `"installdir"` — that is the folder name under `common`.
4. Copy:
   - `steamapps\appmanifest_<AppID>.acf`
   - `steamapps\common\<installdir>\` (the whole folder)

Do **not** zip unless you have to. Game data is already compressed; zip/7z mostly burns time and Deck CPU. A raw folder copy is faster to write and faster to extract.

If you must make one archive (network upload), use 7-Zip **Store** (no compression):

```text
7z a -mx=0 SteamGames.7z steamapps
```

---

## 4. Optional: PowerShell packer

Run after Steam is quit. Builds `D:\SteamTransfer\steamapps` from every library in `libraryfolders.vdf`. Change `$Out` if you want a different destination.

```powershell
$Out = "D:\SteamTransfer\steamapps"
$vdf = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
$libs = [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value -replace '\\\\','\' }

New-Item -ItemType Directory -Force -Path "$Out\common" | Out-Null

foreach ($lib in $libs) {
  $apps = Join-Path $lib "steamapps"
  if (-not (Test-Path $apps)) { continue }
  Write-Host "Library: $apps"
  Copy-Item "$apps\appmanifest_*.acf" $Out -Force
  Get-ChildItem "$apps\common" -Directory | ForEach-Object {
    Write-Host "  $($_.Name)"
    robocopy $_.FullName "$Out\common\$($_.Name)" /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS
  }
}
Write-Host "Packed to $Out"
```

One App ID (example `1091500`):

```powershell
$AppId = "1091500"
$Out   = "D:\SteamTransfer\steamapps"
$acf   = Get-ChildItem "${env:ProgramFiles(x86)}\Steam","D:\SteamLibrary" -Recurse -Filter "appmanifest_$AppId.acf" -ErrorAction SilentlyContinue |
         Select-Object -First 1
$dir   = (Select-String -Path $acf.FullName -Pattern '"installdir"\s+"([^"]+)"').Matches[0].Groups[1].Value
$common = Join-Path $acf.DirectoryName "common\$dir"

New-Item -ItemType Directory -Force -Path "$Out\common" | Out-Null
Copy-Item $acf.FullName $Out
robocopy $common "$Out\common\$dir" /E /XJ /R:1 /W:1
```

---

## 5. Get the pack onto this Deck

Pick one path. Official LAN transfer is the least work if both devices are on this LAN.

### A. Steam LAN transfer (no packing)

Both clients online, same account, same LAN. Steam → **Settings → Downloads → Game File Transfer over Local Network**. On the Deck tap **Install**; Steam pulls from the PC instead of the internet.

The sending client must be a **desktop** Steam (not Game Mode). The Deck can receive; it cannot send back.

### B. USB / exFAT stick (what §3 packed)

1. Plug the drive in. Switch to **Desktop Mode**.
2. Merge packed `steamapps` into the target:

   | Target | Path |
   | --- | --- |
   | Internal SSD | `/home/deck/.steam/steam/steamapps/` |
   | microSD (Steam-formatted) | `/run/media/deck/<card>/steamapps/` |

3. `.acf` files → `steamapps/`
4. Game folders → `steamapps/common/`
5. Do **not** overwrite the Deck’s `libraryfolders.vdf`.
6. Eject, return to **Game Mode** (or restart Steam in Desktop Mode).

If Steam does not list the game as installed: open it and hit **Install**. Steam should discover the files, verify, and only download deltas / Proton / shaders.

Then: **Properties → Installed Files → Verify integrity** for anything that looks wrong.

### C. Stage on the Mac, then `deckpushgame`

If the pack is on this Mac (USB mounted, or copied into a folder):

```bash
deckpushgame 'Cyberpunk 2077' /Volumes/USB/SteamTransfer/steamapps
```

`deckpushgame` rsyncs `common/<folder>/` plus the matching `appmanifest_*.acf` to `deck@10.0.0.143:/home/deck/.steam/steam/steamapps/`. Then on the Deck tap **Install** to verify.

Without a second argument it looks in the Mac Steam libraries (`~/Library/Application Support/Steam/steamapps`, etc.).

### D. Open-source GUIs

Steam-aware (copies folder **and** `.acf`):

| Tool | License | Role |
| --- | --- | --- |
| [Steam Library Manager](https://github.com/RevoLand/Steam-Library-Manager) | MIT | Windows GUI. Drag games onto a USB “library”. Closest packer. Last release 2025-03 (`v1.7.2.0`). |
| [CopyToDeck](https://github.com/Matalus/steamdeck-tips) | OSS | PowerShell picker. Windows → Deck over SSH/SSHFS or onto a microSD. Needs `sshd` on this Deck (already enabled). |

File pipe only (you still place `steamapps` yourself):

| Tool | License | Role |
| --- | --- | --- |
| [Winpinator](https://github.com/swiszczoo/winpinator) + [Warpinator](https://github.com/linuxmint/warpinator) | GPL-3.0 | LAN drag-and-drop. Warpinator is in Discover on the Deck. |
| [LocalSend](https://github.com/localsend/localsend) | MIT | Simpler cross-platform send/receive. |

Closed-source but Deck-specific: [Deck Drive Manager](https://deckdrivemanager.com/) writes games + ACF onto an ext4/Btrfs SD card. Free; not OSS.

Do **not** use Steam **Backup and Restore** onto the Deck — restore often finishes and then re-downloads everything.

---

## 6. After it shows as installed

- Steam will pull **Proton** and **shader pre-cache** the first time. Expected; much smaller than the game.
- Set compatibility if needed: gear → **Properties → Compatibility → Proton**.
- Missing VC++ in the prefix: [MANUAL.md §9](MANUAL.md) — Protontricks verbs, not a Windows `_CommonRedist`.
- Saves: enable **Steam Cloud** on both machines. Local Windows saves in `Documents` / `%APPDATA%` are a separate copy if Cloud is off.
- Stop the local AI / *arr / Jellyfin transcode stack first for heavy titles: QAM **Deck Focus → Game focus** or `deck game`.

---

## 7. Things that will bite you

- **Linux-native games:** the Windows folder still works under Proton. Deck may swap in a Linux depot on the next update — expect a download, not a full re-get.
- **Anti-cheat** (EAC, BattlEye, Vanguard, …): many online games will not run on Deck even with a perfect copy.
- **Incomplete Windows installs:** copy only titles that launch cleanly on the PC.
- **Same-LAN Wi-Fi vs Ethernet:** LAN transfer speed depends on the Deck’s radio. A USB pack is often faster for 80–150 GB titles.

---

## 8. Do-not (this procedure)

| Do not | Why |
| --- | --- |
| Copy only `common\<Game>` | Missing `.acf` → Steam re-downloads. |
| Overwrite Deck `libraryfolders.vdf` | Breaks existing internal / SD libraries. |
| Zip with maximum compression | Wastes hours; game assets are already compressed. |
| FAT32 the transfer stick | 4 GB file limit. |
| Pack `compatdata` / `shadercache` / `userdata` | Wrong platform or account-tied. |
| Steam Backup → Restore on Deck | Commonly re-downloads the whole title. |
| Sideload dumps / `_CommonRedist` / cracked Steam DLLs | Not a library export. See [MANUAL.md §13](MANUAL.md). |

---

## Quick reference

| I want to… | Do this |
| --- | --- |
| Pack selected Windows games | `.acf` + `common\<installdir>` onto exFAT `SteamTransfer\steamapps\` |
| Pack every library | PowerShell in §4, or copy each `steamapps` and delete junk |
| Official LAN copy | Steam → Downloads → Game File Transfer; Install on Deck |
| USB onto this Deck | Merge into `/home/deck/.steam/steam/steamapps/` (or the SD `steamapps`) |
| Push from this Mac | `deckpushgame 'Folder Name' /path/to/steamapps` |
| GUI packer | Steam Library Manager (OSS) or CopyToDeck |
| After copy | Install / Verify on Deck; Protontricks only if a runtime is missing |
