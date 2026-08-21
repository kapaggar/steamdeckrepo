#!/usr/bin/env bash
# AI focus (START): bring Ollama back, then Open WebUI.
# Waits until 127.0.0.1:11434 answers before starting WebUI.
set -euo pipefail

export HOME="${HOME:-/home/deck}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

API="http://127.0.0.1:11434/api/tags"
WEBUI="http://127.0.0.1:3000"

echo "AI focus: starting ollama.service (Distrobox ai-box, localhost only)"
systemctl --user start ollama.service

ok=0
for _ in $(seq 1 90); do
  if curl -fsS --max-time 2 "${API}" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 1
done

if [[ "${ok}" -ne 1 ]]; then
  echo "AI focus: Ollama did not answer on 127.0.0.1:11434" >&2
  exit 1
fi
echo "AI focus: Ollama answering on 127.0.0.1:11434"

echo "AI focus: starting open-webui.service"
systemctl --user start open-webui.service

web=0
for _ in $(seq 1 90); do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "${WEBUI}" 2>/dev/null || echo 000)
  if [[ "${code}" == "200" || "${code}" == "302" ]]; then
    web=1
    break
  fi
  sleep 1
done

if [[ "${web}" -eq 1 ]]; then
  echo "AI focus: Open WebUI answering on ${WEBUI}"
else
  echo "AI focus: Open WebUI started but ${WEBUI} not ready yet (unit is up)"
fi

echo "AI focus: stack started"
