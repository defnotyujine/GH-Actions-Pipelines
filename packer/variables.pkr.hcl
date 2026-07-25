variable "base_image_url" {
  type        = string
  default     = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
  description = "Official AlmaLinux 9 GenericCloud qcow2 base image."
}

variable "base_image_sha256" {
  type        = string
  default     = "c397eed7023e92c841155831b1f47e26300e5bef0f0256c129322307c897a251"
  description = "sha256 of base_image_url - Packer verifies and caches on this. Update alongside the URL when bumping the base."
}

variable "ssh_public_key" {
  type        = string
  description = "Public key injected into the VM's root account via cloud-init (pair to ssh_private_key_file). Generated per-build by the workflow."
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to the private key Packer/Ansible use to SSH into the VM as root."
}

variable "image_name" {
  type        = string
  default     = "almalinux9-cis-local"
  description = "Output image basename. CI passes almalinux9-cis-<shortsha>-<date>."
}

variable "output_directory" {
  type    = string
  default = "output"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = string
  default = "20G"
}
