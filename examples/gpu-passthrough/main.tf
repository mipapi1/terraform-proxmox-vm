# Three-node cluster where every node passes its Intel iGPU to "its" VM, e.g. for
# hardware video transcoding in Kubernetes. One cluster PCI mapping names the GPU on
# every node, so each VM gets the GPU of whatever host it runs on, and the API token
# needs only the Mapping.Use privilege instead of root.
#
# Host preparation (each node, see the README): IOMMU on, the iGPU alone in its IOMMU
# group, and the host's own GPU drivers kept off it:
#   printf 'blacklist i915\nblacklist xe\n' > /etc/modprobe.d/blacklist-igpu.conf
#   update-initramfs -u -k all && proxmox-boot-tool refresh && reboot
terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox", version = ">= 0.98.1" }
  }
}

provider "proxmox" {
  endpoint  = "https://pve1.example.com:8006/"
  api_token = var.proxmox_api_token
  ssh {
    agent    = true
    username = "root"
  }
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_keys" {
  description = "Public keys for the admin user, e.g. [\"ssh-ed25519 AAAA... you@laptop\"]"
  type        = list(string)
}

# Find the values on each node with: lspci -nn -s 00:02.0 and
# lspci -vmmn -s 00:02.0 (subsystem), and the group under /sys/kernel/iommu_groups
resource "proxmox_hardware_mapping_pci" "igpu" {
  name    = "intel-igpu"
  comment = "Intel iGPU of each node"
  map = [
    { node = "pve1", path = "0000:00:02.0", id = "8086:46d1", subsystem_id = "8086:7270", iommu_group = 0 },
    { node = "pve2", path = "0000:00:02.0", id = "8086:46d4", subsystem_id = "8086:7270", iommu_group = 0 },
    { node = "pve3", path = "0000:00:02.0", id = "8086:46d4", subsystem_id = "8086:7270", iommu_group = 0 },
  ]
}

locals {
  nodes = {
    k8s01 = { node = "pve1", ip = "192.168.20.11/24" }
    k8s02 = { node = "pve2", ip = "192.168.20.12/24" }
    k8s03 = { node = "pve3", ip = "192.168.20.13/24" }
  }
}

module "k8s" {
  source   = "github.com/mipapi1/terraform-proxmox-vm?ref=v1.0.0"
  for_each = local.nodes

  name               = each.key
  node_name          = each.value.node
  template_node_name = "pve1" # the template lives on pve1
  template_vm_id     = 9000

  vcpu      = 4
  memory    = 10240
  disk_size = 100

  ip      = each.value.ip
  gateway = "192.168.20.1"

  vm_datastore_id = "local-zfs"
  ssh_public_keys = var.ssh_public_keys

  pci_mapping = proxmox_hardware_mapping_pci.igpu.name
}
