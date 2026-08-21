# Steam Deck helpers — Mac bash (passwordless SSH to deck@10.0.0.143)
# Source from ~/.bashrc

export STEAMDECK_HOST="${STEAMDECK_HOST:-10.0.0.143}"
export STEAMDECK_USER="${STEAMDECK_USER:-deck}"
export STEAMDECK_SSH="${STEAMDECK_SSH:-${STEAMDECK_USER}@${STEAMDECK_HOST}}"

# Remote paths (SteamOS symlinks ~/.steam/steam → ~/.local/share/Steam)
export STEAMDECK_STEAMAPPS='/home/deck/.steam/steam/steamapps'
export STEAMDECK_COMMON="${STEAMDECK_STEAMAPPS}/common"
export STEAMDECK_USERDATA='/home/deck/.local/share/Steam/userdata'
export STEAMDECK_DOWNLOADS='/home/deck/Downloads'
export STEAMDECK_MEDIA='/run/media/deck'

_deck_ssh() {
  ssh -o ConnectTimeout=8 "$STEAMDECK_SSH" "$@"
}

_deck_rsync() {
  rsync -avh --progress -e "ssh -o ConnectTimeout=8" "$@"
}

deckping() {
  if _deck_ssh 'echo ok' >/dev/null 2>&1; then
    echo "steamdeck up  $STEAMDECK_SSH"
    return 0
  fi
  echo "steamdeck down  $STEAMDECK_SSH" >&2
  return 1
}

# shellcheck source=/dev/null
[[ -r "${BASH_SOURCE[0]%/*}/deck-help.bash" ]] && source "${BASH_SOURCE[0]%/*}/deck-help.bash"

deck() {
  case "${1:-}" in
    ''|help|-h|--help)
      _deck_usage_mac
      ;;
    mac)
      _deck_usage_mac
      ;;
    remote|local|deck)
      _deck_usage_remote
      ;;
    tools|cli)
      _deck_usage_tools
      ;;
    paths|path)
      _deck_usage_paths
      ;;
    arch|persist|update)
      _deck_usage_arch
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
    ssh|sh|shell)
      shift
      decksh "$@"
      ;;
    ping)
      shift
      deckping "$@"
      ;;
    df)
      deckdf
      ;;
    games)
      deckgames
      ;;
    push)
      shift
      deckpush "$@"
      ;;
    pull)
      shift
      deckpull "$@"
      ;;
    *)
      echo "deck: unknown topic '$1'  (try: deck help)" >&2
      return 1
      ;;
  esac
}

decksh() {
  deckping || return 1
  _deck_ssh -t "$@"
}

deckdf() {
  deckping || return 1
  _deck_ssh 'df -h /home/deck /run/media/deck 2>/dev/null; echo; du -sh ~/.steam/steam/steamapps/common ~/.local/share/Steam/userdata 2>/dev/null'
}

deckmounts() {
  deckping || return 1
  _deck_ssh "ls -la ${STEAMDECK_MEDIA} 2>/dev/null || echo '(no removable media mounted)'"
}

deckgames() {
  deckping || return 1
  _deck_ssh "ls -1 ${STEAMDECK_COMMON} 2>/dev/null | sort"
}

deckmanifests() {
  deckping || return 1
  _deck_ssh "ls -1 ${STEAMDECK_STEAMAPPS}/appmanifest_*.acf 2>/dev/null | xargs -n1 basename | sed 's/appmanifest_//;s/.acf$//'"
}

deckpush() {
  local src=${1:?usage: deckpush LOCAL_PATH [REMOTE_PATH]}
  local dst=${2:-${STEAMDECK_DOWNLOADS}/}
  deckping || return 1
  _deck_rsync "$src" "${STEAMDECK_SSH}:${dst}"
}

deckpull() {
  local src=${1:?usage: deckpull REMOTE_PATH [LOCAL_PATH]}
  local dst=${2:-.}
  deckping || return 1
  _deck_rsync "${STEAMDECK_SSH}:${src}" "$dst"
}

deckpushgame() {
  local game=${1:?usage: deckpushgame GAME_FOLDER_NAME [LOCAL_STEAMAPPS_DIR]}
  local local_root=${2:-}
  deckping || return 1

  if [[ -z $local_root ]]; then
    for candidate in \
      "$HOME/Library/Application Support/Steam/steamapps" \
      "$HOME/.steam/steam/steamapps" \
      "$HOME/.local/share/Steam/steamapps"
    do
      [[ -d "$candidate/common/$game" ]] && local_root=$candidate && break
    done
  fi
  if [[ -z $local_root || ! -d "$local_root/common/$game" ]]; then
    echo "deckpushgame: cannot find local game folder '$game'" >&2
    echo "  pass steamapps root as 2nd arg, e.g. deckpushgame '$game' /path/to/steamapps" >&2
    return 1
  fi

  echo "push game folder …"
  _deck_rsync "$local_root/common/$game/" "${STEAMDECK_SSH}:${STEAMDECK_COMMON}/$game/"

  local acf
  acf=$(find "$local_root" -maxdepth 1 -name 'appmanifest_*.acf' -exec grep -l "\"installdir\"[[:space:]]*\"$game\"" {} + 2>/dev/null | head -1)
  if [[ -n $acf ]]; then
    echo "push manifest $(basename "$acf") …"
    _deck_rsync "$acf" "${STEAMDECK_SSH}:${STEAMDECK_STEAMAPPS}/"
  else
    echo "note: no matching appmanifest_*.acf found — on Deck tap Install to verify files" >&2
  fi
  echo "done — on Deck: Library → Install (verifies existing files)"
}

