# Changelog

## v1.0.0

First public release, extracted from a running three-node Proxmox VE 9 homelab.

- Full clone of a UEFI/q35 cloud-init template, including clones to nodes other than
  the template's node
- Cloud-init user-data snippet: hostname, timezone, admin user with SSH keys
- Optional whole-device PCI passthrough through a cluster resource mapping (iGPU)
- Never restarts running VMs (`reboot_after_update = false`)
- Cloud-init drive stored with the VM disks (replication-friendly)
