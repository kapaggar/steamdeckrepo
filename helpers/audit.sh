#!/usr/bin/env bash
# Audit $HOME-first Steam Deck setup (update-surviving architecture).
set -euo pipefail

H="${HOME}"
ok=0 warn=0

_pass() { echo "  ✓ $*"; ok=$((ok + 1)); }
_warn() { echo "  ! $*"; warn=$((warn + 1)); }
_fail() { echo "  ✗ $*"; warn=$((warn + 1)); }

_check_dir() {
  [[ -d "$1" ]] && _pass "$1" || _fail "missing $1"
}

_check_exec() {
  local name=$1 path=$2
  if [[ -x "$path" ]]; then
    _pass "$name (${path})"
  elif command -v "$name" >/dev/null 2>&1; then
    _pass "$name (PATH)"
  else
    _fail "$name (expected ${path})"
  fi
}

echo "Steam Deck audit  $(date '+%Y-%m-%d %H:%M')"
echo "host=$(hostname 2>/dev/null || echo deck)  user=${USER}  home=${H}"
echo

echo "── Directories (/usr disposable, \$HOME persistent) ──"
_check_dir "${H}/.local/bin"
_check_dir "${H}/.config/systemd/user"
_check_dir "${H}/.config/containers/systemd"
_check_dir "${H}/.config/steamdeck"
_check_dir "${H}/containers"
_check_dir "${H}/Applications"

echo
echo "── User CLIs (~/.local/bin, ~/.grok/bin) ──"
_check_exec grok "${H}/.grok/bin/grok"
_check_exec agent "${H}/.local/bin/agent"
_check_exec cursor "${H}/.local/bin/cursor"
_check_exec xdg-open "${H}/.local/bin/xdg-open"
_check_exec emudeck "${H}/.local/bin/emudeck"
if [[ -x "${H}/.local/bin/distrobox" ]]; then
  _pass "distrobox (~/.local)"
elif command -v distrobox >/dev/null; then
  _warn "distrobox (system /usr only — run: deck bootstrap)"
else
  _fail "distrobox"
fi

echo
echo "── AppImages (~/Applications) ──"
for app in cursor/EmuDeck.AppImage; do
  [[ -e "${H}/Applications/${app}" ]] && _pass "Applications/${app}" || true
done
count=$(find "${H}/Applications" -maxdepth 1 -name '*.AppImage' 2>/dev/null | wc -l | tr -d ' ')
echo "  … ${count} AppImage(s) under ~/Applications"

echo
echo "── Containers & systemd user ──"
if command -v podman >/dev/null; then
  _pass "podman $(podman --version 2>/dev/null | awk '{print $3}')"
  sock=$(systemctl --user is-active podman.socket 2>/dev/null || echo inactive)
  [[ "${sock}" == active ]] && _pass "podman.socket active" || _warn "podman.socket ${sock} (run: deck bootstrap)"
else
  _fail "podman"
fi

linger=$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || echo unknown)
[[ "${linger}" == "yes" ]] && _pass "linger enabled" || _warn "linger=${linger} (optional: sudo loginctl enable-linger ${USER})"

DB="${H}/.local/bin/distrobox"
[[ -x "${DB}" ]] || DB=$(command -v distrobox 2>/dev/null || true)
if [[ -n "${DB}" ]]; then
  if "${DB}" list 2>/dev/null | grep -q arch-tools; then
    _pass "distrobox container arch-tools"
  else
    _warn "no arch-tools container (deck bootstrap --with-container)"
  fi
  if "${DB}" list 2>/dev/null | awk '{print $3}' | grep -qx ai-box; then
    _pass "distrobox container ai-box"
  else
    _warn "no ai-box container (local AI)"
  fi
fi

quadlets=$(find "${H}/.config/containers/systemd" -name '*.container' ! -name 'example.container' 2>/dev/null | wc -l | tr -d ' ')
[[ "${quadlets}" -gt 0 ]] && _pass "${quadlets} active quadlet(s)" || _warn "no custom quadlets (see ~/.config/containers/systemd/example.container)"

