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
    Environment = "POC"
  }
}

build {
  name    = "golden-ami-${var.os}"
  sources = ["source.amazon-ebs.golden"]

  # Python dependencies (keep for future)
  provisioner "shell" {
    inline = [
      "sudo dnf install -y python3 python3-pip curl || sudo yum install -y python3 python3-pip curl || true",
      "sudo pip3 install --no-cache-dir requests reportlab pyyaml || true"
    ]
  }

  # Partition + Agents
  provisioner "shell" {
    scripts = [
      "${path.root}/../../../scripts/linux/partitioning.sh",
      "${path.root}/../../../scripts/linux/install_agents.sh"
    ]
  }

  # PRE Scan (DISABLED FOR POC)
  # provisioner "shell" {
  #   environment_vars = [...]
  #   script = "${path.root}/../../../scripts/common/qualys_pre_scan_and_upload.sh"
  # }

  # Patch
  provisioner "shell" {
    script = "${path.root}/../../../scripts/linux/patch_os.sh"
  }

  # CIS Hardening (DISABLED FOR POC)
  # provisioner "ansible" {
  #   playbook_file = "${path.root}/../../../ansible/playbooks/linux_cis.yml"
  #   user          = "ec2-user"
  # }

  # POST Scan + Gate (DISABLED FOR POC)
  # provisioner "shell" {
  #   environment_vars = [...]
  #   script = "${path.root}/../../../scripts/common/qualys_post_scan_upload_and_gate.sh"
  # }

  # SBOM Export (DISABLED FOR POC)
  # provisioner "shell" {
  #   script = "${path.root}/../../../scripts/common/export_sbom.sh"
  # }

  # Cleanup
  # provisioner "shell" {
  #   script = "${path.root}/../../../scripts/linux/finalize_cleanup.sh"
  # }

  post-processor "manifest" {
    output     = "output/aws_ami_manifest.json"
    strip_path = true
  }
}
