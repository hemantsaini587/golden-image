#!/bin/bash
set -euo pipefail

echo "[INFO] Installing AWS CLI (if missing)..."
command -v aws >/dev/null 2>&1 || (yum install -y awscli || true)

echo "[INFO] Verifying AWS CLI..."
aws --version || true


echo "[INFO] Installing/enabling SSM Agent..."
sudo yum install -y amazon-ssm-agent || true
sudo systemctl enable amazon-ssm-agent || true
sudo systemctl start amazon-ssm-agent || true

echo "[INFO] Installing/enabling CloudWatch Agent..."

sudo yum install -y amazon-cloudwatch-agent || \
sudo dnf install -y amazon-cloudwatch-agent || true
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

