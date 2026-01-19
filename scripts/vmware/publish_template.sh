#!/bin/bash
set -euo pipefail

SRC_VM="${1}"
DEST_FOLDER="${2}"

echo "[INFO] Publishing VMware template..."
echo "[INFO] Move/convert VM '${SRC_VM}' to folder '${DEST_FOLDER}'"

# Placeholder:
# govc vm.markastemplate -vm "${SRC_VM}"
# govc folder.mv -folder "${SRC_VM}" -target "${DEST_FOLDER}"

echo "[INFO] VMware publish complete (placeholder)."
