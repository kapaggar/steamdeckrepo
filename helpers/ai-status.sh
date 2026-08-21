#!/usr/bin/env bash
# Local AI status (run on the Deck). Used by: deck ai, deck ollama, audit.sh
set -u

H="${HOME}"
API="http://127.0.0.1:11434"
SVC="ollama.service"

_ok() { printf '  ✓ %s\n' "$*"; }
_no() { printf '  · %s\n' "$*"; }

echo "Local AI  $(date '+%Y-%m-%d %H:%M')"
echo "  OLLAMA_HOST=127.0.0.1:11434  (localhost only — not on LAN)"
echo "  warning: local inference competes with running games"
echo

linger=$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || echo unknown)
[[ "${linger}" == yes ]] && _ok "linger=${linger}" || _no "linger=${linger}"

DB="${H}/.local/bin/distrobox"
[[ -x "${DB}" ]] || DB=$(command -v distrobox 2>/dev/null || true)
if [[ -n "${DB}" ]] && "${DB}" list 2>/dev/null | awk '{print $3}' | grep -qx ai-box; then
  _ok "distrobox ai-box"
else
  _no "distrobox ai-box missing"
fi

if systemctl --user is-enabled --quiet "${SVC}" 2>/dev/null; then
  _ok "user unit ${SVC} enabled"
else
  _no "user unit ${SVC} not enabled"
fi
state=$(systemctl --user is-active "${SVC}" 2>/dev/null || echo inactive)
[[ "${state}" == active ]] && _ok "user unit ${SVC} ${state}" || _no "user unit ${SVC} ${state}"

if curl -fsS --max-time 3 "${API}/api/tags" >/dev/null 2>&1; then
  _ok "API ${API}/api/tags"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json, urllib.request
try:
    with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as r:
        data = json.load(r)
    models = data.get("models") or []
    if not models:
        print("  · no models pulled yet")
    for m in models:
        name = m.get("name") or m.get("model") or "?"
        size = m.get("size") or 0
        gb = size / (1024**3) if size else 0
        print(f"  ✓ model {name}  ({gb:.1f} GiB)" if gb else f"  ✓ model {name}")
except Exception as e:
    print(f"  · tags parse: {e}")
PY
  else
    curl -sS --max-time 5 "${API}/api/tags" || true
    echo
  fi
else
  _no "API down  (${API}/api/tags)"
fi

[[ -d "${H}/.ollama" ]] && _ok "~/.ollama (models persist on host \$HOME)" || _no "no ~/.ollama yet"

if [[ -x "${H}/homebrew/services/PluginLoader" ]]; then
  ver=$(cat "${H}/homebrew/services/.loader.version" 2>/dev/null || echo unknown)
  _ok "Decky PluginLoader ${ver}"
else
  _no "Decky PluginLoader missing"
fi
pl=$(systemctl is-active plugin_loader 2>/dev/null || echo inactive)
en=$(systemctl is-enabled plugin_loader 2>/dev/null || echo disabled)
if [[ "${pl}" == active ]]; then
  _ok "plugin_loader.service ${pl} (${en})"
else
  _no "plugin_loader.service ${pl} (${en}) — QAM plug needs a Game Mode restart"
fi
[[ -f "${H}/homebrew/plugins/bonsAI/plugin.json" ]] && _ok "plugin: bonsAI" || _no "plugin missing: bonsAI"
[[ -f "${H}/homebrew/plugins/decky-ollama/plugin.json" ]] && _ok "plugin: decky-ollama (127.0.0.1 + user ollama.service)" \
  || _no "plugin missing: decky-ollama"
[[ -f "${H}/homebrew/plugins/deck-focus/plugin.json" ]] && _ok "plugin: deck-focus (QAM Game/AI focus)" \
  || _no "plugin missing: deck-focus"
[[ -x "${H}/.config/steamdeck/game-focus.sh" ]] && _ok "game-focus.sh" || _no "missing game-focus.sh"
[[ -x "${H}/.config/steamdeck/ai-focus.sh" ]] && _ok "ai-focus.sh" || _no "missing ai-focus.sh"

echo
if [[ -d "${H}/.local/lib/ollama" ]]; then
  _no "host ~/.local/lib/ollama present (bonsAI tarball — remove it; use Distrobox)"
fi
if [[ -x "${H}/.local/bin/ollama" ]] && file -b "${H}/.local/bin/ollama" 2>/dev/null | grep -qi ELF; then
  _no "~/.local/bin/ollama is a host ELF — should be the Distrobox wrapper"
fi
[[ -f "${H}/.config/steamdeck/ollama-managed-by-distrobox" ]] && _ok "Distrobox-managed (skip bonsAI Install Ollama)" \
  || _no "missing ollama-managed-by-distrobox marker"

echo
WEBUI="http://127.0.0.1:3000"
wu=$(systemctl --user is-active open-webui.service 2>/dev/null || echo inactive)
if [[ "${wu}" == active ]]; then
  _ok "open-webui.service ${wu}"
else
  _no "open-webui.service ${wu}"
fi
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "${WEBUI}" 2>/dev/null || echo 000)
if [[ "${code}" == 200 || "${code}" == 302 ]]; then
  _ok "Open WebUI ${WEBUI}  (HTTP ${code})"
else
  _no "Open WebUI ${WEBUI}  (HTTP ${code})"
fi
echo "  Open WebUI  ${WEBUI}"

echo
echo "start/stop:  systemctl --user start|stop|restart ${SVC}"
echo "logs:        journalctl --user -u ${SVC} -f"
echo "CLI:         ollama list | ollama pull qwen2.5:1.5b"
echo "box:         distrobox enter ai-box"
echo "WebUI:       ${WEBUI}  (systemctl --user start|stop open-webui.service)"
echo "Decky:       plugin_loader.service (system). SteamOS updates can drop it — re-run install-decky.sh"
echo "QAM:         restart Game Mode once if the plug icon is missing; enable bonsAI + decky-ollama + Deck Focus"
echo "Focus:       Game Mode → … → Decky → Deck Focus → Game focus / AI focus"
echo "             or: deck game   /   deck ai-on"
echo "Do not use bonsAI Install Ollama — use the Distrobox unit"
