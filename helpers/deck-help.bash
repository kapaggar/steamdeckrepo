# Shared deck help renderer — sourced by `deck` on Mac and Steam Deck

_deck_print_usage() {
  local where=${1:-mac}
  cat <<EOF
Steam Deck helpers  (${where})
Target: ${STEAMDECK_SSH:-deck@10.0.0.143}

Usage:  deck              this page
        deck help          same
        deck ssh           open SSH shell on Deck
        deck <topic>       deck mac | deck remote | deck tools | deck paths | deck arch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Mac → Deck  (run from this Mac)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Connection
    deckping | dping       test SSH to Deck
    decksh | dsh           interactive shell on Deck
    deck ssh               same as decksh
    ssh steamdeck          SSH host alias (~/.ssh/config)

  Library & disk
    deckdf                 remote disk + library sizes
    deckmounts             list SD / USB mounts
    deckgames | dgames     list installed game folders
    deckmanifests          list Steam app IDs

  File transfer
    deckpush SRC [DST]     copy to Deck (default ~/Downloads)
    deckpull SRC [DST]     copy from Deck (default .)
    dpush / dpull          aliases for push / pull

  Games & saves
    deckpushgame NAME      push game + appmanifest from Mac Steam library
    deckpullgame NAME      pull game folder from Deck
    deckpullsaves [DIR]    backup userdata/ (default ~/Backups/steamdeck-saves)
    deckpushsaves [DIR]    restore saves backup
    deckscreenshots [DIR]  pull Steam screenshots
    deckmods               find mod/workshop dirs on Deck
    deckrestartsteam       restart Steam client remotely

  Remote CLIs (via SSH + TTY)
    deckagent [ARGS]       Cursor Agent on Deck
    deckgrok [ARGS]         Grok CLI on Deck
    deckcat FILE            print remote file

  Architecture (update-surviving $HOME layout)
    deck audit             remote audit checklist
    deck bootstrap [OPTS]    remote bootstrap (--with-container)
    deck arch              architecture help

  Local AI (Ollama in Distrobox ai-box)
    deck ai                ollama + ai-box + Decky + Open WebUI status
    deck webui             Open WebUI URL http://127.0.0.1:3000
    deck webui start|stop|restart|logs
    deck ollama            same + user-unit status
    deck ollama logs       journalctl --user -u ollama.service
    deck ollama start|stop|restart
    deck box-ai            distrobox enter ai-box
    warning: local inference competes with running games
    Do not use bonsAI Install Ollama — use the Distrobox unit

  Env overrides
    STEAMDECK_HOST  STEAMDECK_USER  STEAMDECK_SSH

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 On Deck  (Konsole / Desktop Mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Aliases
    games                  list game folders in steamapps/common
    steamapps              cd ~/.steam/steam/steamapps
    saves                  cd Steam userdata (saves)
    deckmedia              list /run/media/deck (SD/USB)

  Functions
    deckdf                 disk usage + library sizes
    deckusage              paths summary + game count

  CLIs (PATH: ~/.local/bin ~/.grok/bin)
    grok                   Grok AI terminal
    agent | cursor-agent   Cursor Agent CLI
    cursor                 Cursor IDE AppImage launcher

  Desktop shortcuts
    Grok CLI, Cursor Agent, Cursor IDE, Google Chrome, Open WebUI

  Browser login fix
    ~/.local/bin/xdg-open  opens http(s) in Chrome Flatpak (wrapper)

  Chrome → Open WebUI (localhost)
    Desktop Google Chrome (our .desktop, not the Discover symlink)
    New tab = big Open WebUI button; bookmarks bar = Open WebUI
    Fully quit Chrome, then relaunch from ~/Desktop
    Re-apply: bash ~/.config/steamdeck/install-chrome-open-webui.sh

  Config files
    ~/.config/steamdeck/               bootstrap, audit, helpers
    ~/.config/steamdeck/deck-remote.bashrc
    ~/.config/containers/systemd/      Podman Quadlets
    ~/.config/systemd/user/            user services

  Update-surviving layout (SteamOS)
    deck audit             checklist (\$HOME vs /usr)
    deck bootstrap         mkdirs, podman.socket, ~/.local distrobox
    deck box               enter arch-tools Distrobox
    deck box-ai            enter ai-box Distrobox (Ollama)
    Persistent: ~/.local/bin ~/.grok ~/.config ~/Applications ~/containers ~/.ollama
    Disposable:  /usr (SteamOS image — do not install tools here)

EOF
}

_deck_usage_mac() {
  _deck_print_usage "Mac"
}

_deck_usage_remote() {
  cat <<'EOF'
On-Deck commands (run in Konsole on the Steam Deck)

  deck                   full help (Mac + Deck sections if synced)
  deck local             this section only
  deck df                disk + library usage
  deck games             list installed games
  deck paths             show Steam directory paths

  games                  alias → list game folders
  steamapps              alias → cd steamapps
  saves                  alias → cd userdata
  deckmedia              alias → list removable media
  deckdf                 disk usage function
  deckusage              paths + counts

  grok | agent | cursor  installed CLIs / IDE

  Architecture (survives SteamOS updates)
    deck audit             audit \$HOME-first setup
    deck bootstrap         bootstrap user-space (add --with-container)
    deck box               distrobox enter arch-tools
    deck box-ai            distrobox enter ai-box
    deck ai                local Ollama + Decky + Open WebUI status
    deck webui             Open WebUI http://127.0.0.1:3000
    deck ollama            ollama.service status / logs / start|stop
    Do not use bonsAI Install Ollama — use the Distrobox unit
EOF
}

_deck_usage_tools() {
  cat <<'EOF'
Installed tools on Deck

  grok                   ~/.grok/bin/grok
  agent                  ~/.local/bin/agent
  cursor                 ~/.local/bin/cursor  → ~/Applications/cursor/
  google-chrome          ~/.local/bin/google-chrome → Flatpak + Open WebUI new-tab
  retroarch              Steam library (steamapps/common/RetroArch)

  Local AI
    ollama                 ~/.local/bin/ollama → Distrobox ai-box
    ollama.service         user systemd (OLLAMA_HOST=127.0.0.1:11434)
    Open WebUI             http://127.0.0.1:3000  (Quadlet; Chrome new tab / bookmark)
    Decky + bonsAI         QAM chat (plugin_loader.service; restart Game Mode for QAM icon)
    Do not use bonsAI Install Ollama — use the Distrobox unit

  Login
    grok login
    agent login
    agent status
EOF
}

_deck_usage_paths() {
  cat <<'EOF'
Common paths on Deck (persistent under $HOME)

  ~/.local/bin/                  user CLI wrappers
  ~/.grok/                       Grok CLI
  ~/.local/share/cursor-agent/   Cursor Agent
  ~/.local/share/steamdeck/      Chrome Open WebUI new-tab extension
  ~/.config/steamdeck/           deck helpers, bootstrap, audit
  ~/.config/systemd/user/        user systemd units
  ~/.config/containers/systemd/  Podman Quadlets (*.container)
  ~/containers/                  container data volumes
  ~/Applications/                AppImages (Cursor, EmuDeck, …)

  ~/Emulation/roms/              EmuDeck ROMs
  ~/Emulation/bios/              EmuDeck BIOS
  ~/.steam/steam/steamapps/      Steam library
  ~/.local/share/Steam/userdata/ saves
  ~/Downloads/                   Mac deckpush drop folder
  /run/media/deck/               SD / USB (may change mount name)

  Local AI
    ~/.ollama/                   Ollama models (host \$HOME, bind-mounted into ai-box)
    ~/.config/systemd/user/ollama.service
    ~/.local/bin/ollama          CLI wrapper into ai-box
    ~/.config/containers/systemd/open-webui.container
    ~/containers/open-webui/     Open WebUI persistent state
    ~/homebrew/                  Decky Loader + plugins (QAM)
    ~/homebrew/plugins/bonsAI
    ~/Downloads/decky-plugins/   staged zips / decky-ollama source
EOF
}

_deck_usage_arch() {
  cat <<'EOF'
Update-surviving SteamOS architecture

  Principle: /usr is wiped on image updates — keep tools in $HOME.

  Baseline dirs
    ~/.local/bin
    ~/.config/systemd/user
    ~/.config/containers/systemd
    ~/containers
    ~/Applications

  Bootstrap (on Deck)
    deck bootstrap                    podman.socket + ~/.local distrobox
    deck bootstrap --with-container   also create arch-tools Distrobox
    deck bootstrap --with-ai          also create ai-box Distrobox

  Headless services at boot
    sudo loginctl enable-linger deck   (once, needs password)
    systemctl --user enable --now podman.socket
    systemctl --user enable --now ollama.service
    systemctl --user start open-webui.service   (Quadlet; auto via default.target)

  Local AI (CPU first, localhost only)
    Distrobox ai-box + official Ollama in the box
    OLLAMA_HOST=127.0.0.1:11434
    models persist in ~/.ollama
    Open WebUI at http://127.0.0.1:3000 (rootless Quadlet, pasta host-loopback)
    Decky Ollama + bonsAI for Gaming Mode QAM
    Do not use bonsAI Install Ollama — use the Distrobox unit
    warning: local inference competes with running games
    GPU later (do not enable ROCm): drop OLLAMA_NO_GPU=1,
    optionally OLLAMA_VULKAN=1, recreate ai-box with --device=/dev/dri

  Quadlet pattern (~/.config/containers/systemd/myapp.container)
    systemctl --user daemon-reload
    systemctl --user enable --now myapp.service

  See also: ~/.config/containers/systemd/example.container
EOF
}
