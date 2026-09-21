variable "lab_vm_name" {
  description = "Name of the containerlab VM"
  type        = string
  default     = "netautoai-lab"
}

variable "lab_vm_id" {
  description = "Proxmox VM ID for the containerlab VM"
  type        = number
  default     = 9101
}

variable "lab_vm_cores" {
  description = "Number of CPU cores for the lab VM"
  type        = number
  default     = 4
  validation {
    condition     = var.lab_vm_cores >= 1 && var.lab_vm_cores <= 32
    error_message = "lab_vm_cores must be between 1 and 32."
  }
}

variable "lab_vm_memory" {
  description = "Memory in MB for the lab VM"
  type        = number
  default     = 8192
  validation {
    condition     = var.lab_vm_memory >= 2048 && var.lab_vm_memory <= 131072
    error_message = "lab_vm_memory must be between 2048 MB and 131072 MB."
  }
}

variable "lab_vm_disk_size" {
  description = "Disk size in GB for the lab VM (IOL images + Docker layers)"
  type        = number
  default     = 40
  validation {
    condition     = var.lab_vm_disk_size >= 20 && var.lab_vm_disk_size <= 500
    error_message = "lab_vm_disk_size must be between 20 GB and 500 GB."
  }
}

variable "lab_vm_ip_address" {
  description = "Static CIDR for the lab VM (e.g. 192.168.3.60/24). DHCP is not allowed: the manager VM routes to this address."
  type        = string
  validation {
    condition     = can(cidrhost(var.lab_vm_ip_address, 0))
    error_message = "lab_vm_ip_address must be a valid CIDR (e.g. 192.168.3.60/24)."
  }
}

variable "lab_vm_ip_gateway" {
  description = "Gateway IP for the lab VM"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.lab_vm_ip_gateway))
    error_message = "lab_vm_ip_gateway must be a valid IPv4 address."
  }
}

module "lab_vm" {
  source = "./modules/proxmox_vm"

  vm_name      = var.lab_vm_name
  vm_id        = var.lab_vm_id
  node_name    = var.proxmox_node
  datastore_id = var.datastore_id

  cores     = var.lab_vm_cores
  memory    = var.lab_vm_memory
  disk_size = var.lab_vm_disk_size

  bridge  = var.network_bridge
  vlan_id = var.vlan_id

  image_file_id = proxmox_virtual_environment_download_file.debian_13_cloud_image.id

  ci_user     = var.ci_user
  ci_password = var.ci_password
  ci_ssh_keys = var.ssh_public_keys
  ip_address  = var.lab_vm_ip_address
  ip_gateway  = var.lab_vm_ip_gateway
  dns_servers = var.dns_servers

  tags = ["terraform", "lab-node", "containerlab"]
}

output "lab_vm_id" {
  description = "Proxmox VM ID of the containerlab VM"
  value       = module.lab_vm.vm_id
}

output "lab_vm_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent, per network interface"
  value       = module.lab_vm.ipv4_addresses
}
