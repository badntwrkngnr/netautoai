# Downloads the official Debian 13 (trixie) genericcloud image directly into
# Proxmox storage using the "import" content type (PVE 8.1+/9.x). This is
# fetched once and reused for the VM's disk.
resource "proxmox_virtual_environment_download_file" "debian_13_cloud_image" {
  content_type = "import"
  datastore_id = var.datastore_id
  node_name    = var.proxmox_node

  url       = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-genericcloud-amd64.qcow2"

  # Avoid re-downloading on every plan/apply
  overwrite = false
}

module "manager_vm" {
  source = "./modules/proxmox_vm"

  vm_name      = var.vm_name
  vm_id        = var.vm_id
  node_name    = var.proxmox_node
  datastore_id = var.datastore_id

  cores     = var.vm_cores
  memory    = var.vm_memory
  disk_size = var.vm_disk_size

  bridge  = var.network_bridge
  vlan_id = var.vlan_id

  image_file_id = proxmox_virtual_environment_download_file.debian_13_cloud_image.id

  ci_user     = var.ci_user
  ci_password = var.ci_password
  ci_ssh_keys = var.ssh_public_keys
  ip_address  = var.vm_ip_address
  ip_gateway  = var.vm_ip_gateway
  dns_servers = var.dns_servers

  tags = ["terraform", "manager-node"]
}
