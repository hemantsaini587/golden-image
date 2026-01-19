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

echo "[INFO] Qualys POST scan (Host ID based)"
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
  --out "${OUTDIR}/post_summary.json"

python3 qualys/export_report.py \
  --phase post \
  --os "${OS_NAME}" \
  --host-id "${HOST_ID}" \
  --outdir "${OUTDIR}"

POST_REPORT="$(ls -1 ${OUTDIR}/post-hardening-report-${OS_NAME}-*.pdf | tail -n 1)"

aws s3 cp "${POST_REPORT}" "s3://${REPORT_BUCKET}/${REPORT_PREFIX}/${OS_NAME}/post/$(basename ${POST_REPORT})"

GATE_MODE="$(python3 qualys/get_gate_mode.py --os "${OS_NAME}")"
echo "[INFO] Gate mode (from tuning): ${GATE_MODE}"

python3 qualys/evaluate_gate.py \
  --summary-json "${OUTDIR}/post_summary.json" \
  --fail-on "${GATE_MODE}"

echo "[INFO] POST report uploaded and gate passed: ${POST_REPORT}"