usvc=$(systemctl --user list-unit-files --type=service --state=enabled 2>/dev/null | wc -l | tr -d ' ')
echo "  … ${usvc} enabled user systemd units"

echo
echo "── Local AI (Ollama, localhost only) ──"
if systemctl --user is-enabled --quiet ollama.service 2>/dev/null; then
  _pass "ollama.service enabled"
else
  _warn "ollama.service not enabled"
fi
if systemctl --user is-active --quiet ollama.service 2>/dev/null; then
  _pass "ollama.service active"
else
  _warn "ollama.service $(systemctl --user is-active ollama.service 2>/dev/null || echo inactive)"
fi
if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  _pass "API http://127.0.0.1:11434/api/tags"
else
  _warn "Ollama API not answering on 127.0.0.1:11434"
fi
[[ -d "${H}/.ollama" ]] && _pass "~/.ollama" || _warn "no ~/.ollama (created on first serve)"
[[ -x "${H}/.local/bin/ollama" ]] && _pass "ollama wrapper (~/.local/bin)" || _warn "no ~/.local/bin/ollama wrapper"
if [[ -x "${H}/.local/bin/ollama" ]] && file -b "${H}/.local/bin/ollama" 2>/dev/null | grep -qi ELF; then
  _warn "~/.local/bin/ollama is a host ELF (bonsAI tarball) — should be Distrobox wrapper"
fi
if [[ -d "${H}/.local/lib/ollama" ]]; then
  _warn "host ~/.local/lib/ollama present (bonsAI tarball — conflicts with ai-box)"
else
  _pass "no host ~/.local/lib/ollama tarball"
fi
if [[ -f "${H}/.config/steamdeck/ollama-managed-by-distrobox" ]]; then
  _pass "marker: Distrobox-managed Ollama (do not use bonsAI Install Ollama)"
else
  _warn "missing ~/.config/steamdeck/ollama-managed-by-distrobox"
fi
if [[ -x "${H}/homebrew/services/PluginLoader" ]]; then
  _pass "Decky PluginLoader $(cat "${H}/homebrew/services/.loader.version" 2>/dev/null || echo present)"
else
  _warn "Decky PluginLoader missing"
fi
if systemctl is-active --quiet plugin_loader 2>/dev/null; then
  _pass "plugin_loader.service active ($(systemctl is-enabled plugin_loader 2>/dev/null || echo unknown))"
else
  _warn "plugin_loader inactive — re-run ~/.config/steamdeck/install-decky.sh; QAM plug needs Game Mode restart"
fi
[[ -f "${H}/homebrew/plugins/bonsAI/plugin.json" ]] && _pass "bonsAI plugin" || _warn "bonsAI missing"
[[ -f "${H}/homebrew/plugins/decky-ollama/plugin.json" ]] && _pass "decky-ollama plugin" \
  || _warn "decky-ollama missing"

# Host /usr must stay SteamOS-owned. Ollama lives in the container.
if [[ -e /usr/local/bin/ollama || -e /usr/bin/ollama ]]; then
  _warn "ollama binary on host /usr (unexpected — should be inside ai-box only)"
else
  _pass "no ollama binary in host /usr"
fi

echo
echo "── Open WebUI (localhost only) ──"
if [[ -f "${H}/.config/containers/systemd/open-webui.container" ]]; then
  _pass "quadlet open-webui.container"
else
  _warn "missing ~/.config/containers/systemd/open-webui.container"
fi
if systemctl --user is-active --quiet open-webui.service 2>/dev/null; then
  _pass "open-webui.service active"
else
  _warn "open-webui.service $(systemctl --user is-active open-webui.service 2>/dev/null || echo inactive)"
