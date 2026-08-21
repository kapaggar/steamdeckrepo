#!/usr/bin/env bash
# VS Code (user Flatpak) + Continue → local Ollama. Survives SteamOS /usr updates.
# Does not use snap or /usr. Does not start Ollama, Jellyfin, postgres, or redis.
set -euo pipefail

FLATPAK_ID="com.visualstudio.code"
H="${HOME}"
UID_NUM="$(id -u)"
SOCK="unix:///run/user/${UID_NUM}/podman/podman.sock"
DB="${H}/.local/bin/distrobox"
CODE_BIN="${H}/.local/bin/code"
FLAT_CFG="${H}/.var/app/${FLATPAK_ID}/config/Code/User"
DESKTOP_DIR="${H}/.local/share/applications"
FORCE=0

usage() {
  cat <<EOF
Usage: bash ~/.config/steamdeck/install-vscode.sh [--force]

  user Flatpak ${FLATPAK_ID}
  filesystem=home + talk-name org.freedesktop.Flatpak (Distrobox from the sandbox)
  Continue.continue → Ollama http://127.0.0.1:11434 model qwen2.5:1.5b
  terminal profile distrobox-dev (default)

Does not bind Ollama on 0.0.0.0. Does not start the AI stack.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1 ;;
    *) echo "unknown arg: ${arg}" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$(id -u)" -eq 0 ]]; then
  echo "do not run this as root; run as deck" >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak not found (stock SteamOS should have it)" >&2
  exit 1
fi

echo "== VS Code (user Flatpak) + Continue =="
echo "  home=${H}"

if flatpak --user info "${FLATPAK_ID}" >/dev/null 2>&1; then
  echo "already installed: $(flatpak --user info "${FLATPAK_ID}" 2>/dev/null | awk -F': *' '/^[[:space:]]*Version:/{print $2; exit}')"
else
  echo "installing ${FLATPAK_ID} (user, Flathub) …"
  flatpak install --user -y flathub "${FLATPAK_ID}"
fi

# See $HOME (~/src, Distrobox CLI) and host Distrobox via flatpak-spawn --host.
flatpak override --user --filesystem=home "${FLATPAK_ID}"
flatpak override --user --filesystem="xdg-run/podman" "${FLATPAK_ID}"
flatpak override --user --talk-name=org.freedesktop.Flatpak "${FLATPAK_ID}"
echo "overrides: filesystem=home, xdg-run/podman, talk-name=org.freedesktop.Flatpak"

cat > "${CODE_BIN}" << EOF
#!/usr/bin/env bash
# User Flatpak VS Code (not snap, not /usr).
export PATH="\${HOME}/.local/bin:\${PATH}"
export BROWSER="\${BROWSER:-\${HOME}/.local/bin/xdg-open}"
exec /usr/bin/flatpak run --user ${FLATPAK_ID} "\$@"
EOF
chmod 755 "${CODE_BIN}"
echo "wrapper: ${CODE_BIN}"

mkdir -p "${DESKTOP_DIR}" "${H}/Desktop"
DESKTOP_BODY=$(cat << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Visual Studio Code
GenericName=Code Editor
Comment=VS Code + Distrobox dev + Continue → local Ollama
Exec=${CODE_BIN} %F
Icon=${FLATPAK_ID}
Terminal=false
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=Code
MimeType=text/plain;inode/directory;
X-Flatpak=${FLATPAK_ID}
EOF
)
printf '%s\n' "${DESKTOP_BODY}" > "${DESKTOP_DIR}/code.desktop"
chmod 755 "${DESKTOP_DIR}/code.desktop"
cp -f "${DESKTOP_DIR}/code.desktop" "${H}/Desktop/code.desktop"
chmod 755 "${H}/Desktop/code.desktop"
echo "desktop: ${DESKTOP_DIR}/code.desktop + ~/Desktop"

# Integrated terminal: Distrobox dev (host, via flatpak-spawn).
mkdir -p "${FLAT_CFG}"
python3 - "${FLAT_CFG}/settings.json" "${DB}" "${SOCK}" << 'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
distrobox = sys.argv[2]
sock = sys.argv[3]
data = {}
if p.exists() and p.stat().st_size:
    data = json.loads(p.read_text())
profiles = dict(data.get("terminal.integrated.profiles.linux") or {})
profiles["distrobox-dev"] = {
    "path": "/usr/bin/flatpak-spawn",
    "args": ["--host", distrobox, "enter", "dev"],
    "overrideName": "distrobox-dev",
    "icon": "terminal-linux",
}
data["terminal.integrated.profiles.linux"] = profiles
data["terminal.integrated.defaultProfile.linux"] = "distrobox-dev"
data["terminal.integrated.cwd"] = "/home/deck/src"
data["docker.host"] = sock
p.write_text(json.dumps(data, indent=2) + "\n")
print(f"settings: {p}  profile=distrobox-dev")
PY

# Continue → local Ollama only. Do not bind 0.0.0.0.
mkdir -p "${H}/.continue"
write_continue() {
  local dest=$1
  if [[ -f "${dest}" && "${FORCE}" -ne 1 ]]; then
    cat >/dev/null
    echo "keep: ${dest} (pass --force to replace)"
    return
  fi
  cat > "${dest}"
  echo "wrote: ${dest}"
}

write_continue "${H}/.continue/config.json" << 'EOF'
{
  "models": [
    {
      "title": "Ollama qwen2.5:1.5b",
      "provider": "ollama",
      "model": "qwen2.5:1.5b",
      "apiBase": "http://127.0.0.1:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Ollama qwen2.5:1.5b",
    "provider": "ollama",
    "model": "qwen2.5:1.5b",
    "apiBase": "http://127.0.0.1:11434"
  }
}
EOF

write_continue "${H}/.continue/config.yaml" << 'EOF'
name: Steam Deck local
version: 0.0.1
schema: v1
models:
  - name: Ollama qwen2.5:1.5b
    provider: ollama
    model: qwen2.5:1.5b
    apiBase: http://127.0.0.1:11434
    roles:
      - chat
      - edit
      - apply
      - autocomplete
EOF

echo "installing Continue.continue …"
if "${CODE_BIN}" --install-extension Continue.continue --force >/tmp/deck-continue-install.log 2>&1; then
  echo "Continue: installed (Continue.continue)"
else
  echo "Continue: leftover — first launch may finish the marketplace install" >&2
  echo "  log: /tmp/deck-continue-install.log" >&2
  tail -20 /tmp/deck-continue-install.log >&2 || true
fi

echo
echo "Launch: Desktop Visual Studio Code, or: code   (or: deck vscode)"
echo "Terminal profile: distrobox-dev  →  distrobox enter dev  (via flatpak-spawn --host)"
echo "Continue: http://127.0.0.1:11434  model qwen2.5:1.5b"
echo "DOCKER_HOST=${SOCK}  (Docker-API compatible ≠ every Docker extension works)"
echo "Ollama stays localhost-only. This script does not start it."
