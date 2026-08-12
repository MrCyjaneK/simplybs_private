#!/usr/bin/env bash
# Idempotent environment bootstrap for simplybs.
# Runs after the repository is checked out. Prepares the Go build/module
# caches and installs Docker (best-effort, "nice to have").
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> go version"
go version

# Warm the Go module and build caches so the normal dev loop (`go run .`)
# and `go test ./...` start fast. Building also validates the toolchain.
echo "==> go mod download"
go mod download

echo "==> go build ./..."
go build ./...

# --- Docker (optional / nice to have) -----------------------------------
# Docker is not required for the normal `go run .` workflow, so a failure
# here must not break environment setup.
install_docker() {
  if command -v dockerd >/dev/null 2>&1 && command -v fuse-overlayfs >/dev/null 2>&1; then
    echo "==> docker + fuse-overlayfs already installed"
    return 0
  fi

  echo "==> installing docker.io + fuse-overlayfs"
  sudo apt-get update -qq
  # --force-confold avoids interactive conffile prompts (e.g. /etc/fuse.conf).
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    -o Dpkg::Options::=--force-confold \
    -o Dpkg::Options::=--force-confdef \
    docker.io fuse-overlayfs iptables uidmap
}

configure_docker() {
  # Use fuse-overlayfs since the VM runs inside an unprivileged container
  # where the default overlay2 driver is unavailable. Bridge networking and
  # host iptables manipulation are disabled because they are not permitted in
  # this sandbox (image pulls and `--network host` still work).
  sudo mkdir -p /etc/docker
  echo '{
  "storage-driver": "fuse-overlayfs",
  "iptables": false,
  "bridge": "none"
}' | sudo tee /etc/docker/daemon.json >/dev/null
}

if install_docker && configure_docker; then
  echo "==> docker installed: $(docker --version)"
  echo "==> to start the daemon: sudo bash -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'"
else
  echo "==> WARNING: docker setup failed; continuing without docker" >&2
fi

echo "==> install complete"
