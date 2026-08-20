#!/usr/bin/env bash
# Idempotent Steam Deck user-space bootstrap (survives SteamOS image updates).
# Rule: /usr is disposable — persistent tools live under $HOME.
set -euo pipefail

WITH_CONTAINER=0
WITH_AI=0
for arg in "$@"; do
  case "${arg}" in
    --with-container) WITH_CONTAINER=1 ;;
    --with-ai) WITH_AI=1 ;;
  esac
done

H="${HOME}"
mkdir -p "${H}/.local/bin"
mkdir -p "${H}/.config/systemd/user"
mkdir -p "${H}/.config/containers/systemd"
mkdir -p "${H}/.local/share/containers"
mkdir -p "${H}/containers"
mkdir -p "${H}/Applications"
mkdir -p "${H}/.config/steamdeck"

# PATH for this session (bashrc also sets this)
export PATH="${H}/.local/bin:${H}/.grok/bin:${PATH}"

echo "== Steam Deck user-space bootstrap =="
echo "home=${H}"

# --- Podman user socket (rootless API) ---
if command -v podman >/dev/null 2>&1; then
  echo "podman: $(podman --version)"
  systemctl --user enable --now podman.socket 2>/dev/null || true
  echo "podman.socket: $(systemctl --user is-active podman.socket 2>/dev/null || echo unknown)"
else
  echo "podman: not found (SteamOS image may not include it yet)"
fi

# --- Linger (headless user services at boot) ---
linger=$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || echo unknown)
echo "linger: ${linger}"
if [[ "${linger}" == "no" ]]; then
  echo "  → run once (needs sudo password): sudo loginctl enable-linger ${USER}"
fi

# --- Distrobox in ~/.local (update-surviving install) ---
DB="${H}/.local/bin/distrobox"
if [[ -x "${DB}" ]]; then
  echo "distrobox: $("${DB}" --version 2>/dev/null || echo ~/.local)"
elif command -v curl >/dev/null 2>&1; then
  echo "installing distrobox → ~/.local …"
  curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install \
    | sh -s -- --prefix "${H}/.local"
  DB="${H}/.local/bin/distrobox"
  echo "distrobox: $("${DB}" --version 2>/dev/null || echo installed)"
else
  echo "distrobox: skip install (no curl); system: $(command -v distrobox 2>/dev/null || echo none)"
  DB="$(command -v distrobox 2>/dev/null || true)"
fi

# --- Optional arch-tools container ---
if [[ "${WITH_CONTAINER}" -eq 1 && -n "${DB}" ]]; then
  if "${DB}" list 2>/dev/null | awk '{print $3}' | grep -qx arch-tools; then
    echo "distrobox arch-tools: already exists"
  else
    echo "creating distrobox arch-tools (may take a few minutes) …"
    "${DB}" create --name arch-tools --image docker.io/library/archlinux:latest --yes
    echo "distrobox arch-tools: created"
  fi
fi

# --- Optional ai-box (Ollama host) ---
if [[ "${WITH_AI}" -eq 1 && -n "${DB}" ]]; then
  if "${DB}" list 2>/dev/null | awk '{print $3}' | grep -qx ai-box; then
    echo "distrobox ai-box: already exists"
  else
    echo "creating distrobox ai-box (may take a few minutes) …"
    "${DB}" create --name ai-box --image docker.io/library/archlinux:latest --yes
    echo "distrobox ai-box: created — next: official ollama install inside the box"
  fi
fi

# --- Quadlet example (not enabled by default) ---
EXAMPLE="${H}/.config/containers/systemd/example.container"
if [[ ! -f "${EXAMPLE}" ]]; then
  cat > "${EXAMPLE}" << 'EOF'
# Example Podman Quadlet — copy to myapp.container, edit, then:
#   systemctl --user daemon-reload
#   systemctl --user enable --now myapp.service
#
# [Container]
# Image=docker.io/vendor/app:latest
# PublishPort=127.0.0.1:8080:8080
# Volume=%h/containers/myapp:/config:Z
#
# [Service]
# Restart=always
#
# [Install]
# WantedBy=default.target
EOF
  echo "quadlet example: ${EXAMPLE}"
fi

# --- Reload user systemd if quadlets exist ---
if compgen -G "${H}/.config/containers/systemd/"'*.container' >/dev/null 2>&1; then
  systemctl --user daemon-reload 2>/dev/null || true
fi

# --- Grok CLI (~/.grok — user space) ---
if [[ ! -x "${H}/.grok/bin/grok" ]] && command -v curl >/dev/null; then
  echo "grok: missing — reinstalling to ~/.grok …"
  curl -fsSL https://x.ai/cli/install.sh | bash 2>/dev/null || echo "grok: install failed (run manually)"
fi

echo
echo "Persistent layout OK. Run: deck audit"
