import os
import shutil
import subprocess
from pathlib import Path

import decky

DECK_HOME = "/home/deck"
SCRIPT_DIR = Path(DECK_HOME) / ".config" / "steamdeck"
GAME_FOCUS = SCRIPT_DIR / "game-focus.sh"
AI_FOCUS = SCRIPT_DIR / "ai-focus.sh"
DECK_UID = 1000
USER_RUNTIME = f"/run/user/{DECK_UID}"

# Hard safety: never pass these to a shell, and never invoke them as units.
FORBIDDEN_SUBSTRINGS = (
    "pkill steam",
    "killall steam",
    "stop plugin_loader",
    "stop steam",
    "stop sdgyrodsu",
)


def _deck_env() -> dict:
    return {
        "HOME": DECK_HOME,
        "USER": "deck",
        "LOGNAME": "deck",
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/home/deck/.local/bin",
        "XDG_RUNTIME_DIR": USER_RUNTIME,
        "DBUS_SESSION_BUS_ADDRESS": f"unix:path={USER_RUNTIME}/bus",
        "SHELL": "/bin/bash",
        "LANG": os.environ.get("LANG", "C.UTF-8"),
    }


def _as_deck(argv: list[str], timeout: int) -> subprocess.CompletedProcess:
    joined = " ".join(argv).lower()
    for bad in FORBIDDEN_SUBSTRINGS:
        if bad in joined:
            raise RuntimeError(f"refusing forbidden command: {bad}")

    env = _deck_env()
    if os.geteuid() == DECK_UID:
        cmd = argv
    elif shutil.which("runuser"):
        cmd = ["runuser", "-u", "deck", "--"] + argv
    elif shutil.which("sudo"):
        cmd = ["sudo", "-u", "deck", "-H", "--"] + argv
    else:
        cmd = argv

    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
        check=False,
    )


def _http_ok(url: str, timeout: float = 2.0) -> bool:
    try:
        import urllib.request

        with urllib.request.urlopen(url, timeout=timeout) as r:
            return 200 <= r.status < 400
    except Exception:
        return False


class Plugin:
    async def _main(self):
        decky.logger.info("deck-focus loaded")

    async def _unload(self):
        decky.logger.info("deck-focus unloaded")

    async def get_status(self) -> dict:
        ollama = _http_ok("http://127.0.0.1:11434/api/tags")
        webui = _http_ok("http://127.0.0.1:3000")
        return {
            "ollama": ollama,
            "webui": webui,
            "message": f"Ollama {'up' if ollama else 'down'}; WebUI {'up' if webui else 'down'}",
        }

    async def game_focus(self) -> dict:
        return self._run_script(GAME_FOCUS, timeout=60, label="Game focus")

    async def ai_focus(self) -> dict:
        return self._run_script(AI_FOCUS, timeout=180, label="AI focus")

    def _run_script(self, script: Path, timeout: int, label: str) -> dict:
        if not script.is_file():
            msg = f"{label}: missing {script}"
            decky.logger.error(msg)
            return {"ok": False, "message": msg}
        try:
            result = _as_deck(["/bin/bash", str(script)], timeout=timeout)
        except Exception as e:
            msg = f"{label} failed: {e}"
            decky.logger.error(msg)
            return {"ok": False, "message": msg}

        out = ((result.stdout or "") + (result.stderr or "")).strip()
        last = out.splitlines()[-1] if out else label
        ok = result.returncode == 0
        if not ok:
            decky.logger.error(f"{label} rc={result.returncode}: {out}")
        else:
            decky.logger.info(f"{label} ok: {last}")
        return {"ok": ok, "message": last}
