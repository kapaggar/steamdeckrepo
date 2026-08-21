# Steam Deck on-device helpers (managed from Mac)
# ~/.config/steamdeck/deck-remote.bashrc

export STEAM_STEAMAPPS="${HOME}/.steam/steam/steamapps"
export STEAM_COMMON="${STEAM_STEAMAPPS}/common"
export STEAM_USERDATA="${HOME}/.local/share/Steam/userdata"
export STEAM_DOWNLOADS="${HOME}/Downloads"

# User Flatpak exports (VS Code) — stock XDG_DATA_DIRS often omits this
export XDG_DATA_DIRS="${HOME}/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

alias games='ls -1 "${STEAM_COMMON}" 2>/dev/null | sort'
alias steamapps='cd "${STEAM_STEAMAPPS}" && pwd && ls -la'
alias saves='cd "${STEAM_USERDATA}" && pwd && ls -la'
alias deckmedia='ls -la /run/media/deck 2>/dev/null || echo "(no media)"'

deckdf() {
  df -h /home/deck /run/media/deck 2>/dev/null
  du -sh "${STEAM_COMMON}" "${STEAM_USERDATA}" 2>/dev/null
}

deckusage() {
  echo "Steam paths on this Deck:"
  echo "  STEAM_COMMON    ${STEAM_COMMON}"
  echo "  STEAM_STEAMAPPS ${STEAM_STEAMAPPS}"
  echo "  STEAM_USERDATA  ${STEAM_USERDATA}"
  echo
  deckdf
  echo
  echo "Installed games: $(ls -1 "${STEAM_COMMON}" 2>/dev/null | wc -l | tr -d ' ')"
}

[[ -r "$HOME/.config/steamdeck/deck-help.bash" ]] && source "$HOME/.config/steamdeck/deck-help.bash"

deckaudit() {
  bash "$HOME/.config/steamdeck/audit.sh"
}

deckbootstrap() {
  bash "$HOME/.config/steamdeck/bootstrap.sh" "$@"
}

deckbox() {
  local db="${HOME}/.local/bin/distrobox"
  [[ -x "${db}" ]] || db=$(command -v distrobox 2>/dev/null || true)
  [[ -n "${db}" ]] || { echo "distrobox not found — run: deck bootstrap" >&2; return 1; }
  exec "${db}" enter arch-tools "$@"
}

deckboxai() {
  local db="${HOME}/.local/bin/distrobox"
  [[ -x "${db}" ]] || db=$(command -v distrobox 2>/dev/null || true)
  [[ -n "${db}" ]] || { echo "distrobox not found — run: deck bootstrap" >&2; return 1; }
  export PATH="/usr/bin:/bin:${HOME}/.local/bin:${PATH}"
  exec "${db}" enter ai-box "$@"
}

deckdev() {
  local db="${HOME}/.local/bin/distrobox"
  [[ -x "${db}" ]] || db=$(command -v distrobox 2>/dev/null || true)
  [[ -n "${db}" ]] || { echo "distrobox not found — run: deck bootstrap" >&2; return 1; }
  export PATH="/usr/bin:/bin:${HOME}/.local/bin:${PATH}"
  exec "${db}" enter dev "$@"
}

deckvscode() {
  export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH}"
  if [[ "${1:-}" == install || "${1:-}" == --install ]]; then
    shift
    bash "${HOME}/.config/steamdeck/install-vscode.sh" "$@"
    return
  fi
  if ! command -v code >/dev/null; then
    echo "code missing — run: deck vscode install" >&2
    return 1
  fi
  nohup code "$@" >/tmp/deck-vscode.log 2>&1 &
  echo "VS Code launched (Desktop Mode). log: /tmp/deck-vscode.log"
}

deckai() {
  bash "${HOME}/.config/steamdeck/ai-status.sh"
}

deckgamefocus() {
  bash "${HOME}/.config/steamdeck/game-focus.sh"
}

deckaifocus() {
  bash "${HOME}/.config/steamdeck/ai-focus.sh"
}

deckwebui() {
  local sub=${1:-status}
  case "${sub}" in
    start|stop|restart)
      systemctl --user "${sub}" open-webui.service
      systemctl --user --no-pager -l status open-webui.service | head -16
      ;;
    logs|log)
      shift
      journalctl --user -u open-webui.service -n "${1:-80}" --no-pager
      ;;
    *)
      echo "Open WebUI  http://127.0.0.1:3000"
      bash "${HOME}/.config/steamdeck/ai-status.sh"
      ;;
  esac
}

