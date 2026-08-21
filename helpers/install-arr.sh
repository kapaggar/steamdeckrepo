#!/usr/bin/env bash
# *arr library managers — rootless Podman Quadlets, localhost only.
# Radarr / Sonarr / Prowlarr / Bazarr. Survives SteamOS updates ($HOME).
#
# Legal: library managers only. This script does not add pirate indexers,
# torrent site configs, Usenet provider keys, or download clients.
# Configure any legal indexers yourself. We do not ship any.
#
# Skipped on purpose: Readarr, Whisparr, Lidarr, qBittorrent, SABnzbd.
set -euo pipefail

H="${HOME}"
QUADLET_DIR="${H}/.config/containers/systemd"
TZ_NAME="America/Los_Angeles"
PUID="1000"
PGID="1000"

# Extra args after image are Volume= source:dest lines (appended after /config).
write_quadlet() {
  local name=$1 port=$2 image=$3
  shift 3
  local dest="${QUADLET_DIR}/${name}.container"
  local extra=""
  local line
  for line in "$@"; do
    extra="${extra}Volume=${line}"$'\n'
  done

  cat > "${dest}" << EOF
# ${name} library manager (localhost only). linuxserver amd64 image.
# Do not publish on 0.0.0.0. Do not add indexers or download-client keys here.
# Inter-app URL from another *arr container: http://10.0.2.2:${port}
# (pasta host-loopback → host 127.0.0.1). Not 127.0.0.1 inside the box.
#
# After edit:
#   systemctl --user daemon-reload
#   systemctl --user restart ${name}.service

[Unit]
Description=${name} library manager (localhost only)
After=network-online.target
Wants=network-online.target

[Container]
Image=${image}
ContainerName=${name}
PublishPort=127.0.0.1:${port}:${port}
Volume=%h/containers/${name}:/config
${extra}Environment=PUID=${PUID}
Environment=PGID=${PGID}
Environment=TZ=${TZ_NAME}
UserNS=keep-id
PodmanArgs=--network=pasta:--map-host-loopback,10.0.2.2

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
EOF
}

_http_code() {
  local url=$1
  curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "${url}" 2>/dev/null || echo 000
}

_unit_state() {
  systemctl --user is-active "${1}.service" 2>/dev/null || echo inactive
}

status() {
  echo "*arr library managers  $(date '+%Y-%m-%d %H:%M')"
  echo "  localhost only — not on the LAN (SSH -L from the Mac)"
  echo "  configure indexers yourself; we do not ship any"
  echo "  Game focus stops these. They fight the 15W APU with Jellyfin + Ollama."
  echo

  local name port url code state quad
  for spec in \
    "radarr 7878" \
    "sonarr 8989" \
    "prowlarr 9696" \
    "bazarr 6767"
  do
    name=${spec%% *}
    port=${spec##* }
    url="http://127.0.0.1:${port}"
    quad="${QUADLET_DIR}/${name}.container"
    if [[ ! -f "${quad}" ]]; then
      printf '  · %s.service  not installed\n' "${name}"
      continue
    fi
    state=$(_unit_state "${name}")
    code=$(_http_code "${url}")
    mark='·'
    [[ "${state}" == active ]] && mark='✓'
    printf '  %s  %s.service  %-8s  %s  HTTP %s\n' \
      "${mark}" "${name}" "${state}" "${url}" "${code}"
  done
  echo
  echo "  skipped: Readarr, Whisparr, Lidarr, download clients (none on this Deck)"
  echo "  media: ~/media/movies  ~/media/tv  ~/media/downloads (empty stub)"
}

start_units() {
  local name
  for name in radarr sonarr prowlarr bazarr; do
    if [[ -f "${QUADLET_DIR}/${name}.container" ]]; then
      systemctl --user start "${name}.service"
    fi
  done
}

stop_units() {
  local name
  for name in radarr sonarr prowlarr bazarr; do
    systemctl --user stop "${name}.service" 2>/dev/null || true
  done
}

restart_units() {
  local name
  for name in radarr sonarr prowlarr bazarr; do
    if [[ -f "${QUADLET_DIR}/${name}.container" ]]; then
      systemctl --user restart "${name}.service"
    fi
  done
}

wait_http() {
  local name=$1 url=$2
  local i code
  for i in $(seq 1 90); do
    code=$(_http_code "${url}")
    if [[ "${code}" =~ ^(200|301|302|303|307|308)$ ]]; then
      echo "  ${name} answering ${url} (HTTP ${code})"
      return 0
    fi
    sleep 2
  done
  echo "  ${name} started but ${url} not ready yet (HTTP ${code:-000})" >&2
  return 1
}

install_stack() {
  echo "== *arr library managers (localhost Quadlets) =="
  echo "  legal: no indexers, no Usenet keys, no download clients"
  echo "  images: linuxserver official amd64 (Deck is x86_64, not ARM)"
  echo

  mkdir -p \
    "${QUADLET_DIR}" \
    "${H}/containers/radarr" \
    "${H}/containers/sonarr" \
    "${H}/containers/prowlarr" \
    "${H}/containers/bazarr" \
    "${H}/media/movies" \
    "${H}/media/tv" \
    "${H}/media/downloads"

  write_quadlet radarr 7878 lscr.io/linuxserver/radarr:latest \
    "%h/media/movies:/movies" \
    "%h/media/downloads:/downloads"
  write_quadlet sonarr 8989 lscr.io/linuxserver/sonarr:latest \
    "%h/media/tv:/tv" \
    "%h/media/downloads:/downloads"
  write_quadlet prowlarr 9696 lscr.io/linuxserver/prowlarr:latest
  write_quadlet bazarr 6767 lscr.io/linuxserver/bazarr:latest \
    "%h/media/movies:/movies" \
    "%h/media/tv:/tv"

  echo "quadlets written under ${QUADLET_DIR}"

  if command -v podman >/dev/null 2>&1; then
    local img
    for img in \
      lscr.io/linuxserver/radarr:latest \
      lscr.io/linuxserver/sonarr:latest \
      lscr.io/linuxserver/prowlarr:latest \
      lscr.io/linuxserver/bazarr:latest
    do
      echo "pull ${img} …"
      podman pull "${img}"
    done
  else
    echo "podman not found — Quadlets will pull on first start" >&2
  fi

  systemctl --user daemon-reload

  local name
  for name in radarr sonarr prowlarr bazarr; do
    # Quadlets are generated units — systemctl enable fails; [Install] WantedBy is enough.
    if systemctl --user is-active --quiet "${name}.service"; then
      systemctl --user restart "${name}.service"
    else
      systemctl --user start "${name}.service"
    fi
    echo "  ${name}.service $(_unit_state "${name}")"
  done

  echo
  echo "waiting for UIs on 127.0.0.1 …"
  wait_http radarr   http://127.0.0.1:7878 || true
  wait_http sonarr   http://127.0.0.1:8989 || true
  wait_http prowlarr http://127.0.0.1:9696 || true
  wait_http bazarr   http://127.0.0.1:6767 || true
  echo
  status
}

cmd=${1:-install}
case "${cmd}" in
  install|apply)
    install_stack
    ;;
  status|'')
    status
    ;;
  start)
    start_units
    status
    ;;
  stop)
    stop_units
    status
    ;;
  restart)
    restart_units
    status
    ;;
  logs|log)
    shift
    unit=${1:-radarr}
    journalctl --user -u "${unit}.service" -n "${2:-80}" --no-pager
    ;;
  *)
    echo "usage: install-arr.sh [install|status|start|stop|restart|logs [unit]]" >&2
    exit 1
    ;;
esac
