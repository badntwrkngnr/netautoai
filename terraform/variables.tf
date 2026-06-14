# --- Proxmox connection ---

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://homelab:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the form 'user@realm!tokenid=uuid'"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed PVE certs)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username the provider uses for node-level operations"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_password" {
  description = "SSH password the provider uses for node-level operations"
  type        = string
}

variable "proxmox_node" {
  description = "Target Proxmox node name, e.g. homelab"
  type        = string
}

# --- Storage / networking ---

variable "datastore_id" {
  description = "Proxmox storage ID for the VM disk and downloaded image (must have 'Import' content enabled)"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge for the VM's NIC"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag for the VM's NIC, or null for none"
  type        = number
  default     = null
}

# --- VM sizing ---

variable "vm_name" {
  description = "Name of the manager VM"
  type        = string
  default     = "netautoai"
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
  default     = 9100
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Disk size in GB (must be >= the cloud image's size)"
  type        = number
  default     = 64
}

# --- Cloud-init ---

variable "vm_ip_address" {
  description = "Static CIDR (e.g. 192.168.1.50/24) or \"dhcp\""
  type        = string
  default     = "dhcp"
}

variable "vm_ip_gateway" {
  description = "Gateway IP, required only when vm_ip_address is static"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS servers for the VM"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ci_user" {
  description = "Cloud-init user account to create"
  type        = string
  default     = "debian"
}

variable "ci_password" {
  description = "Cloud-init user account password"
  type        = string
  default     = "debian"
}

variable "ssh_public_keys" {
  description = "SSH public keys authorized for ci_user"
  type        = list(string)
}
