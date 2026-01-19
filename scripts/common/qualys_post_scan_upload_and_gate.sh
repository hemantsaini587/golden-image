#!/bin/bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUTDIR="/tmp/qualys"
mkdir -p "${OUTDIR}"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
IP_ADDR="$(hostname -I | awk '{print $1}')"

echo "[INFO] Qualys POST scan (Host ID based)"
echo "[INFO] Hostname: ${HOSTNAME_FQDN}"
echo "[INFO] IP: ${IP_ADDR}"

# Host ID should exist already; lookup again just in case
python3 qualys/host_lookup.py \
  --dns "${HOSTNAME_FQDN}" \
  --ip "${IP_ADDR}" \
  --timeout-seconds 600 \
  --poll-seconds 20 \
  --out "${OUTDIR}/host_id.txt"

HOST_ID="$(cat ${OUTDIR}/host_id.txt)"

python3 qualys/vuln_summary.py \
  --host-id "${HOST_ID}" \
  --out "${OUTDIR}/post_summary.json"

python3 qualys/export_report.py \
  --phase post \
  --os "${OS_NAME}" \
  --host-id "${HOST_ID}" \
  --outdir "${OUTDIR}"

POST_REPORT="$(ls -1 ${OUTDIR}/post-hardening-report-${OS_NAME}-*.pdf | tail -n 1)"

echo "[INFO] Uploading POST report to S3..."
aws s3 cp "${POST_REPORT}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/post/$(basename ${POST_REPORT})"

echo "[INFO] Enforcing security gate..."
python3 qualys/evaluate_gate.py \
  --summary-json "${OUTDIR}/post_summary.json" \
  --fail-on "${FAIL_ON_SEVERITY}"

echo "[INFO] POST scan completed and gate passed."
