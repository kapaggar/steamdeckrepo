# Distrobox is a host tool (rootless Podman). $HOME is bind-mounted into boxes,
# so ~/.local/bin/distrobox is visible inside ai-box/dev, but host podman is not.
# Do not install podman/docker/lilipod inside a box — proxy to the host instead.
#
# Sourced from deck-remote.bashrc (Deck interactive shells, including inside boxes)
# and steamdeck.bash (Mac; no-op unless already in a container).
# Host-exec runs on the host: CONTAINER_ID is empty and /run/.containerenv is absent,
# so this wrapper is not defined there and cannot recurse.

_steamdeck_in_distrobox() {
  [[ -n "${CONTAINER_ID:-}" || -f /run/.containerenv ]]
}

_steamdeck_distrobox() {
  if _steamdeck_in_distrobox; then
    if command -v distrobox-host-exec >/dev/null 2>&1; then
      command distrobox-host-exec distrobox "$@"
      return
    fi
    echo "distrobox: already inside a box (${CONTAINER_ID:-unknown}); exit, then run distrobox on the host." >&2
    return 1
  fi
  command distrobox "$@"
}

# Only shadow the command inside a box so host `type distrobox` stays the real binary.
if _steamdeck_in_distrobox; then
  distrobox() { _steamdeck_distrobox "$@"; }
fi
