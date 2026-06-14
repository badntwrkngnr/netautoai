# Terraform - Manager VM

Provisions the `netautoai` manager VM on Proxmox VE using the
[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)
provider, by importing the official Debian 13 (trixie) `genericcloud` qcow2
image and booting it with cloud-init.

## One-time Proxmox setup

**1. Create an API token for Terraform** (run on the Proxmox host or via
the shell in the web UI):

```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role PVEAdmin
pveum user token add terraform@pve tf --privsep 0
```

The last command prints a token secret -- it's shown only once. Combine it
with the user/token id as `terraform@pve!tf=<secret>` for `proxmox_api_token`.

`PVEAdmin` is broad; for a tighter setup create a custom role with just the
VM/datastore privileges Terraform needs (see the
[bpg provider docs](https://bpg.sh/docs/) for a minimal privilege list).

**2. Enable "Import" content type on your storage**

In the Proxmox UI: *Datacenter -> Storage -> (your storage, e.g.
`local-lvm`) -> Edit -> Content*, make sure **Disk image** and **Import**
are both enabled. This is required for
`proxmox_virtual_environment_download_file` with `content_type = "import"`
to work (PVE 8.1+ / 9.x).

**3. SSH access for the provider**

The bpg provider uses SSH for some node-level operations. Make sure the
machine running `terraform apply` can SSH to the Proxmox node as
`proxmox_ssh_username` (default `root`) using an SSH agent, or adjust the
`ssh` block in `providers.tf` to use a key file instead.

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: endpoint, api token, node, SSH key, etc.

terraform init
terraform plan
terraform apply
```

On first apply, Terraform will:

1. Download the Debian 13 `genericcloud` image into Proxmox storage (once).
2. Create VM `9100` (`netautoai`) with cloud-init configured for the
   `ci_user` account and your SSH public key(s).

## Getting the IP for Ansible

```bash
terraform output manager_vm_ipv4_addresses
```

This returns one list of addresses per NIC (the QEMU guest agent must be
running -- the Debian cloud image includes it, but it can take ~30-60s after
boot to report). Use the LAN IP for the **first** Ansible run, since the
tailscale role hasn't joined the tailnet yet:

```yaml
# ansible/inventory/hosts.yml (temporary, for first run)
all:
  hosts:
    manager-node:
      ansible_host: 192.168.1.50   # from terraform output
      ansible_user: debian
```

After `ansible/site.yml` runs and the host joins the tailnet, switch
`ansible_host` back to the MagicDNS name (`netautoai`) for subsequent runs.

## Notes

- `vm_disk_size` must be >= the cloud image's size (a few GB); Proxmox grows
  the disk to the requested size on import.
- The `lifecycle.ignore_changes = [initialization]` block on the VM resource
  prevents Terraform from re-applying cloud-init (and rebooting the VM) once
  it's been provisioned and handed off to Ansible.
- `ci_user` defaults to `debian`. Add it to `ansible/inventory/hosts.yml` as
  `ansible_user`.
