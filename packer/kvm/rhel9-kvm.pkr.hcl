packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
  }
}

variable "os" { default = "rhel9" }
variable "output_dir" { default = "output/artifacts/kvm" }

source "qemu" "golden" {
  iso_url      = "file:///mnt/isos/rhel9.iso"
  iso_checksum = "none"

  output_directory = "${var.output_dir}/${var.os}"
  disk_image       = true
  format           = "qcow2"
  accelerator      = "kvm"
  headless         = true

  ssh_username = "root"
  ssh_password = "changeme"
  ssh_timeout  = "30m"
}

build {
  sources = ["source.qemu.golden"]

  provisioner "shell" {
    scripts = [
      "../../scripts/linux/partitioning.sh",
      "../../scripts/linux/install_agents.sh",
      "../../scripts/linux/patch_os.sh",
      "../../scripts/linux/finalize_cleanup.sh"
    ]
  }
}
