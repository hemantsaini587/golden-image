#!/bin/bash
set -euo pipefail

# Usage:
#   upload_artifact.sh <file_path> <repo_path>
#
# Example:
#   upload_artifact.sh output/artifacts/kvm/rhel9/disk.qcow2 golden-images/kvm/rhel9/disk-20260119.qcow2

FILE_PATH="${1:-}"
REPO_PATH="${2:-}"

if [ -z "${FILE_PATH}" ] || [ -z "${REPO_PATH}" ]; then
  echo "Usage: $0 <file_path> <repo_path>"
  exit 2
fi

if [ ! -f "${FILE_PATH}" ]; then
  echo "ERROR: file not found: ${FILE_PATH}"
  exit 2
fi

if [ -z "${ARTIFACTORY_URL:-}" ]; then
  echo "ERROR: ARTIFACTORY_URL env var not set"
  exit 2
fi

if [ -z "${ARTIFACTORY_USER:-}" ] || [ -z "${ARTIFACTORY_TOKEN:-}" ]; then
  echo "ERROR: ARTIFACTORY_USER / ARTIFACTORY_TOKEN env vars not set"
  exit 2
fi

TARGET="${ARTIFACTORY_URL%/}/${REPO_PATH}"

echo "[INFO] Uploading to Artifactory..."
echo "[INFO] File: ${FILE_PATH}"
echo "[INFO] Target: ${TARGET}"

curl -sfL \
  -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" \
  -T "${FILE_PATH}" \
  "${TARGET}"

echo "[INFO] Upload successful."