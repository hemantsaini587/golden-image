packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.2.0"
    }
  }
}

############################
# Variables
############################
variable "os" {
  type    = string
  default = "rhel9"
}

variable "vcenter_server" { type = string }
variable "vcenter_user"   { type = string }
variable "vcenter_password" {
  type      = string
  sensitive = true
}

variable "datacenter" { type = string }
variable "cluster"    { type = string }
variable "datastore"  { type = string }
variable "network"    { type = string }

variable "folder" {
  type    = string
  default = "GoldenImages"
}

# Base template to clone from
variable "template" {
  type = string
}

# Naming prefix for the final golden VM/template
variable "golden_vm_name_prefix" {
  type    = string
  default = "golden"
}

# Optional: convert the VM into a vCenter template
variable "convert_to_template" {
  type    = bool
  default = true
}

############################
# vSphere Clone Builder
############################
source "vsphere-clone" "golden" {
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_user
  password            = var.vcenter_password
  insecure_connection = true

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = var.folder

  template = var.template

  # Final VM name created by Packer
  vm_name = "${var.golden_vm_name_prefix}-${var.os}"

  network_adapters {
    network = var.network
  }

  # Linux SSH access (ensure base template allows SSH)
  ssh_username = "root"
  ssh_password = "changeme"
  ssh_timeout  = "30m"

  # Keep VM powered on during provisioning
  power_on = true

  # Convert to template after provisioning (best practice for VMware)
  convert_to_template = var.convert_to_template
}

############################
# Build
############################
build {
  name    = "vmware-golden-${var.os}"
  sources = ["source.vsphere-clone.golden"]

  # Partitioning / base prep (optional depending on your template)
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh"
    ]
  }

  # Install security agents
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/install_agents.sh"
    ]
  }

  # Patch OS
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/patch_os.sh"
    ]
  }

  # CIS Hardening (Ansible over SSH)
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/linux_cis.yml"
  }

  # Final cleanup
  provisioner "shell" {
    scripts = [
      "../../scripts/linux/finalize_cleanup.sh"
    ]
  }
}