fi
webui_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 http://127.0.0.1:3000 2>/dev/null || echo 000)
if [[ "${webui_code}" == 200 || "${webui_code}" == 302 ]]; then
  _pass "Open WebUI http://127.0.0.1:3000 (HTTP ${webui_code})"
else
  _warn "Open WebUI not answering on 127.0.0.1:3000 (HTTP ${webui_code})"
fi
if ss -lnt 2>/dev/null | awk '$4=="127.0.0.1:3000"{found=1} $4=="0.0.0.0:3000"{bad=1} END{exit (found && !bad)?0:1}'; then
  _pass "Open WebUI listen 127.0.0.1:3000 only"
elif ss -lnt 2>/dev/null | grep -q '0.0.0.0:3000'; then
  _warn "Open WebUI listening on 0.0.0.0:3000 (should be 127.0.0.1 only)"
fi
[[ -d "${H}/containers/open-webui" ]] && _pass "~/containers/open-webui persist dir" \
  || _warn "missing ~/containers/open-webui"

echo
echo "── Chrome Open WebUI (new tab + bookmark) ──"
EXT="${H}/.local/share/steamdeck/chrome-open-webui-newtab"
[[ -f "${EXT}/manifest.json" && -f "${EXT}/newtab.html" ]] \
  && _pass "new-tab extension ${EXT}" \
  || _warn "missing Open WebUI new-tab extension (run: bash ~/.config/steamdeck/install-chrome-open-webui.sh)"
[[ -x "${H}/.local/bin/google-chrome" ]] && grep -q -- '--load-extension' "${H}/.local/bin/google-chrome" 2>/dev/null \
  && _pass "google-chrome wrapper --load-extension" \
  || _warn "missing ~/.local/bin/google-chrome wrapper"
if [[ -f "${H}/.local/share/applications/com.google.Chrome.desktop" ]] \
  && grep -q -- '--load-extension' "${H}/.local/share/applications/com.google.Chrome.desktop"; then
  _pass "user Chrome .desktop loads new-tab extension"
else
  _warn "app-menu Chrome .desktop missing --load-extension"
fi
if [[ -f "${H}/Desktop/com.google.Chrome.desktop" ]] \
  && grep -q -- '--load-extension' "${H}/Desktop/com.google.Chrome.desktop"; then
  _pass "Desktop Google Chrome uses our launcher"
else
  _warn "Desktop Chrome is the official Flatpak symlink (no new-tab button)"
fi
if [[ -f "${H}/.var/app/com.google.Chrome/config/google-chrome/Default/Bookmarks" ]] \
  && grep -q '127.0.0.1:3000' "${H}/.var/app/com.google.Chrome/config/google-chrome/Default/Bookmarks"; then
  _pass "Chrome Bookmarks bar has Open WebUI"
else
  _warn "Open WebUI not in Chrome Bookmarks yet (quit Chrome, re-run installer, or import Desktop HTML)"
fi

echo
echo "── Shell helpers ──"
[[ -f "${H}/.config/steamdeck/deck-remote.bashrc" ]] && _pass "deck-remote.bashrc" || _fail "deck-remote.bashrc"
[[ -f "${H}/.config/steamdeck/deck-help.bash" ]] && _pass "deck-help.bash" || _fail "deck-help.bash"
[[ -f "${H}/.config/steamdeck/bootstrap.sh" ]] && _pass "bootstrap.sh" || _fail "bootstrap.sh"
case ":${PATH}:" in
  *":${H}/.local/bin:"*) _pass 'PATH includes ~/.local/bin (login/interactive)' ;;
  *)
    [[ -d "${H}/.local/bin" ]] && _pass '~/.local/bin exists (set in ~/.bashrc for shells)' \
      || _warn 'PATH missing ~/.local/bin'
    ;;
esac

echo
echo "── Summary ──"
echo "  passed=${ok}  warnings=${warn}"
echo "  fix: deck bootstrap   full audit+container: deck bootstrap --with-container"
