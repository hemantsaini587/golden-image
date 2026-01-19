#!/bin/bash
set -euo pipefail
echo "[INFO] Patching OS..."
if command -v dnf >/dev/null 2>&1; then
  dnf update -y
elif command -v yum >/dev/null 2>&1; then
  yum update -y
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update && apt-get upgrade -y
fi
echo "[INFO] Patch completed."
