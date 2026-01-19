#!/bin/bash
set -euo pipefail

OUTDIR="/tmp/qualys"
mkdir -p "${OUTDIR}"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
IP_ADDR="$(hostname -I | awk '{print $1}')"

# Instance metadata (IMDSv2)
TOKEN="$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"

INSTANCE_ID="$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")"

export INSTANCE_ID="${INSTANCE_ID}"
export SOURCE_AMI_ID="${SOURCE_AMI_ID:-unknown}"
export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
export BUILD_URL="${BUILD_URL:-unknown}"

echo "[INFO] Qualys PRE scan (Host ID based)"
echo "[INFO] OS: ${OS_NAME}"
echo "[INFO] Hostname: ${HOSTNAME_FQDN}"
echo "[INFO] IP: ${IP_ADDR}"
echo "[INFO] Instance ID: ${INSTANCE_ID}"

python3 qualys/run_lookup_with_tuning.py \
  --os "${OS_NAME}" \
  --dns "${HOSTNAME_FQDN}" \
  --ip "${IP_ADDR}" \
  --out "${OUTDIR}/host_id.txt"

HOST_ID="$(cat ${OUTDIR}/host_id.txt)"
echo "[INFO] Qualys Host ID: ${HOST_ID}"

python3 qualys/vuln_summary.py \
  --host-id "${HOST_ID}" \
  --out "${OUTDIR}/pre_summary.json"

python3 qualys/export_report.py \
  --phase pre \
  --os "${OS_NAME}" \
  --host-id "${HOST_ID}" \
  --outdir "${OUTDIR}"

PRE_REPORT="$(ls -1 ${OUTDIR}/pre-hardening-report-${OS_NAME}-*.pdf | tail -n 1)"

aws s3 cp "${PRE_REPORT}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/pre/$(basename ${PRE_REPORT})"

echo "[INFO] PRE report uploaded: ${PRE_REPORT}"
