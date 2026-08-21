#!/usr/bin/env bash
# Game focus (STOP): free CPU/RAM for games by stopping our local AI stack.
# Safe: never touches Steam, Decky plugin_loader, Flatpak browsers, or sdgyrodsu.
set -euo pipefail

export HOME="${HOME:-/home/deck}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

echo "Game focus: stopping local AI + *arr (Ollama + Open WebUI + Jellyfin + library managers)"
echo "  leaving Steam, Decky plugin_loader, Flatpak browsers, and sdgyrodsu alone"

systemctl --user stop open-webui.service 2>/dev/null || true
systemctl --user stop ollama.service 2>/dev/null || true
systemctl --user stop jellyfin.service 2>/dev/null || true
systemctl --user stop radarr.service 2>/dev/null || true
systemctl --user stop sonarr.service 2>/dev/null || true
systemctl --user stop prowlarr.service 2>/dev/null || true
systemctl --user stop bazarr.service 2>/dev/null || true

# Only AI containers we created. Never a blanket podman stop --all.
# Do not add: jellyfin*, dev, or other non-AI boxes.
OUR_CONTAINERS=(open-webui ai-box)
if command -v podman >/dev/null 2>&1; then
  for name in "${OUR_CONTAINERS[@]}"; do
    case "${name}" in
      steam|plugin_loader|sdgyrodsu|*chrome*|*firefox*)
        echo "  skip protected name: ${name}"
        continue
        ;;
    esac
    if podman container exists "${name}" 2>/dev/null; then
      podman stop "${name}" >/dev/null 2>&1 || true
    fi
  done
fi

echo "Game focus: AI + *arr stack stopped"
