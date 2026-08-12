#!/usr/bin/env bash
# Per-boot startup for simplybs. Starts the Docker daemon (best-effort).
# Docker is optional, so this script always exits 0 to avoid blocking startup.
set -uo pipefail

# Nothing to reconcile if docker was not installed.
if ! command -v dockerd >/dev/null 2>&1; then
  echo "==> dockerd not installed; skipping"
  exit 0
fi

# Already running? (idempotent / restart-safe)
if sudo docker info >/dev/null 2>&1; then
  echo "==> docker daemon already running"
  exit 0
fi

echo "==> starting docker daemon"
sudo rm -f /var/run/docker.pid
# Run the whole pipeline (including the log redirect) as root; otherwise the
# redirect is evaluated by the unprivileged shell and fails on /var/log.
sudo bash -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'

# Wait for the daemon socket to become responsive.
for _ in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    echo "==> docker daemon ready"
    exit 0
  fi
  sleep 1
done

echo "==> WARNING: docker daemon did not become ready in time; see /var/log/dockerd.log" >&2
exit 0