deckollama() {
  local sub=${1:-status}
  case "${sub}" in
    status|'')
      bash "${HOME}/.config/steamdeck/ai-status.sh"
      echo
      systemctl --user --no-pager -l status ollama.service | head -24
      ;;
    logs|log)
      shift
      journalctl --user -u ollama.service -n "${1:-80}" --no-pager
      ;;
    start|stop|restart)
      systemctl --user "${sub}" ollama.service
      systemctl --user --no-pager -l status ollama.service | head -16
      ;;
    *)
      export PATH="/usr/bin:/bin:${HOME}/.local/bin:${PATH}"
      command ollama "$@"
      ;;
  esac
}

deckjellyfin() {
  local sub=${1:-status}
  case "${sub}" in
    start|stop|restart)
      systemctl --user "${sub}" jellyfin.service
      systemctl --user --no-pager -l status jellyfin.service | head -16
      ;;
    logs|log)
      shift
      journalctl --user -u jellyfin.service -n "${1:-80}" --no-pager
      ;;
    *)
      echo "Jellyfin  http://127.0.0.1:8096  and LAN :8096  (media ~/media)"
      systemctl --user --no-pager -l status jellyfin.service | head -16
      ;;
  esac
}

deckarr() {
  local sub=${1:-status}
  case "${sub}" in
    install|apply|start|stop|restart)
      bash "${HOME}/.config/steamdeck/install-arr.sh" "${sub}"
      ;;
    logs|log)
      shift
      bash "${HOME}/.config/steamdeck/install-arr.sh" logs "$@"
      ;;
    *)
      echo "*arr  http://127.0.0.1:{7878,8989,9696,6767}  (localhost only)"
      echo "  configure indexers yourself; we do not ship any"
      bash "${HOME}/.config/steamdeck/install-arr.sh" status
      ;;
  esac
}

deck() {
  case "${1:-}" in
    ''|help|-h|--help)
      if declare -F _deck_print_usage >/dev/null 2>&1; then
        _deck_print_usage "Steam Deck"
      else
        _deck_usage_remote 2>/dev/null || deckusage
      fi
      ;;
    local|remote|deck)
      if declare -F _deck_usage_remote >/dev/null 2>&1; then
        _deck_usage_remote
      else
        deckusage
      fi
      ;;
    tools|cli)
      if declare -F _deck_usage_tools >/dev/null 2>&1; then
        _deck_usage_tools
      else
        echo "grok  agent  cursor  emudeck"
      fi
      ;;
    paths|path)
      if declare -F _deck_usage_paths >/dev/null 2>&1; then
        _deck_usage_paths
      fi
      ;;
    arch|persist|update)
      if declare -F _deck_usage_arch >/dev/null 2>&1; then
        _deck_usage_arch
      fi
      ;;
    audit)
      shift
      deckaudit "$@"
      ;;
    bootstrap|boot)
      shift
      deckbootstrap "$@"
      ;;
    box|arch-tools)
      shift
      deckbox "$@"
      ;;
    box-ai|ai-box)
      shift
      deckboxai "$@"
      ;;
    dev|box-dev)
      shift
      deckdev "$@"
      ;;
    vscode|code)
      shift
      deckvscode "$@"
      ;;
    ai)
      shift
      deckai "$@"
      ;;
    game|game-focus|ai-off)
      shift
      deckgamefocus "$@"
      ;;
    ai-on|ai-focus)
      shift
      deckaifocus "$@"
      ;;
    ollama)
      shift
      deckollama "$@"
      ;;
    webui|open-webui)
      shift
      deckwebui "$@"
      ;;
    jellyfin|jf)
      shift
      deckjellyfin "$@"
      ;;
    arr)
      shift
      deckarr "$@"
      ;;
    df)
      deckdf
      ;;
    games)
      games
      ;;
    protontricks|winetricks)
      shift
      export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH}"
      if [[ "${1:-}" == install || "${1:-}" == --install ]]; then
        shift
        bash "${HOME}/.config/steamdeck/install-protontricks.sh" "$@"
      else
        command protontricks "$@"
      fi
      ;;
    usage)
      deckusage
      ;;
    *)
      echo "deck: unknown topic '$1'  (try: deck help)" >&2
      return 1
      ;;
  esac
}

alias dhelp='deck'
