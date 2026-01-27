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

source "amazon-ebs" "golden" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.large"

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_timeout  = "45m"

  iam_instance_profile = "packer-build-instance-profile"

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

  # Install AWS CLI + tools if needed
  provisioner "powershell" {
    inline = [
      "Write-Host '[INFO] Preparing Windows build environment...'",
      "New-Item -ItemType Directory -Force -Path C:\\Temp | Out-Null"
    ]
  }

  # 1) Install agents (CrowdStrike, Qualys Cloud Agent, etc.)
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows/install_agents.ps1"
    ]
  }

  # 2) Qualys PRE (Host-ID + export CSV + upload)
  provisioner "powershell" {
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
    scripts = [
      "../../scripts/windows-agent/qualys_pre_scan_and_upload.ps1"
    ]
  }

  # 3) Patch OS
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows/patch_os.ps1"
    ]
  }

  # 4) CIS hardening (if you have it) + config baseline
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows/apply_cis.ps1"
    ]
  }

  # 5) Qualys POST + gate
  provisioner "powershell" {
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
    scripts = [
      "../../scripts/windows-agent/qualys_post_scan_upload_and_gate.ps1"
    ]
  }

  # 6) Sysprep
  provisioner "powershell" {
    scripts = [
      "../../scripts/windows/sysprep.ps1"
    ]
  }
}