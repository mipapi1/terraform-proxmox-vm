locals {
  # Proxmox can only clone to non-shared storage on the template's own node
  template_node_name = coalesce(var.template_node_name, var.node_name)
}

resource "proxmox_virtual_environment_vm" "virtual_machine" {
  depends_on = [proxmox_virtual_environment_file.cloud_config]

  name        = var.name
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags

  # Never restart a running VM from Terraform. Changes that need a restart (memory, CPU,
  # PCI devices, ...) stay pending in Proxmox until you restart the VM yourself. With the
  # provider default (true), one apply restarts every changed VM at once, e.g. all nodes
  # of a cluster together.
  reboot_after_update = false

  clone {
    vm_id     = var.template_vm_id
    node_name = local.template_node_name
    full      = true
    # On the template's node: clone straight to the target storage. On other nodes,
    # Proxmox can't clone across nodes to non-shared storage, so the clone lands on the
    # template's (shared) storage and the disk block below moves it.
    datastore_id = var.node_name == local.template_node_name ? var.vm_datastore_id : null
  }

  machine       = "q35"
  bios          = "ovmf" # UEFI; the template must be UEFI too
  scsi_hardware = "virtio-scsi-pci"

  efi_disk {
    datastore_id = var.vm_datastore_id
    file_format  = "raw"
    type         = "4m"
  }

  serial_device {
    device = "socket"
  }

  agent {
    enabled = true
    timeout = "120s"
  }

  cpu {
    cores = var.vcpu
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.vm_datastore_id
    interface    = var.disk_interface
    iothread     = var.disk_iothread
    file_format  = var.disk_file_format
    discard      = var.disk_discard
    size         = var.disk_size
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    # The cloud-init drive sits with the VM's disks (e.g. on ZFS, so storage replication
    # covers it; a drive on a directory storage can't be replicated). Moving it later
    # needs the VM powered off.
    datastore_id = var.vm_datastore_id
    ip_config {
      ipv4 {
        address = var.ip
        gateway = var.gateway
      }
    }
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  # Whole-device PCI passthrough (e.g. an Intel iGPU) through a cluster resource mapping,
  # so the API token needs no root rights and the VM gets "its" host's device wherever
  # it runs. See examples/gpu-passthrough.
  dynamic "hostpci" {
    for_each = var.pci_mapping == null ? [] : [var.pci_mapping]
    content {
      device  = "hostpci0"
      mapping = hostpci.value
      pcie    = true
    }
  }
}
