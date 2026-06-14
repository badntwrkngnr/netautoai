output "manager_vm_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent, per network interface"
  value       = module.manager_vm.ipv4_addresses
}

output "manager_vm_id" {
  description = "Proxmox VM ID of the manager node"
  value       = module.manager_vm.vm_id
}
