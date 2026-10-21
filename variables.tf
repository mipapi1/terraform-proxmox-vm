#############
# Required  #
#############

variable "name" {
  description = "VM name (also the hostname set by cloud-init)"
  type        = string
}

variable "node_name" {
  description = "Proxmox node to create the VM on"
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the cloud-init template to clone (UEFI/q35, qemu-guest-agent installed)"
  type        = number
}

variable "ip" {
  description = "IPv4 address with prefix length (e.g. 192.168.1.50/24), or \"dhcp\""
  type        = string
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

#############
# VM        #
#############

variable "vm_id" {
  description = "VM ID (null: next free ID)"
  type        = number
  default     = null
}

variable "description" {
  description = "VM description shown in Proxmox"
  type        = string
  default     = null
}

variable "tags" {
  description = "Proxmox tags"
  type        = list(string)
  default     = null
}

variable "template_node_name" {
  description = "Node that holds the template (null: same as node_name)"
  type        = string
  default     = null
}

variable "vcpu" {
  description = "Number of vCPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type (host = best performance; use a generic type such as x86-64-v2-AES if VMs migrate between different CPUs)"
  type        = string
  default     = "host"
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "pci_mapping" {
  description = "Name of a cluster PCI resource mapping to pass through as hostpci0 (null: none)"
  type        = string
  default     = null
}

#############
# Storage   #
#############

variable "vm_datastore_id" {
  description = "Datastore for the VM's disks, EFI disk and cloud-init drive"
  type        = string
  default     = "local-lvm"
}

variable "cloud_init_datastore_id" {
  description = "Directory datastore with `snippets` content for the cloud-init user-data file"
  type        = string
  default     = "local"
}

variable "disk_interface" {
  description = "Boot disk interface"
  type        = string
  default     = "virtio0"
}

variable "disk_file_format" {
  description = "Boot disk format"
  type        = string
  default     = "raw"
}

variable "disk_iothread" {
  description = "Give the boot disk its own IO thread"
  type        = bool
  default     = true
}

variable "disk_discard" {
  description = "Pass TRIM/discard to the storage (on/ignore)"
  type        = string
  default     = "on"
}

#############
# Network   #
#############

variable "bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag (null: untagged)"
  type        = number
  default     = null
}

variable "gateway" {
  description = "IPv4 gateway (null with ip = \"dhcp\")"
  type        = string
  default     = null
}

#############
# Cloud-init #
#############

variable "admin_username" {
  description = "Admin user created by cloud-init (sudo without password, SSH keys only)"
  type        = string
  default     = "admin"
}

variable "ssh_public_keys" {
  description = "SSH public keys for the admin user"
  type        = list(string)
  default     = []
}

variable "timezone" {
  description = "Timezone set by cloud-init"
  type        = string
  default     = "UTC"
}
