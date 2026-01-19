packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.0.0"
    }
  }
}

variable "vcenter_server" {}
variable "vsphere_user" {}
variable "vsphere_password" {}
variable "source_template" {}

source "vsphere-clone" "rhel9" {
  vcenter_server      = var.vcenter_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  template  = var.source_template
  vm_name   = "rhel9-build-{{timestamp}}"
  folder    = "ImageFactory"
  cluster   = "BUILD"
  datastore = "BUILD_DS"
}

build {
  sources = ["source.vsphere-clone.rhel9"]

  provisioner "shell" {
    script = "../../scripts/linux/install_agents.sh"
  }

  provisioner "shell" {
    script = "../../scripts/linux/patch_os.sh"
  }

  provisioner "shell" {
    script = "../../scripts/linux/finalize_cleanup.sh"
  }
}
