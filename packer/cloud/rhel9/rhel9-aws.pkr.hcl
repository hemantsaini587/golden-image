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

# No variable definitions here! They are in variables.pkr.hcl
# Variables
#variable "region"          { type = string }
#variable "source_ami"      { type = string }
#variable "ami_name_prefix" { type = string }
#variable "os"              { type = string }

#variable "qualys_username" { type = string }
#variable "qualys_password" { type = string }
#variable "report_bucket"   { type = string }
#variable "report_prefix"   { type = string }

source "amazon-ebs" "golden" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.medium"
  ssh_username  = "ec2-user"

  iam_instance_profile = "packer-build-instance-profile"

  ami_name = "${var.ami_name_prefix}-${var.os}-{timestamp()}"

  tags = {
    "Name"      = "${var.ami_name_prefix}-${var.os}"
    "ImageType" = "Golden"
    "OS"        = var.os
    "BuiltBy"   = "Jenkins+Packer"
  }
}

# Build steps
build {
  name    = "golden-ami-${var.os}"
  sources = ["source.amazon-ebs.golden"]

  # Ensure python + deps for Qualys PDF export
  provisioner "shell" {
    inline = [
      "sudo yum install -y python3 python3-pip curl || true",
      "sudo pip3 install --no-cache-dir requests reportlab pyyaml || true"
    ]
  }

  # 1) Install agents + partitioning
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh",
      "../../scripts/linux/install_agents.sh"
    ]
  }

  # 2) PRE scan + report + upload
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "SOURCE_AMI_ID=${var.source_ami}",
      "BUILD_NUMBER=${env("BUILD_NUMBER")}",
      "BUILD_URL=${env("BUILD_URL")}"
    ]
    script = "../../scripts/common/qualys_pre_scan_and_upload.sh"
  }

  # 3) Patch + CIS hardening
  provisioner "shell" {
    script = "../../scripts/linux/patch_os.sh"
  }

  # 4) Ansible CIS hardening
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/linux_cis.yml"
  }

  # 5) POST scan + report + upload + gate
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "SOURCE_AMI_ID=${var.source_ami}",
      "BUILD_NUMBER=${coalesce(env("BUILD_NUMBER"), "local")}",
      "BUILD_URL=${coalesce(env("BUILD_URL"), "local")}"

    ]
    script = "../../scripts/common/qualys_post_scan_upload_and_gate.sh"
  }

  # 6) Export SBOM
  provisioner "shell" {
    environment_vars = [
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}"
    ]
    script = "../../scripts/common/export_sbom.sh"
  }

  # 7) Cleanup
  provisioner "shell" {
    script = "../../scripts/linux/finalize_cleanup.sh"
  }

  # 8) AMI Output
  post-processor "manifest" {
    output     = "output/aws_ami_manifest.json"
    strip_path = true
  }
}



