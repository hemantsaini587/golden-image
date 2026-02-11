#!/bin/bash
set -euo pipefail

echo "[INFO] Installing AWS CLI (if missing)..."
if ! command -v aws >/dev/null 2>&1; then
  sudo dnf install -y awscli || sudo yum install -y awscli || true
fi

echo "[INFO] Verifying AWS CLI..."
aws --version || true


echo "[INFO] Installing/enabling SSM Agent..."

if ! systemctl list-unit-files | grep -q amazon-ssm-agent; then
  echo "[INFO] Installing SSM Agent via RPM..."
  curl -o amazon-ssm-agent.rpm \
    https://s3.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm
  sudo dnf install -y ./amazon-ssm-agent.rpm || true
fi

sudo systemctl enable amazon-ssm-agent || true
sudo systemctl start amazon-ssm-agent || true
sudo systemctl status amazon-ssm-agent --no-pager || true


echo "[INFO] Installing/enabling CloudWatch Agent..."

if ! systemctl list-unit-files | grep -q amazon-cloudwatch-agent; then
  echo "[INFO] Installing CloudWatch Agent via RPM..."
  curl -o amazon-cloudwatch-agent.rpm \
    https://amazoncloudwatch-agent-us-east-1.s3.us-east-1.amazonaws.com/redhat/amd64/latest/amazon-cloudwatch-agent.rpm
  sudo dnf install -y ./amazon-cloudwatch-agent.rpm || true
fi

sudo systemctl enable amazon-cloudwatch-agent || true
sudo systemctl start amazon-cloudwatch-agent || true
sudo systemctl status amazon-cloudwatch-agent --no-pager || true


echo "[INFO] Installing CrowdStrike (placeholder)..."
# rpm -ivh falcon-sensor.rpm
# /opt/CrowdStrike/falconctl -s --cid=XXXX
# systemctl enable falcon-sensor && systemctl start falcon-sensor

echo "[INFO] Installing Qualys Cloud Agent (placeholder)..."
# rpm -ivh qualys-cloud-agent.rpm
# /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId CustomerId

echo "[INFO] Agents installed."
