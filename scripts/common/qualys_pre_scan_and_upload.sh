#!/bin/bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_NAME="pre-hardening-report-${OS_NAME}-${TS}.pdf"

echo "[INFO] Running Qualys PRE scan workflow..."
echo "[INFO] Report name: ${REPORT_NAME}"

# Trigger scan (placeholder for now - integrate real Qualys API)
python3 qualys/trigger_scan.py \
  --phase pre \
  --os "${OS_NAME}" \
  --artifact /tmp/build_artifact.json \
  --out /tmp/qualys_pre.json

python3 qualys/export_report.py \
  --phase pre \
  --os "${OS_NAME}" \
  --input /tmp/qualys_pre.json \
  --outdir /tmp

# Rename exported report to your required naming convention
mv /tmp/pre-hardening-report-${OS_NAME}-*.pdf "/tmp/${REPORT_NAME}"

# Upload to S3
aws s3 cp "/tmp/${REPORT_NAME}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/pre/${REPORT_NAME}"

echo "[INFO] PRE scan report uploaded successfully."
