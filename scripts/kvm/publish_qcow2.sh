#!/bin/bash
set -euo pipefail

QCOW2="${1}"
DEST_DIR="${2}"

echo "[INFO] Publishing qcow2 image..."
mkdir -p "${DEST_DIR}"
cp -v "${QCOW2}" "${DEST_DIR}"
echo "[INFO] Published to ${DEST_DIR}"
