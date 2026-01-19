#!/bin/bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_NAME="post-hardening-report-${OS_NAME}-${TS}.pdf"

echo "[INFO] Running Qualys POST scan workflow..."
echo "[INFO] Report name: ${REPORT_NAME}"

python3 qualys/trigger_scan.py \
  --phase post \
  --os "${OS_NAME}" \
  --artifact /tmp/build_artifact.json \
  --out /tmp/qualys_post.json

python3 qualys/export_report.py \
  --phase post \
  --os "${OS_NAME}" \
  --input /tmp/qualys_post.json \
  --outdir /tmp

mv /tmp/post-hardening-report-${OS_NAME}-*.pdf "/tmp/${REPORT_NAME}"

aws s3 cp "/tmp/${REPORT_NAME}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/post/${REPORT_NAME}"

echo "[INFO] POST scan report uploaded successfully."

# Enforce gate (fail packer build if not compliant)
python3 qualys/evaluate_gate.py \
  --input /tmp/qualys_post.json \
  --fail-on "${FAIL_ON_SEVERITY}"

echo "[INFO] Security gate passed."
