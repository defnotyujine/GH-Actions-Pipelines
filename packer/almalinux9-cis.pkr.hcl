packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

locals {
  user_data = <<-EOF
    #cloud-config
    disable_root: false
    ssh_pwauth: false
    users:
      - name: root
        lock_passwd: false
        ssh_authorized_keys:
          - ${var.ssh_public_key}
  EOF

  meta_data = <<-EOF
    instance-id: ${var.image_name}
    local-hostname: almalinux9-cis
  EOF
}

source "qemu" "almalinux9_cis" {
  iso_url      = var.base_image_url
  iso_checksum = "sha256:${var.base_image_sha256}"
  disk_image   = true
  format       = "qcow2"
  disk_size    = var.disk_size

  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  headless    = true
  cpus        = var.cpus
  memory      = var.memory

  qemuargs = [
    ["-cpu", "host"]
  ]

  net_device     = "virtio-net"
  disk_interface = "virtio"

  cd_label = "cidata"
  cd_content = {
    "user-data" = local.user_data
    "meta-data" = local.meta_data
  }

  communicator         = "ssh"
  ssh_username         = "root"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "15m"

  shutdown_command = "shutdown -P now"
  output_directory = var.output_directory
  vm_name          = "${var.image_name}.qcow2"
}

build {
  name    = "almalinux9-cis"
  sources = ["source.qemu.almalinux9_cis"]
s
  provisioner "ansible" {
    playbook_file = "${path.root}/../playbooks/playbook.yml"
    user          = "root"
    use_proxy     = false
    extra_arguments = [
      "--tags", "level1-server",
      "-e", "@${path.root}/../sysconfig/group_vars/all/rhel9-cis.yml",
      "-e", "@${path.root}/bake-vars.yml",
    ]
  }

  post-processor "manifest" {
    output     = "${var.output_directory}/packer-manifest.json"
    strip_path = true
  }
}
