#!/usr/bin/env bash
# Install Protontricks as a user Flatpak (survives SteamOS /usr image updates).
# Optionally apply winetricks verbs to an official Steam Proton prefix.
# Never copies a Windows game dump, never runs setup.exe from a Mac folder.
set -euo pipefail

FLATPAK_ID="com.github.Matoking.protontricks"
DEFAULT_APPID="1243830"   # Overcooked! All You Can Eat (Steam)
DEFAULT_VERBS="vcrun2019"
APPLY=0
APPID="${DEFAULT_APPID}"
VERBS="${DEFAULT_VERBS}"

H="${HOME}"
STEAMAPPS="${H}/.steam/steam/steamapps"

usage() {
  cat <<EOF
Usage: bash ~/.config/steamdeck/install-protontricks.sh [--apply [APPID]] [--verbs "vcrun2019"]

  (no flags)     install user Flatpak + ~/.local/bin wrappers
  --apply        apply verbs to a Steam Proton prefix if that app is installed
  --verbs LIST   winetricks verbs for --apply (default: ${DEFAULT_VERBS})

Default APPID ${DEFAULT_APPID} is Overcooked! All You Can Eat.

Do not copy a Windows _CommonRedist / setup.exe onto the Deck.
Install the game from Steam first, launch it once (creates compatdata), then --apply.

Typical later commands (non-interactive):

  protontricks -q ${DEFAULT_APPID} vcrun2019
  protontricks -c "winetricks -q vcrun2019" ${DEFAULT_APPID}

Pick vcrun2019 *or* vcrun2022, not both. Skip DirectX web setup (Proton/DXVK).
Optional if a title actually needs them: vcrun2010, openal, dotnet40, xna40.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --apply)
      APPLY=1
      if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        APPID="$2"
        shift
      fi
      ;;
    --verbs)
      VERBS="${2:?--verbs needs a verb list}"
      shift
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

protontricks_bin() {
  if [[ -x "${H}/.local/bin/protontricks" ]]; then
    "${H}/.local/bin/protontricks" "$@"
  else
    flatpak run --user "${FLATPAK_ID}" "$@"
  fi
}

echo "== Protontricks (user Flatpak) =="
echo "  home=${H}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "do not run this as root; run as deck" >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak not found (stock SteamOS should have it)" >&2
  exit 1
fi

if flatpak --user info "${FLATPAK_ID}" >/dev/null 2>&1; then
  echo "already installed: $(flatpak --user info "${FLATPAK_ID}" 2>/dev/null | awk -F': *' '/^[[:space:]]*Version:/{print $2; exit}')"
else
  echo "installing ${FLATPAK_ID} from Flathub (user) …"
  flatpak install --user -y flathub "${FLATPAK_ID}"
fi

mkdir -p "${H}/.local/bin"

cat > "${H}/.local/bin/protontricks" <<EOF
#!/usr/bin/env bash
exec flatpak run --user ${FLATPAK_ID} "\$@"
EOF
cat > "${H}/.local/bin/protontricks-launch" <<EOF
#!/usr/bin/env bash
exec flatpak run --user --command=protontricks-launch ${FLATPAK_ID} "\$@"
EOF
chmod +x "${H}/.local/bin/protontricks" "${H}/.local/bin/protontricks-launch"
echo "wrappers: ~/.local/bin/protontricks  ~/.local/bin/protontricks-launch"
echo "version: $(protontricks_bin --version 2>/dev/null || echo unknown)"

prefix="${STEAMAPPS}/compatdata/${APPID}"
manifest="${STEAMAPPS}/appmanifest_${APPID}.acf"

if [[ "${APPLY}" -eq 1 ]]; then
  if [[ ! -f "${manifest}" || ! -d "${prefix}" ]]; then
    echo
    echo "Steam app ${APPID} is not installed (no appmanifest / no compatdata prefix)."
    echo "Install it from Steam, launch once, then re-run:"
    echo "  bash ~/.config/steamdeck/install-protontricks.sh --apply ${APPID}"
    echo "or:"
    echo "  protontricks -q ${APPID} ${VERBS}"
    exit 2
  fi
  echo
  echo "applying to prefix ${prefix}: ${VERBS}"
  # -q = winetricks quiet (no zenity). Can take several minutes.
  # shellcheck disable=SC2086
  protontricks_bin -q "${APPID}" ${VERBS}
  echo "done"
  exit 0
fi

echo
if [[ -f "${manifest}" && -d "${prefix}" ]]; then
  echo "Steam app ${APPID} looks installed. To apply ${DEFAULT_VERBS}:"
  echo "  bash ~/.config/steamdeck/install-protontricks.sh --apply ${APPID}"
else
  echo "Steam app ${APPID} is not installed on this Deck (expected until you buy/install it)."
fi
echo
usage
