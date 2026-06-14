output "vm_id" {
  value = proxmox_virtual_environment_vm.vm.vm_id
}

output "ipv4_addresses" {
  description = "List of IPv4 addresses per network interface, reported by the QEMU guest agent"
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
}
