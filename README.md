# Golden Image Factory (Multi-Platform) — Production Pipeline

## Overview
Golden Image Factory automates the creation of **security-hardened Golden Images** across platforms using a standardized pipeline.

It supports:
- **AWS AMIs** (primary production workflow)
- **On-prem KVM images** (qcow2)
- **VMware images/templates** (VMDK / vSphere template)
- **Windows builds** (via VMware template or ISO-based pipelines)

This repo implements a consistent lifecycle:
1. Pick source image (CIS or non-CIS)
2. Spin up test instance/VM from source image
3. Install required security agents
4. (Optional) Apply CIS hardening
5. Run Qualys scan (pre-hardening)
6. Patch OS + CVEs
7. Run Qualys scan (post-hardening)
8. Generate Golden Image
9. Distribute/publish the Golden Image

---

## Why This Pipeline Is Production-Ready
This solution enforces:
- Standardization across OS flavors and platforms
- CIS hardening automation (Linux via Ansible)
- Vulnerability validation using **Qualys Cloud Agent**
- Pre and post scan reports stored centrally
- Automated security gate enforcement (fail build if Critical/High vulnerabilities exist)
- Audit-friendly reports with build metadata

---

## Supported Platforms

### AWS AMI (Production Workflow)
Builder: `amazon-ebs`  
Output: Golden AMI  
Distribution: Copy/share/encrypt AMI across regions/accounts

### KVM (qcow2)
Builder: `qemu`  
Output: qcow2  
Distribution: Publish to central artifact storage (e.g., NFS/MinIO/Artifactory)

### VMware (vSphere)
Builder: `vsphere-clone` or `vsphere-iso`  
Output: vSphere Template / OVA  
Distribution: Publish into vCenter Golden Image folder/catalog

### Windows ISO / Template
Approach:
- Template-based build preferred for enterprise
- ISO-based automation possible via MDT/SCCM
Distribution: MDT/SCCM share or vCenter template catalog

---

## Repository Structure

golden-image/

- README.md  
- Jenkinsfile.aws.bake  
- Jenkinsfile.aws.share  
- Jenkinsfile.kvm.bake  
- Jenkinsfile.vmware.bake  
- Jenkinsfile.windows.iso.bake  

config/  
  - images.yml  
    - global.yml  

packer/  
- cloud/  
    - rhel9-aws.pkr.hcl  
    - ubuntu2204-aws.pkr.hcl  
    - win2022-aws.pkr.hcl  

kvm/  
  - rhel9-kvm.pkr.hcl  
      - ubuntu2204-kvm.pkr.hcl  

vmware/  
  - rhel9-vmware.pkr.hcl  
  - ubuntu2204-vmware.pkr.hcl  
  - win2022-vmware.pkr.hcl  

scripts/  
  common/  
    - select_image.py  
    - write_manifest.py  
    - upload_reports_s3.sh  

  aws/  
    - extract_ami_id.py  
    - share_ami.py  
    - utils.py  

kvm/  
    - publish_qcow2.sh  

vmware/  
    - publish_template.sh  

windows/  
  - publish_iso.ps1  

linux/  
  - partitioning.sh  
  - install_agents.sh  
  - patch_os.sh  
  - finalize_cleanup.sh  

windows-agent/  
  - install_agents.ps1  
  - patch_os.ps1  

ansible/  
  - playbooks/  
      - linux_base.yml  
      - linux_cis.yml  
      - windows_base.yml  
      - windows_cis.yml  

  roles/  
    - cis_linux/  
        -  defaults/main.yml  
        - vars/main.yml  
        - tasks/  
          - main.yml  
          - section1.yml  
    
    cis_windows/
      tasks/main.yml

qualys/  
  - trigger_scan.py  
  - export_report.py  

output/  
  - artifacts/  
