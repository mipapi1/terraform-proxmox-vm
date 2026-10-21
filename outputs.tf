output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.virtual_machine.vm_id
}

output "name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.virtual_machine.name
}

output "node_name" {
  description = "Proxmox node the VM runs on"
  value       = proxmox_virtual_environment_vm.virtual_machine.node_name
}

output "ipv4_addresses" {
  description = "IPv4 addresses reported by the guest agent, per interface"
  value       = proxmox_virtual_environment_vm.virtual_machine.ipv4_addresses
}

output "mac_addresses" {
  description = "MAC addresses of the VM's network interfaces"
  value       = proxmox_virtual_environment_vm.virtual_machine.mac_addresses
}
