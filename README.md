# Golden Image Factory (Multi-Platform)

## Overview
Golden Image Factory is a standardized automation framework to build **Golden Images** across multiple platforms:

- **AWS AMI** (Cloud)
- **KVM qcow2** (On-prem)
- **VMware Templates / VMDK / OVA** (On-prem)
- **Windows ISO distribution** (MDT/SCCM workflow)

The framework ensures consistent:
- Security agent installation (CrowdStrike, Qualys, SSM, AWS CLI, etc.)
- CIS hardening (Ansible / PowerShell)
- OS patching (yum/dnf/apt or Windows updates)
- Qualys vulnerability scanning (Cloud Agent)
- Centralized report storage (S3/MinIO)
- Controlled distribution/publishing per platform

---

## Common Pipeline Stages (All Platforms)
1. Pick source image from central storage (Artifactory/NFS/S3)
2. Spin up test VM/server (Packer)
3. Apply custom partitioning
4. Install security agents
5. CIS hardening (if needed)
6. Qualys scan + report generation
7. Patch OS (CVE patching)
8. Qualys post scan + report generation
9. Create Golden Image
10. Distribute/publish Golden Image

---

## Platform-Specific Pipelines

### AWS (AMI)
**Bake**
- Jenkinsfile: `Jenkinsfile.aws.bake`
- Packer Builder: `amazon-ebs`
- Output: Golden AMI in `us-east-1`

**Share**
- Jenkinsfile: `Jenkinsfile.aws.share`
- Features:
  - Cross-region AMI copy
  - Optional KMS encryption
  - Cross-account sharing
  - Snapshot permission sharing (mandatory)

---

### KVM (qcow2)
- Jenkinsfile: `Jenkinsfile.kvm.bake`
- Packer Builder: `qemu`
- Output: qcow2 published to central KVM image repository

---

### VMware (Templates / OVA)
- Jenkinsfile: `Jenkinsfile.vmware.bake`
- Packer Builder: `vsphere-clone` or `vsphere-iso`
- Output: Published into vCenter Golden Template folder

---

### Windows ISO (MDT/SCCM)
- Jenkinsfile: `Jenkinsfile.windows.iso.bake`
- Output: ISO copied to MDT/SCCM share
- Note: ISO build customization requires separate tooling and is treated as a publishing workflow here.

---

## Requirements

### Jenkins Build Agent
- packer
- python3
- awscli
- Ansible (Linux flows)
- PowerShell (Windows flows)
- boto3 (Python)
- pyyaml (Python)

### Credentials
- AWS credentials (Bake/Share)
- vCenter credentials (VMware pipeline)
- Qualys API credentials (scan/report export)
- Artifactory credentials (if source images stored in JFrog)

---

## Notes
- Qualys scripts are skeleton placeholders and should be replaced with real API calls.
- Snapshot permissions are mandatory for cross-account AMI usage.
- KMS encryption is strongly recommended for golden image distribution.

---


golden-image/

README.md
Jenkinsfile.aws.bake
Jenkinsfile.aws.share
Jenkinsfile.kvm.bake
Jenkinsfile.vmware.bake
Jenkinsfile.windows.iso.bake

config/
  images.yml
    global.yml

packer/
cloud/
  rhel9-aws.pkr.hcl
  ubuntu2204-aws.pkr.hcl
  win2022-aws.pkr.hcl

kvm/
  rhel9-kvm.pkr.hcl
    ubuntu2204-kvm.pkr.hcl

vmware/
  rhel9-vmware.pkr.hcl
  ubuntu2204-vmware.pkr.hcl
  win2022-vmware.pkr.hcl

scripts/
  common/
    select_image.py
    write_manifest.py
    upload_reports_s3.sh

  aws/
    extract_ami_id.py
    share_ami.py
    utils.py

kvm/
    publish_qcow2.sh

vmware/
    publish_template.sh

windows/
  publish_iso.ps1

linux/
  partitioning.sh
  install_agents.sh
  patch_os.sh
  finalize_cleanup.sh

windows-agent/
  install_agents.ps1
  patch_os.ps1

ansible/
  playbooks/
    linux_base.yml
    linux_cis.yml
    windows_base.yml
    windows_cis.yml

  roles/
    cis_linux/
      defaults/main.yml
      vars/main.yml
      tasks/
        main.yml
        section1.yml
    
    cis_windows/
      tasks/main.yml

qualys/
  trigger_scan.py
  export_report.py

output/
  artifacts/
