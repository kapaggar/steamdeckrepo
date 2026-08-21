#!/usr/bin/env bash
# Official kubectl + helm static binaries → ~/.local/bin (shared with Distrobox).
# Ubuntu 24.04 does not ship these packages. Does not touch SteamOS /usr.
set -euo pipefail

H="${HOME}"
BIN="${H}/.local/bin"
mkdir -p "${BIN}"
export PATH="${BIN}:${PATH}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "do not run this as root; run as deck" >&2
  exit 1
fi

echo "== dev CLIs (kubectl / helm → ~/.local/bin) =="

install_kubectl() {
  if [[ -x "${BIN}/kubectl" ]]; then
    echo "kubectl: already $(kubectl version --client --output=yaml 2>/dev/null | awk '/gitVersion:/{print $2; exit}' || echo present)"
    return 0
  fi
  local ver
  ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  echo "kubectl: installing ${ver} …"
  curl -fsSLo "${BIN}/kubectl" "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl"
  chmod 755 "${BIN}/kubectl"
  echo "kubectl: $("${BIN}/kubectl" version --client --output=yaml 2>/dev/null | awk '/gitVersion:/{print $2; exit}')"
}

install_helm() {
  if [[ -x "${BIN}/helm" ]]; then
    echo "helm: already $("${BIN}/helm" version --short 2>/dev/null || echo present)"
    return 0
  fi
  local ver tgz tmp
  ver=$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "${ver}" ]]; then
    echo "helm: skip (could not resolve latest tag)" >&2
    return 1
  fi
  echo "helm: installing ${ver} …"
  tmp=$(mktemp -d)
  tgz="${tmp}/helm.tgz"
  curl -fsSLo "${tgz}" "https://get.helm.sh/helm-${ver}-linux-amd64.tar.gz"
  tar -C "${tmp}" -xzf "${tgz}" linux-amd64/helm
  mv "${tmp}/linux-amd64/helm" "${BIN}/helm"
  chmod 755 "${BIN}/helm"
  rm -rf "${tmp}"
  echo "helm: $("${BIN}/helm" version --short 2>/dev/null || echo installed)"
}

install_kubectl
install_helm || echo "helm: leftover — install later with this script"

echo
echo "These live under \$HOME so Distrobox dev sees them (export PATH=\"\$HOME/.local/bin:\$PATH\")."
echo "SteamOS /usr was not touched."
