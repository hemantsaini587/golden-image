#!/bin/bash
set -euo pipefail

ARTIFACT_DIR="${1:-}"
if [ -z "${ARTIFACT_DIR}" ]; then
  echo "Usage: publish_qcow2.sh <artifact_dir>"
  exit 2
fi

echo "[INFO] Publishing KVM qcow2 artifacts from: ${ARTIFACT_DIR}"

# Example: publish to NFS/MinIO/Artifactory
# Replace with your standard distribution method.
DEST="/mnt/golden-images/kvm/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${DEST}"

cp -av "${ARTIFACT_DIR}"/* "${DEST}/"

echo "[INFO] Published to: ${DEST}"
