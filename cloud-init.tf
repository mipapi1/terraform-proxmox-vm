# Cloud-init user-data, uploaded as a snippet. Snippets are files, so this needs a
# directory-type datastore with `snippets` content enabled (e.g. `local`).
# The template is expected to have qemu-guest-agent installed, so nothing is installed here.
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = var.cloud_init_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = <<-EOF
#cloud-config
    hostname: ${var.name}
    timezone: ${var.timezone}
    users:
      - default
      - name: ${var.admin_username}
        groups:
          - sudo
          - _ssh
        shell: /bin/bash
        ssh_authorized_keys:
%{for key in var.ssh_public_keys~}
          - ${trimspace(key)}
%{endfor~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    runcmd:
      - echo "done" > /tmp/cloud-config.done
    EOF
    file_name = "user-data-${var.name}.yaml"
  }

  # cloud-init only runs on a VM's first boot. Without this, any later edit here (e.g. a
  # new SSH key) replaces the snippet, and that forces Terraform to destroy and recreate
  # the VM. New VMs still get the current content; change existing VMs with your
  # configuration management instead.
  lifecycle {
    ignore_changes = [source_raw]
  }
}
