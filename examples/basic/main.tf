# One VM cloned from a cloud-init template, static IP on a VLAN.
terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox", version = ">= 0.98.1" }
  }
}

provider "proxmox" {
  endpoint  = "https://pve1.example.com:8006/"
  api_token = var.proxmox_api_token # user@realm!tokenid=secret, e.g. from Vault or an env var
  # Uploading the cloud-init snippet needs SSH to the node
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

module "web" {
  source = "github.com/mipapi1/terraform-proxmox-vm?ref=v1.0.0"

  name           = "web01"
  node_name      = "pve1"
  template_vm_id = 9000

  vcpu      = 2
  memory    = 4096
  disk_size = 32

  ip      = "192.168.20.50/24"
  gateway = "192.168.20.1"
  vlan_id = 20

  vm_datastore_id = "local-zfs"
  admin_username  = "ops"
  ssh_public_keys = var.ssh_public_keys
  timezone        = "Europe/Berlin"
  tags            = ["web", "terraform"]
}

output "web_ip" {
  value = module.web.ipv4_addresses
}
