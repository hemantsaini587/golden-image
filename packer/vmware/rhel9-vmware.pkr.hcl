packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.0.0"
    }
  }
}

variable "vcenter_server" {}
variable "vcenter_user" {}
variable "vcenter_password" { sensitive = true }

variable "datacenter" {}
variable "cluster" {}
variable "datastore" {}
variable "network" {}
variable "folder" { default = "GoldenImages" }

source "vsphere-clone" "golden" {
  vcenter_server       = var.vcenter_server
  username             = var.vcenter_user
  password             = var.vcenter_password
  insecure_connection  = true

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = var.folder

  template = "RHEL9-Base-Template"

  network_adapters {
    network = var.network
  }

  ssh_username = "root"
  ssh_password = "changeme"
}

build {
  sources = ["source.vsphere-clone.golden"]

  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh",
      "../../scripts/linux/install_agents.sh",
      "../../scripts/linux/patch_os.sh",
      "../../scripts/linux/finalize_cleanup.sh"
    ]
  }
}
