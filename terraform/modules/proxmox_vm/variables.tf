variable "vm_name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "node_name" {
  type = string
}

variable "datastore_id" {
  type = string
}

variable "cores" {
  type = number
}

variable "memory" {
  type = number
}

variable "disk_size" {
  type = number
}

variable "bridge" {
  type = string
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "image_file_id" {
  description = "file_id of the downloaded/imported disk image to clone the VM disk from"
  type        = string
}

variable "ip_address" {
  description = "CIDR address or \"dhcp\""
  type        = string
}

variable "ip_gateway" {
  type    = string
  default = null
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "ci_user" {
  type = string
}

variable "ci_password" {
  type = string
}

variable "ci_ssh_keys" {
  type = list(string)
}

variable "tags" {
  type    = list(string)
  default = []
}
