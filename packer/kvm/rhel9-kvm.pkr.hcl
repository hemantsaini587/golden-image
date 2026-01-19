packer {
  required_plugins {
    qemu = {
      source = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
  }
}

source "qemu" "rhel9" {
  accelerator      = "kvm"
  headless         = true
  output_directory = "output/rhel9-kvm"
  format           = "qcow2"
  disk_size        = "20G"

  # Either use ISO build OR disk_image clone approach
  iso_url      = "/isos/rhel9.iso"
  iso_checksum = "none"

  ssh_username = "root"
  ssh_password = "password"
  ssh_timeout  = "30m"
}

build {
  sources = ["source.qemu.rhel9"]

  provisioner "shell" {
    script = "../../scripts/linux/partitioning.sh"
  }

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
