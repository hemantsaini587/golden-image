#!/bin/bash
set -euo pipefail

REPORT_FILE="${1}"
S3_BUCKET="${2}"
S3_KEY="${3}"

echo "[INFO] Uploading report ${REPORT_FILE} to s3://${S3_BUCKET}/${S3_KEY}"
aws s3 cp "${REPORT_FILE}" "s3://${S3_BUCKET}/${S3_KEY}"
echo "[INFO] Upload complete"
