#!/usr/bin/env bash
# Persistent Chrome bookmark + new-tab button for local Open WebUI.
# Lives under $HOME so it survives SteamOS image updates.
# Safe: never writes Bookmarks/Preferences while Flatpak Chrome is running.
set -euo pipefail

H="${HOME}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/chrome-open-webui-newtab"
EXT="${H}/.local/share/steamdeck/chrome-open-webui-newtab"
APP_EXT="${H}/Applications/chrome-extensions/open-webui-newtab"
PROFILE="${H}/.var/app/com.google.Chrome/config/google-chrome/Default"
WEBUI="http://127.0.0.1:3000"
WEBUI_SLASH="${WEBUI}/"
TITLE="Open WebUI"

chrome_is_running() {
  if command -v flatpak >/dev/null 2>&1 && flatpak ps 2>/dev/null | grep -q 'com.google.Chrome'; then
    return 0
  fi
  if pgrep -u "$(id -u)" -f '/app/bin/chrome' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

echo "== Chrome Open WebUI helpers =="
echo "  home=${H}"
echo "  extension=${EXT}"

if [[ ! -f "${SRC}/manifest.json" || ! -f "${SRC}/newtab.html" ]]; then
  echo "missing extension source next to this script: ${SRC}" >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1 || ! flatpak info com.google.Chrome >/dev/null 2>&1; then
  echo "com.google.Chrome Flatpak is not installed; skip" >&2
  exit 1
fi

mkdir -p "${H}/.local/bin" \
  "${H}/.local/share/applications" \
  "${H}/.local/share/steamdeck" \
  "${H}/Applications/chrome-extensions" \
  "${H}/Desktop" \
  "${H}/.config/steamdeck"

# --- unpacked MV3 extension (canonical path + Applications alias) ---
rm -rf "${EXT}"
mkdir -p "${EXT}"
cp -a "${SRC}/." "${EXT}/"
chmod 644 "${EXT}"/*

if [[ -e "${APP_EXT}" && ! -L "${APP_EXT}" ]]; then
  rm -rf "${APP_EXT}"
fi
ln -sfn "${EXT}" "${APP_EXT}"
echo "  extension installed"

# --- CLI wrapper (always passes --load-extension) ---
cat > "${H}/.local/bin/google-chrome" << EOF
#!/usr/bin/env bash
# Flatpak Chrome with the Open WebUI new-tab extension.
set -euo pipefail
EXT="${EXT}"
args=()
for a in "\$@"; do
  case "\$a" in
    @@|@@u) continue ;;
    *) args+=("\$a") ;;
  esac
done
exec /usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome \\
  com.google.Chrome --load-extension="\${EXT}" "\${args[@]}"
EOF
chmod 755 "${H}/.local/bin/google-chrome"
ln -sfn google-chrome "${H}/.local/bin/google-chrome-stable"
echo "  wrapper ~/.local/bin/google-chrome"

# --- xdg-open: keep http(s) on Chrome, now via the wrapper ---
if [[ -f "${H}/.local/bin/xdg-open" ]]; then
  cat > "${H}/.local/bin/xdg-open" << 'EOF'
#!/usr/bin/env bash
# Steam Deck fix: pass http(s) URLs to Chrome (with Open WebUI new-tab extension).
url="${1:-}"
if [[ "$url" =~ ^https?:// ]]; then
  chrome="${HOME}/.local/bin/google-chrome"
  if [[ -x "${chrome}" ]]; then
    nohup "${chrome}" "${url}" >/dev/null 2>&1 &
  else
    nohup flatpak run com.google.Chrome "${url}" >/dev/null 2>&1 &
  fi
  exit 0
fi
exec /usr/bin/xdg-open "$@"
EOF
  chmod 755 "${H}/.local/bin/xdg-open"
  echo "  xdg-open → google-chrome wrapper"
fi

# --- user .desktop (overrides Discover/system export) + Desktop icon ---
DESKTOP_BODY=$(cat << EOF
[Desktop Entry]
Version=1.0
Name=Google Chrome
GenericName=Web Browser
Comment=Access the Internet (Open WebUI new-tab button)
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome --file-forwarding com.google.Chrome --load-extension=${EXT} @@u %U @@
StartupNotify=true
StartupWMClass=google-chrome
Terminal=false
Icon=com.google.Chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;
X-Flatpak=com.google.Chrome

[Desktop Action new-window]
Name=New Window
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome com.google.Chrome --load-extension=${EXT}

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome com.google.Chrome --load-extension=${EXT} --incognito
EOF
)
printf '%s\n' "${DESKTOP_BODY}" > "${H}/.local/share/applications/com.google.Chrome.desktop"
chmod 755 "${H}/.local/share/applications/com.google.Chrome.desktop"

# Replace the official Flatpak symlink on ~/Desktop with OUR launcher.
rm -f "${H}/Desktop/com.google.Chrome.desktop"
cp -f "${H}/.local/share/applications/com.google.Chrome.desktop" \
  "${H}/Desktop/com.google.Chrome.desktop"
chmod 755 "${H}/Desktop/com.google.Chrome.desktop"
echo "  Desktop + app-menu Google Chrome (with --load-extension)"

# App-menu / Desktop one-tap to WebUI itself
cat > "${H}/.local/share/applications/open-webui.desktop" << EOF
[Desktop Entry]
Name=Open WebUI
Comment=Local ChatGPT-like UI (Ollama on 127.0.0.1)
Exec=${H}/.local/bin/google-chrome ${WEBUI}
Terminal=false
Type=Application
Categories=Network;Office;
StartupNotify=false
Icon=com.google.Chrome
EOF
chmod 755 "${H}/.local/share/applications/open-webui.desktop"
cp -f "${H}/.local/share/applications/open-webui.desktop" \
  "${H}/Desktop/Open-WebUI.desktop"
chmod 755 "${H}/Desktop/Open-WebUI.desktop"

# Drag-this-link page + Netscape import (fallback if JSON bookmarks were skipped)
cat > "${H}/Desktop/Open-WebUI-bookmark.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Open WebUI bookmark</title>
  <style>
    html, body { margin: 0; background: #000; color: #e8e8e8; font: 18px/1.4 system-ui, sans-serif; }
    main { min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 1.5rem; text-align: center; }
    a { display: inline-block; margin-top: 1rem; padding: 1.4rem 2rem; border: 2px solid #3dd68c; border-radius: 1rem; color: #f5f5f5; text-decoration: none; font-size: 2rem; font-weight: 700; }
  </style>
</head>
<body>
  <main>
    <p>Open this file <strong>inside Chrome</strong>, then drag the button onto the bookmarks bar.</p>
    <a href="http://127.0.0.1:3000/">Open WebUI</a>
  </main>
</body>
</html>
EOF
if [[ "${HERE}/chrome-open-webui-bookmark.html" != "${H}/.config/steamdeck/chrome-open-webui-bookmark.html" ]]; then
  cp -f "${HERE}/chrome-open-webui-bookmark.html" \
    "${H}/.config/steamdeck/chrome-open-webui-bookmark.html"
fi
cp -f "${HERE}/chrome-open-webui-bookmark.html" \
  "${H}/Desktop/Open-WebUI-bookmarks-import.html"
echo "  fallback HTML on Desktop (drag / import)"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${H}/.local/share/applications" >/dev/null 2>&1 || true
fi

# --- Bookmarks + show-bookmarks-bar only if Chrome is not running ---
apply_profile() {
  python3 - "$@" << 'PY'
import hashlib, json, os, sys, time, uuid
from pathlib import Path

profile = Path(sys.argv[1])
title = sys.argv[2]
url = sys.argv[3]
profile.mkdir(parents=True, exist_ok=True)

def chrome_time():
    return str(int((time.time() + 11644473600) * 1_000_000))

def md5_update_str(md5, s: str) -> None:
    md5.update(s.encode("utf-8"))

def md5_update_u16(md5, s: str) -> None:
    md5.update(s.encode("utf-16le"))

def checksum_node(md5, node: dict) -> None:
    nid = str(node.get("id", ""))
    name = node.get("name", "")
    ntype = node.get("type")
    if ntype == "url":
        md5_update_str(md5, nid)
        md5_update_u16(md5, name)
        md5_update_str(md5, "url")
        md5_update_str(md5, node.get("url", ""))
        return
    md5_update_str(md5, nid)
    md5_update_u16(md5, name)
    md5_update_str(md5, "folder")
    for child in node.get("children") or []:
        checksum_node(md5, child)

def bookmarks_checksum(roots: dict) -> str:
    md5 = hashlib.md5()
    for key in ("bookmark_bar", "other", "synced"):
        if key in roots:
            checksum_node(md5, roots[key])
    return md5.hexdigest()

def empty_folder(nid: str, name: str, guid: str, now: str) -> dict:
    return {
        "children": [],
        "date_added": now,
        "date_last_used": "0",
        "date_modified": now,
        "guid": guid,
        "id": nid,
        "name": name,
        "type": "folder",
    }

def max_id(node: dict) -> int:
    n = int(node.get("id") or 0)
    for child in node.get("children") or []:
        n = max(n, max_id(child))
    return n

def urls_in(node: dict) -> set[str]:
    found: set[str] = set()
    if node.get("type") == "url" and node.get("url"):
        found.add(node["url"].rstrip("/"))
    for child in node.get("children") or []:
        found |= urls_in(child)
    return found

now = chrome_time()
bm_path = profile / "Bookmarks"
if bm_path.exists():
    data = json.loads(bm_path.read_text(encoding="utf-8"))
else:
    data = {
        "checksum": "",
        "roots": {
            "bookmark_bar": empty_folder(
                "1", "Bookmarks bar", "0bc5d13f-2cba-5d74-951f-3f233fe6c675", now
            ),
            "other": empty_folder(
                "2", "Other bookmarks", "82b081ec-3dd3-529c-8475-ab6c344590dd", now
            ),
            "synced": empty_folder(
                "3", "Mobile bookmarks", "4cf2e351-0e26-5143-b314-d4f1760d2b37", now
            ),
        },
        "version": 1,
    }

roots = data.setdefault("roots", {})
bar = roots.setdefault(
    "bookmark_bar",
    empty_folder("1", "Bookmarks bar", "0bc5d13f-2cba-5d74-951f-3f233fe6c675", now),
)
bar.setdefault("children", [])
existing = urls_in(bar)
target = url.rstrip("/")
if target not in existing:
    nid = max(max_id(roots.get("bookmark_bar", {})), max_id(roots.get("other", {})), max_id(roots.get("synced", {})), 3) + 1
    bar["children"].append(
        {
            "date_added": now,
            "date_last_used": "0",
            "guid": str(uuid.uuid4()),
            "id": str(nid),
            "name": title,
            "type": "url",
            "url": url if url.endswith("/") else url + "/",
        }
    )
    bar["date_modified"] = now
    print("bookmarks: added Open WebUI on the bar")
else:
    print("bookmarks: Open WebUI already present")

data["checksum"] = bookmarks_checksum(roots)
data["version"] = 1
payload = json.dumps(data, indent=3, ensure_ascii=True) + "\n"
tmp = bm_path.with_name("Bookmarks.tmp")
tmp.write_text(payload, encoding="utf-8")
os.replace(tmp, bm_path)
os.chmod(bm_path, 0o600)
bak = profile / "Bookmarks.bak"
bak.write_text(payload, encoding="utf-8")
os.chmod(bak, 0o600)

prefs_path = profile / "Preferences"
if prefs_path.exists():
    prefs = json.loads(prefs_path.read_text(encoding="utf-8"))
else:
    prefs = {}
    print("preferences: created new file")

# SuperMAC protects homepage / session.restore_* — do not touch those.
# bookmark_bar.show_on_all_tabs is not in protection.macs on this profile.
prefs.setdefault("bookmark_bar", {})["show_on_all_tabs"] = True
acct = prefs.setdefault("account_values", {})
acct.setdefault("bookmark_bar", {})["show_on_all_tabs"] = True
prefs.setdefault("browser", {})["show_home_button"] = True

backup = profile / "Preferences.steamdeck.bak"
if prefs_path.exists() and not backup.exists():
    backup.write_bytes(prefs_path.read_bytes())

tmp = prefs_path.with_name("Preferences.tmp")
tmp.write_text(json.dumps(prefs, separators=(",", ":"), ensure_ascii=True), encoding="utf-8")
os.replace(tmp, prefs_path)
os.chmod(prefs_path, 0o600)
print("preferences: bookmark_bar.show_on_all_tabs=true")
PY
}

if chrome_is_running; then
  echo
  echo "  Chrome is running — skipped Bookmarks/Preferences (would be overwritten)."
  echo "  Fully quit Chrome, then run:  bash ~/.config/steamdeck/install-chrome-open-webui.sh"
  echo "  Fallback now: Desktop Open-WebUI.desktop, or import Open-WebUI-bookmarks-import.html"
else
  if [[ -d "${H}/.var/app/com.google.Chrome/config/google-chrome" ]]; then
    apply_profile "${PROFILE}" "${TITLE}" "${WEBUI}"
  else
    echo "  no Chrome profile yet — bookmark JSON will wait until first Chrome launch + re-run"
  fi
fi

echo
echo "Done. Fully quit Chrome if it is open, then launch Google Chrome from ~/Desktop"
echo "  New tab = big Open WebUI button"
echo "  Bookmarks bar = Open WebUI  (or drag Desktop/Open-WebUI-bookmark.html from inside Chrome)"
echo "  Official Discover .desktop without --load-extension will not show the new-tab button"
echo "  Do not change Ollama/WebUI binds; WebUI stays http://127.0.0.1:3000"
