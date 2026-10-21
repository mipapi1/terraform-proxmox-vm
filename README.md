# terraform-proxmox-vm

Terraform module for Proxmox VE that clones VMs from a cloud-init template, using the
[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider.
Optionally, a VM gets a whole PCI device (such as an Intel iGPU) passed through.

It's the module behind a three-node Proxmox VE 9 homelab, where it runs a k3s cluster
with GPU hardware transcoding and a replicated secrets VM. The defaults are generic; the
comments explain why things are set the way they are.

## Features

- **Full clone from a UEFI/q35 template** to any node of a cluster. Clones to a node
  other than the template's go through the template's shared storage, then move to the
  target storage. That's the only way Proxmox allows it.
- **Cloud-init user-data** as a snippet: hostname, timezone, an admin user with SSH keys
  and passwordless sudo.
- **Static IP or DHCP**, optional VLAN tag.
- **PCI passthrough through a cluster resource mapping** (`pci_mapping`). Each VM gets
  "its" host's device, and the API token needs `Mapping.Use` instead of root.
- **Never restarts a running VM.** `reboot_after_update = false`: changes that need a
  restart (memory, CPU, PCI devices) wait in Proxmox until you restart the VM yourself,
  so one `apply` can't take down every node of a cluster at once.
- **The cloud-init drive lives with the VM disks**, so ZFS storage replication covers the
  whole VM.

## Usage

```hcl
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
  ssh_public_keys = [file("~/.ssh/id_ed25519.pub")]
}
```

Full examples:

- [`examples/basic`](examples/basic): one VM, provider setup included
- [`examples/gpu-passthrough`](examples/gpu-passthrough): three VMs, each getting its
  host's Intel iGPU through one cluster PCI mapping

## Requirements

- Terraform >= 1.5, provider `bpg/proxmox` >= 0.98.1
- **A cloud-init template**: UEFI (OVMF), q35, `qemu-guest-agent` installed, cloud-init
  drive. An Ubuntu cloud image converted to a template works.
- **A directory datastore with `snippets` content** for the user-data file (`local` by
  default: Datacenter → Storage → local → Content → Snippets).
- **SSH from Terraform to the node**: the provider uploads snippets over SSH. Configure
  the provider's `ssh` block (agent or key).
- **API token privileges**, for a dedicated role:
  `Datastore.Allocate, Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Audit,
  SDN.Use, Sys.Audit, VM.Allocate, VM.Audit, VM.Clone, VM.Config.CDROM, VM.Config.CPU,
  VM.Config.Cloudinit, VM.Config.Disk, VM.Config.HWType, VM.Config.Memory,
  VM.Config.Network, VM.Config.Options, VM.Migrate, VM.PowerMgmt, VM.GuestAgent.Audit`,
  plus `Mapping.Audit, Mapping.Use` (and `Mapping.Modify` if Terraform manages the
  mapping) for passthrough. Proxmox VE 9 removed `VM.Monitor`; roles that still list it
  need it replaced.

## GPU passthrough (Intel iGPU)

Tested with Intel N100 and N150 (Alder Lake-N) hosts on Proxmox VE 9 and Ubuntu 24.04
guests:

1. **Host:** IOMMU enabled (default on recent Intel CPUs), and the iGPU (`00:02.0`) alone
   in its IOMMU group: `ls /sys/kernel/iommu_groups/*/devices`.
2. **Host:** keep the host's own drivers off the iGPU, so `vfio-pci` can take it:
   ```sh
   printf 'blacklist i915\nblacklist xe\n' > /etc/modprobe.d/blacklist-igpu.conf
   update-initramfs -u -k all && proxmox-boot-tool refresh && reboot
   lspci -nnk -s 00:02.0   # "Kernel driver in use: vfio-pci" once a VM uses it
   ```
3. **Terraform:** a `proxmox_hardware_mapping_pci` with one entry per node, and
   `pci_mapping = <its name>` on the VMs (see the example).
4. **Guest:** a kernel that knows the GPU. Ubuntu's cloud-image kernel ("virtual" flavor)
   has no GPU drivers; install `linux-generic-hwe-24.04` and `linux-firmware`.
   `/dev/dri/renderD128` appears after a reboot.

Attaching a PCI device needs the VM powered off: stop and start the VM after the apply
(a reboot from inside the guest isn't enough).

## Inputs

| Name | Description | Default |
|---|---|---|
| `name` | VM name and hostname | required |
| `node_name` | Node to create the VM on | required |
| `template_vm_id` | Template VM ID | required |
| `ip` | `address/prefix` or `dhcp` | required |
| `disk_size` | Boot disk size (GB) | required |
| `template_node_name` | Node holding the template | `node_name` |
| `vm_id` | VM ID | next free |
| `description`, `tags` | Shown in Proxmox | `null` |
| `vcpu` / `cpu_type` / `memory` | Cores / CPU type / MB | `2` / `host` / `2048` |
| `pci_mapping` | PCI resource mapping to pass through | `null` |
| `vm_datastore_id` | Disks, EFI disk, cloud-init drive | `local-lvm` |
| `cloud_init_datastore_id` | Snippet storage | `local` |
| `disk_interface` / `disk_file_format` | | `virtio0` / `raw` |
| `disk_iothread` / `disk_discard` | | `true` / `on` |
| `bridge` / `vlan_id` / `gateway` | Network | `vmbr0` / untagged / `null` |
| `admin_username` | Cloud-init admin user | `admin` |
| `ssh_public_keys` | Keys for the admin user | `[]` |
| `timezone` | | `UTC` |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | Proxmox VM ID |
| `name`, `node_name` | VM name and node |
| `ipv4_addresses` | Addresses reported by the guest agent |
| `mac_addresses` | NIC MAC addresses |

## Notes and gotchas

- **Cloud-init runs once**, on first boot. The snippet is ignored for changes afterwards
  (`lifecycle.ignore_changes`); otherwise editing it (e.g. adding an SSH key) would make
  Terraform recreate the VM. Manage running VMs with configuration management.
- **Moving the cloud-init drive to another storage needs the VM off.** The provider
  refuses while `reboot_after_update = false`. Do it with `qm` instead (VM stopped):
  `qm set <id> --delete ide2 && qm set <id> --ide2 <storage>:cloudinit`.
- **Storage replication skips cloud-init drives.** Proxmox rebuilds them from the
  snippet at start, so for failover the snippet must exist on the target node too.

## License

MIT
