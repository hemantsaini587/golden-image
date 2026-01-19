#!/bin/bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUTDIR="/tmp/qualys"
mkdir -p "${OUTDIR}"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
IP_ADDR="$(hostname -I | awk '{print $1}')"

echo "[INFO] Qualys PRE scan (Host ID based)"
echo "[INFO] Hostname: ${HOSTNAME_FQDN}"
echo "[INFO] IP: ${IP_ADDR}"

python3 qualys/host_lookup.py \
  --dns "${HOSTNAME_FQDN}" \
  --ip "${IP_ADDR}" \
  --timeout-seconds 1200 \
  --poll-seconds 30 \
  --out "${OUTDIR}/host_id.txt"

HOST_ID="$(cat ${OUTDIR}/host_id.txt)"

python3 qualys/vuln_summary.py \
  --host-id "${HOST_ID}" \
  --out "${OUTDIR}/pre_summary.json"

python3 qualys/export_report.py \
  --phase pre \
  --os "${OS_NAME}" \
  --host-id "${HOST_ID}" \
  --outdir "${OUTDIR}"

PRE_REPORT="$(ls -1 ${OUTDIR}/pre-hardening-report-${OS_NAME}-*.pdf | tail -n 1)"

echo "[INFO] Uploading PRE report to S3..."
aws s3 cp "${PRE_REPORT}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/pre/$(basename ${PRE_REPORT})"

echo "[INFO] PRE scan completed."
