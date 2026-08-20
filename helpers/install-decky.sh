#!/usr/bin/env bash
# Finish official Decky Loader install (needs sudo once).
# User-space files are already staged under ~/homebrew.
# SteamOS updates can break Decky — re-run this after a SteamOS image update.
set -euo pipefail

H="${HOME}"
HB="${H}/homebrew"

echo "Decky finish-install"
echo "  staged PluginLoader: $(cat "${HB}/services/.loader.version" 2>/dev/null || echo missing)"
echo "  plugins: $(find "${HB}/plugins" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | tr '\n' ' ')"
echo

if [[ "$(id -u)" -eq 0 ]]; then
  echo "do not run this as root; run as deck and let sudo escalate" >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  cat <<EOF
Passwordless sudo is not configured, so the official installer cannot finish
over SSH. On the Deck (Desktop Mode Konsole, or an interactive SSH tty):

  curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh

Or, if you want to grant passwordless sudo first (optional, persists in /etc):

  echo 'deck ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/zz-deck-nopasswd
  sudo chmod 440 /etc/sudoers.d/zz-deck-nopasswd
  sudo -n true && bash ~/.config/steamdeck/install-decky.sh

After install:
  1. Restart Game Mode (or reboot) so the QAM plug icon appears.
  2. QAM (… ) → Decky plug → enable bonsAI and decky-ollama if needed.
  3. bonsAI → Ollama → set base URL http://127.0.0.1:11434
  4. Do not use bonsAI Install Ollama — use the Distrobox unit
     (systemctl --user start ollama.service). Chat UI is fine; skip install/update.
  5. decky-ollama start/stop must stay on systemctl --user ollama.service (127.0.0.1).
     Do not let an update bind 0.0.0.0 or pkill ollama.

SteamOS updates wipe /usr and can drop /etc/systemd/system/plugin_loader.service.
Re-run the official installer after an update if the QAM plug disappears.
Game Mode was not restarted by this setup.
EOF
  exit 2
fi

# Official installer re-execs itself with sudo and writes /etc/systemd/system/plugin_loader.service
SCRIPT="${H}/.config/steamdeck/install_release.sh"
if [[ ! -f "${SCRIPT}" ]]; then
  curl -fL --retry 3 -o "${SCRIPT}" \
    "https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh"
  chmod +x "${SCRIPT}"
fi
exec bash "${SCRIPT}"
