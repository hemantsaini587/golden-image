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

variable "qualys_username" { type = string }
variable "qualys_password" { type = string }
variable "report_bucket"   { type = string }
variable "report_prefix"   { type = string }

variable "fail_on_severity" {
  type    = string
  default = "HIGH"
}

source "amazon-ebs" "golden" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.medium"
  ssh_username  = "ubuntu"

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

  # Install tooling + agents
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y python3 python3-pip curl unzip",
      "sudo apt-get install -y awscli || true"
    ]
  }

  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh",
      "../../scripts/linux/install_agents.sh"
    ]
  }

  # Qualys PRE
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

  # Patch
  provisioner "shell" {
    script = "../../scripts/linux/patch_os.sh"
  }

  # CIS Hardening (Ansible)
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/linux_cis.yml"
  }

  # Qualys POST + Gate
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

  # Cleanup
  provisioner "shell" {
    script = "../../scripts/linux/finalize_cleanup.sh"
  }
}
