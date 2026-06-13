# Homelab Network Automation Manager

A self-hosted "manager node" for a home network automation lab, deployed as a
Proxmox VM and connected to the rest of the homelab over Tailscale.

This project is part of a personal learning journey into network automation:
monitoring, documentation/source-of-truth, and (eventually) automated
configuration of lab devices running in [pnetlab](https://pnetlab.com/).

## What it deploys

| Service     | Purpose                                                  |
|-------------|----------------------------------------------------------|
| **Zabbix**  | SNMP monitoring/data collection from network devices     |
| **Grafana** | Dashboards, using Zabbix as a data source                |
| **Netbox**  | DCIM/IPAM — source of truth for network documentation    |
| **Infrahub**| Graph-based source of truth, synced from Netbox          |
| **NGINX**   | Reverse proxy in front of the above                      |

All services run as Docker Compose stacks on a single VM, orchestrated and
provisioned via Ansible.

## Architecture

```bash
                 ┌───────────────────────────────────────--┐
                 │           Manager VM (netautoai)        │
                 │           Proxmox + Tailscale           │
                 │                                         │
   Tailnet ──────┤  ┌────────┐  ┌─────────┐  ┌──────────┐  │
  (MagicDNS)     │  │ NGINX  │──│ Grafana │──│  Zabbix  │  │
                 │  │ proxy  │  └─────────┘  └────┬─────┘  │
                 │  └───┬────┘  ┌─────────┐       │        │
                 │      │       │ Netbox  │───────┘        │
                 │      │       └────┬────┘                │
                 │      │            │                     │
                 │      │       ┌────▼────┐                │
                 │      └───────│ Infrahub│                │
                 │              └─────────┘                │
                 │                                         │
                 │     automation_net (shared docker net)  │
                 └───────────────────┬─────────────────────┘
                                     │
                                 tailscale0
                                     │
                          ┌──────────┴───────────┐
                          │  pnetlab subnet(s)   │
                          │ (lab devices, SNMP)  │
                          └──────────────────────┘
```

The manager VM joins the same Tailscale network (tailnet) as the rest of the
homelab, with MagicDNS providing hostnames for `homelab` (Proxmox host),
`pnetlab`, and `netautoai` (this VM). The host accepts subnet routes
advertised by pnetlab so Docker containers can reach lab device IPs directly.

## Repository structure

```bash
.
├── ansible/              # Provisioning and deployment automation
│   ├── inventory/
│   ├── group_vars/
│   ├── roles/
│   │   ├── common/        # base hardening, ip_forward
│   │   ├── docker/         # Docker Engine + Compose plugin
│   │   ├── tailscale/       # joins tailnet, accepts routes
│   │   └── reverse_proxy/    # creates shared docker network
│   ├── site.yml           # bootstrap playbook
│   └── deploy_stacks.yml  # syncs and deploys compose stacks
├── stacks/                # One Docker Compose stack per service
│   ├── proxy/              # NGINX + per-service conf.d configs
│   ├── zabbix/
│   ├── grafana/
│   ├── netbox/
│   └── infrahub/
├── terraform/             # Nova pasta IaC
|   ├── modules/
|   │   └── proxmox_vm/    # Módulo genérico e reutilizável
|   │       ├── main.tf
|   │       ├── outputs.tf
|   │       └── variables.tf
|   ├── main.tf            # Ponto de entrada (chama os módulos)
|   ├── providers.tf       # Configuração do Provider (Proxmox)
|   ├── variables.tf       # Variáveis da raiz
|   ├── outputs.tf         # Outputs (ex: IP final para o Ansible usar)
|   └── terraform.tfvars   # Ignorado no .gitignore (Suas credenciais/IPs)
├── scripts/               # Automation helper scripts (e.g. Netbox<->Infrahub sync)
├── create_project.sh      # Scaffolding script for this repo layout
└── README.md
```

## Prerequisites

- A Proxmox host (`homelab`) with a VM provisioned for the manager node
- Debian/Ubuntu on the manager VM, reachable over SSH
- [Ansible](https://docs.ansible.com/) installed on your workstation
  (`pip install ansible` or `brew install ansible` on macOS)
- A Tailscale account, with the manager VM and pnetlab joined to the tailnet
- pnetlab advertising the lab subnet(s) as Tailscale routes

## Setup

1. **Configure inventory**

   Edit `ansible/inventory/hosts.yml` with the manager VM's address and SSH
   user (the Tailscale MagicDNS hostname works fine here).

2. **Set up secrets**

   Copy the example vault file and fill in real values:

   ```bash
   cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
   ansible-vault encrypt ansible/group_vars/all/vault.yml
   ```

3. **Review service configs**

   Adjust the `.env` files under each `stacks/*/` directory (database
   passwords, secret keys, etc.).

4. **Bootstrap the VM**

   Installs Docker, Tailscale, applies basic hardening, and creates the
   shared Docker network:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --ask-vault-pass
   ```

5. **Deploy the service stacks**

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/deploy_stacks.yml --ask-vault-pass
   ```

6. **Approve pnetlab's subnet routes**

   In the Tailscale admin console, approve the route(s) advertised by
   `pnetlab` so the manager VM can reach lab devices.

## Accessing the services

Once deployed, services are reachable via the manager VM's Tailscale
hostname:

| Service  | URL                          |
|----------|------------------------------|
| Grafana  | `http://netautoai:8080`      |
| Netbox   | `http://netautoai:8081`      |
| Zabbix   | `http://netautoai:8082`      |
| Infrahub | `http://netautoai:8083`      |

## Roadmap

- [ ] Configure Zabbix SNMP polling against pnetlab lab devices
- [ ] Connect Grafana to Zabbix as a data source
- [ ] Populate Netbox with lab topology/documentation
- [ ] Build the Netbox → Infrahub sync script
- [ ] Start automating lab device configuration from Infrahub/Netbox data

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for
details. Feel free to use, modify, and build on it; attribution is
appreciated but not required beyond what the license states.
