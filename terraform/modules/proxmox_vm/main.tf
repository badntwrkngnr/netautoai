resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id
  tags      = var.tags

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = var.image_file_id
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.ip_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.ci_user
      password = var.ci_password
      keys     = var.ci_ssh_keys
    }
  }

  # Cloud images expect a serial console
  serial_device {}

  boot_order = ["scsi0"]

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}
