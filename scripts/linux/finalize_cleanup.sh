#!/bin/bash
set -euo pipefail
echo "[INFO] Cleanup before imaging..."
rm -rf /tmp/* || true
yum clean all || true
echo "[INFO] Cleanup complete."
