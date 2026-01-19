#!/bin/bash
set -euo pipefail

OS_NAME="${OS_NAME:-unknown}"
OUTDIR="/tmp/sbom"
mkdir -p "${OUTDIR}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SBOM_FILE="sbom-${OS_NAME}-${TS}.json"

echo "[INFO] Generating SBOM using syft..."
syft packages dir:/ -o json > "${OUTDIR}/${SBOM_FILE}"

echo "[INFO] Uploading SBOM to S3..."
aws s3 cp "${OUTDIR}/${SBOM_FILE}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/sbom/${SBOM_FILE}"

echo "[INFO] SBOM uploaded: ${SBOM_FILE}"
