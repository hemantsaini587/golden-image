packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.0.0"
    }
  }
}

variable "region" {}
variable "source_ami" {}
variable "ami_name_prefix" {}
variable "os" {}

# Qualys + Report Storage
variable "qualys_username" { type = string }
variable "qualys_password" { type = string }
variable "report_bucket"   { type = string }
variable "report_prefix"   { type = string }

# Gate
variable "fail_on_severity" {
  type    = string
  default = "HIGH" # CRITICAL/HIGH/NONE
}

source "amazon-ebs" "golden" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.medium"
  ssh_username  = "ec2-user"

  ami_name = "${var.ami_name_prefix}-${var.os}-{{timestamp}}"

  tags = {
    "Name"      = "${var.ami_name_prefix}-${var.os}"
    "ImageType" = "Golden"
    "OS"        = var.os
    "BuiltBy"   = "Jenkins+Packer"
  }
}

build {
  name    = "golden-ami-${var.os}"
  sources = ["source.amazon-ebs.golden"]

  # ----------------------------
  # 1) Install agents & tooling
  # ----------------------------
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh",
      "../../scripts/linux/install_agents.sh"
    ]
  }

  # ------------------------------------
  # 2) Qualys PRE scan + report + upload
  # ------------------------------------
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}"
    ]
    script = "../../scripts/common/qualys_pre_scan_and_upload.sh"
  }

  # --------------------------
  # 3) Patch + CIS harden
  # --------------------------
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/patch_os.sh"
    ]
  }

  # Optional CIS hardening (if needed)
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/linux_cis.yml"
  }

  # -------------------------------------
  # 4) Qualys POST scan + report + upload
  #    + Gate enforcement
  # -------------------------------------
  provisioner "shell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "FAIL_ON_SEVERITY=${var.fail_on_severity}"
    ]
    script = "../../scripts/common/qualys_post_scan_upload_and_gate.sh"
  }

  # --------------------------
  # 5) Final cleanup
  # --------------------------
  provisioner "shell" {
    script = "../../scripts/linux/finalize_cleanup.sh"
  }
}
