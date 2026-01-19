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
  instance_type = "t3.large"

  communicator = "winrm"
  winrm_username = "Administrator"
  winrm_timeout  = "30m"

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

  # Install tools + agents
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows-agent/install_agents.ps1"
    ]
  }

  # Qualys PRE scan/report/upload
  provisioner "powershell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}"
    ]
    script = "../../scripts/windows-agent/qualys_pre_scan_and_upload.ps1"
  }

  # Patch OS
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows-agent/patch_os.ps1"
    ]
  }

  # CIS Hardening (optional) — you can run Ansible via WinRM, or do it via PowerShell/GPO baselines
  provisioner "powershell" {
    inline = [
      "Write-Host '[INFO] CIS hardening placeholder for Windows (implement via GPO/DSC/PowerShell)'"
    ]
  }

  # Qualys POST scan/report/upload + Gate
  provisioner "powershell" {
    environment_vars = [
      "QUALYS_USERNAME=${var.qualys_username}",
      "QUALYS_PASSWORD=${var.qualys_password}",
      "REPORT_BUCKET=${var.report_bucket}",
      "REPORT_PREFIX=${var.report_prefix}",
      "OS_NAME=${var.os}",
      "FAIL_ON_SEVERITY=${var.fail_on_severity}"
    ]
    script = "../../scripts/windows-agent/qualys_post_scan_upload_and_gate.ps1"
  }

  # Finalize + Sysprep
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows/apply_cis.ps1",
      "../../scripts/windows/sysprep.ps1"
    ]
  }
}
