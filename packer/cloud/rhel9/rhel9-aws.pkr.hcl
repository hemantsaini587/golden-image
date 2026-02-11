packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.0.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

source "amazon-ebs" "golden" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.medium"
  ssh_username  = "ec2-user"

  iam_instance_profile = "packer-build-instance-profile"

  # Safe, AWS-compliant AMI name
  ami_name = format(
    "%s-%s-%s",
    var.ami_name_prefix,
    var.os,
    formatdate("YYYYMMDDhhmmss", timestamp())
  )

  tags = {
    Name      = "${var.ami_name_prefix}-${var.os}"
    ImageType = "Golden"
    OS        = var.os
    BuiltBy   = "Jenkins+Packer"
  }
}

build {
  name    = "golden-ami-${var.os}"
  sources = ["source.amazon-ebs.golden"]

  # 0️⃣ Install Python dependencies
  provisioner "shell" {
    inline = [
      "sudo yum install -y python3 python3-pip curl || true",
      "sudo pip3 install --no-cache-dir requests reportlab pyyaml || true"
    ]
  }

  # 1️⃣ Partition + Agents
  provisioner "shell" {
    scripts = [
      "${path.root}/../../../scripts/linux/partitioning.sh",
      "${path.root}/../../../scripts/linux/install_agents.sh"
    ]
  }

  # 2️⃣ PRE Scan
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "SOURCE_AMI_ID=${var.source_ami}",
      "BUILD_NUMBER=${var.build_number}",
      "BUILD_URL=${var.build_url}"
    ]
    script = "${path.root}/../../../scripts/common/qualys_pre_scan_and_upload.sh"
  }

  # 3️⃣ Patch
  provisioner "shell" {
    script = "${path.root}/../../../scripts/linux/patch_os.sh"
  }

  # 4️⃣ CIS Hardening (Ansible)
  provisioner "ansible" {
    playbook_file = "${path.root}/../../../ansible/playbooks/linux_cis.yml"
    user          = "ec2-user"
  }

  # 5️⃣ POST Scan + Gate
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "SOURCE_AMI_ID=${var.source_ami}",
      "BUILD_NUMBER=${var.build_number}",
      "BUILD_URL=${var.build_url}"
    ]
    script = "${path.root}/../../../scripts/common/qualys_post_scan_upload_and_gate.sh"
  }

  # 6️⃣ SBOM Export
  provisioner "shell" {
    environment_vars = [
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}"
    ]
    script = "${path.root}/../../../scripts/common/export_sbom.sh"
  }

  # 7️⃣ Cleanup
  provisioner "shell" {
    script = "${path.root}/../../../scripts/linux/finalize_cleanup.sh"
  }

  # 8️⃣ Output Manifest
  post-processor "manifest" {
    output     = "output/aws_ami_manifest.json"
    strip_path = true
  }
}

