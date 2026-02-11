#!/bin/bash
set -euo pipefail
echo "[INFO] Patching OS..."

if command -v dnf >/dev/null 2>&1; then
  sudo dnf update -y || true
elif command -v yum >/dev/null 2>&1; then
  sudo yum update -y || true
elif command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update && sudo apt-get upgrade -y || true
fi

echo "[INFO] Patch completed."