deckpullgame() {
  local game=${1:?usage: deckpullgame GAME_FOLDER_NAME [LOCAL_DIR]}
  local dst=${2:-./}
  deckping || return 1
  _deck_rsync "${STEAMDECK_SSH}:${STEAMDECK_COMMON}/$game/" "$dst/$game/"
  _deck_rsync "${STEAMDECK_SSH}:${STEAMDECK_STEAMAPPS}/appmanifest_"*.acf "$dst/" 2>/dev/null || true
}

deckpullsaves() {
  local dst=${1:-$HOME/Backups/steamdeck-saves}
  deckping || return 1
  mkdir -p "$dst"
  _deck_rsync "${STEAMDECK_SSH}:${STEAMDECK_USERDATA}/" "$dst/"
  echo "saves → $dst"
}

deckpushsaves() {
  local src=${1:-$HOME/Backups/steamdeck-saves}
  deckping || return 1
  [[ -d $src ]] || { echo "missing: $src" >&2; return 1; }
  _deck_rsync "$src/" "${STEAMDECK_SSH}:${STEAMDECK_USERDATA}/"
}

deckscreenshots() {
  local dst=${1:-$HOME/Pictures/steamdeck-screenshots}
  deckping || return 1
  mkdir -p "$dst"
  _deck_rsync "${STEAMDECK_SSH}:${STEAMDECK_USERDATA}/" "$dst/" \
    --include='*/760/remote/' --include='*/760/remote/*/' --include='*/760/remote/*/*/screenshots/' \
    --include='*/760/remote/*/*/screenshots/**' --exclude='*'
  echo "screenshots → $dst"
}

deckmods() {
  local sub=${1:-}
  deckping || return 1
  if [[ -n $sub ]]; then
    _deck_ssh "find ${STEAMDECK_COMMON} -maxdepth 3 -type d -iname '*mod*' 2>/dev/null | head -40"
  else
    _deck_ssh "find ${STEAMDECK_COMMON} -maxdepth 2 -type d \\( -iname '*mod*' -o -iname 'workshop' \\) 2>/dev/null | head -40"
  fi
}

deckrestartsteam() {
  deckping || return 1
  _deck_ssh 'pkill -x steam || true; nohup steam >/dev/null 2>&1 &'
  echo "steam restart requested on Deck"
}

deckagent() {
  deckping || return 1
  _deck_ssh -t "export PATH=\"\$HOME/.local/bin:\$HOME/.grok/bin:\$PATH\"; agent \"\$@\""
}

deckgrok() {
  deckping || return 1
  _deck_ssh -t "export PATH=\"\$HOME/.grok/bin:\$HOME/.local/bin:\$PATH\"; grok \"\$@\""
}

deckcat() {
  local path=${1:?usage: deckcat REMOTE_FILE}
  deckping || return 1
  _deck_ssh "cat $(printf '%q' "$path")"
}

deckaudit() {
  deckping || return 1
  _deck_ssh 'bash ~/.config/steamdeck/audit.sh'
}

deckbootstrap() {
  deckping || return 1
  _deck_ssh "bash ~/.config/steamdeck/bootstrap.sh $*"
}

deckbox() {
  deckping || return 1
  _deck_ssh -t 'deckbox'
}

deckboxai() {
  deckping || return 1
  _deck_ssh -t 'export PATH="/usr/bin:/bin:$HOME/.local/bin:$PATH"; distrobox enter ai-box'
}

deckai() {
  deckping || return 1
  _deck_ssh 'bash ~/.config/steamdeck/ai-status.sh'
}

deckgamefocus() {
  deckping || return 1
  _deck_ssh 'bash ~/.config/steamdeck/game-focus.sh'
}

deckaifocus() {
  deckping || return 1
  _deck_ssh 'bash ~/.config/steamdeck/ai-focus.sh'
}

deckwebui() {
  deckping || return 1
  local sub=${1:-status}
  case "${sub}" in
    start|stop|restart)
      _deck_ssh "systemctl --user ${sub} open-webui.service && systemctl --user --no-pager -l status open-webui.service | head -16"
      ;;
    logs|log)
      shift
      _deck_ssh "journalctl --user -u open-webui.service -n ${1:-80} --no-pager"
      ;;
    *)
      echo "Open WebUI  http://127.0.0.1:3000  (Deck localhost; SSH tunnel if remote)"
      _deck_ssh 'bash ~/.config/steamdeck/ai-status.sh'
      ;;
  esac
}

deckollama() {
  deckping || return 1
  local sub=${1:-status}
  case "${sub}" in
    status|'')
      _deck_ssh 'bash ~/.config/steamdeck/ai-status.sh; echo; systemctl --user --no-pager -l status ollama.service | head -24'
      ;;
    logs|log)
      shift
      _deck_ssh "journalctl --user -u ollama.service -n ${1:-80} --no-pager"
      ;;
    start|stop|restart)
      _deck_ssh "systemctl --user ${sub} ollama.service && systemctl --user --no-pager -l status ollama.service | head -16"
      ;;
    *)
      _deck_ssh "export PATH=\"/usr/bin:/bin:\$HOME/.local/bin:\$PATH\"; ollama $(printf '%q ' "$@")"
      ;;
  esac
}

deckhelp() { deck help; }

# Short aliases
alias dsh='decksh'
alias dgames='deckgames'
alias dpush='deckpush'
alias dpull='deckpull'
alias dping='deckping'
alias dhelp='deck'
