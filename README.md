# Golden Image Factory (AWS Golden AMI Automation)

## Overview
Golden Image Factory is an automated image build pipeline designed to create **secure, CIS-based Golden AMIs** in AWS.
It uses **Jenkins + Packer + scripted provisioning** to produce standardized, hardened images with security tooling installed and validated via Qualys.

This solution eliminates manual AMI creation, improves compliance consistency, and provides repeatable, auditable golden image builds.

---

## Architecture Summary
**Source Input**
- CIS Base AMI ID (user provides latest approved CIS AMI)

**Pipeline**
- Jenkins triggers build workflow
- Code and scripts are stored in GitHub
- Packer spins a test EC2 instance in `us-east-1`
- Partitioning + agent installation is executed
- Qualys Cloud Agent is used for vulnerability scanning
- Golden AMI is created and stored in AWS

**Distribution**
- Golden AMI is copied to multiple AWS regions
- Encrypted using KMS (optional / recommended)
- Shared to multiple AWS accounts
- Snapshot permissions are shared automatically (mandatory for cross-account use)

---

## Jenkins Jobs

### Job 1: Bake Golden AMI
**Purpose**
- Build Golden AMI from CIS base AMI
- Install security agents (CrowdStrike, SSM, AWS CLI, Qualys)
- Run Qualys scan (optional)

**Inputs**
- `OS` (rhel9/ubuntu2204/win2022)
- `CIS_BASE_AMI_ID` (latest CIS base AMI)
- `AMI_NAME_PREFIX`
- `RUN_QUALYS_SCAN`

**Output**
- AMI ID stored in `output/artifacts/golden_ami.json`

---

### Job 2: Share Golden AMI
**Purpose**
- Copy Golden AMI from `us-east-1` to multiple regions
- Encrypt AMI snapshots using KMS
- Share AMI + Snapshot permissions cross-account

**Inputs**
- `SOURCE_AMI_ID`
- `TARGET_REGIONS` (comma-separated)
- `SHARE_WITH_ACCOUNTS` (comma-separated)
- `ENABLE_ENCRYPTION` (true/false)
- `KMS_KEY_MAP` (region=kmsKeyId mapping)

---

## Repo Structure
golden-image/
Jenkinsfile.bake
Jenkinsfile.share
packer/cloud/
scripts/linux/
scripts/aws/
qualys/
output/artifacts/
