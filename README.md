# Homelab Network Automation Manager

A self-hosted Kubernetes platform for a home network automation lab, deployed as a Proxmox VM running k3s and connected to the rest of the homelab over Tailscale.

This project is part of a personal learning journey into network automation and infrastructure engineering: monitoring, documentation/source-of-truth, and (eventually) automated configuration of lab devices running in [pnetlab](https://pnetlab.com/). It started as a Docker Compose stack and was later migrated to k3s as a hands-on exercise in Kubernetes, Helm, and
declarative infrastructure.

## What it deploys

| Service      | Purpose                                                  | Deployed via              |
|--------------|----------------------------------------------------------|---------------------------|
| **Zabbix**   | SNMP monitoring/data collection from network devices     | Raw k8s manifests         |
| **Grafana**  | Dashboards, using Zabbix as a data source                | Raw k8s manifests         |
| **Netbox**   | DCIM/IPAM — source of truth for network documentation    | Raw k8s manifests         |
| **Infrahub** | Graph-based source of truth, synced from Netbox          | Official Helm chart       |
| **Traefik**  | Ingress controller, bundled with k3s                     | k3s built-in (customized) |

All services run as Kubernetes workloads in the `automation` namespace on a single-node k3s cluster, provisioned via Terraform and bootstrapped/deployed via Ansible. Kubernetes manifests for Netbox, Zabbix, and Grafana include resource requests/limits and liveness/readiness probes to improve stability.

## Architecture

```bash
                 ┌────────────────────────────────────────────┐
                 │            Manager VM (netautoai)          │
                 │            Proxmox + k3s + Tailscale       │
                 │                                            │
   Tailnet ──────┤   Traefik (k3s built-in ingress)           │
  (MagicDNS)     │   ┌────────┬─────────┬──────────┬────────┐ │
                 │   │ :8080  │  :8081  │  :8082   │ :8083  │ │
                 │   │Grafana │ Netbox  │ Zabbix   │Infrahub│ │
                 │   └────┬───┴────┬────┴────┬─────┴───┬────┘ │
                 │        │        │         │         │      │
                 │   namespace: automation (k3s, single node) │
                 └───────────────────────┬────────────────────┘
                                         │
                                     tailscale0
                                         │
                              ┌──────────┴───────────┐
                              │  pnetlab subnet(s)   │
                              │ (lab devices, SNMP)  │
                              └──────────────────────┘
```

Each service is reachable on its own static port via Traefik, customized through a `HelmChartConfig` to add entrypoints alongside the default ones k3s ships with. This mirrors the original Docker Compose design (one port per service on a single Tailscale hostname) rather than per-service hostnames, since it was the lower-friction path for a single-node homelab.

Storage is handled by k3s's bundled `local-path` provisioner — every stateful service's data lives in a `PersistentVolumeClaim` backed by a directory on the VM's own disk.

## Repository structure

```bash
.
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml
│   ├── group_vars/
│   │   └── all/
│   │       ├── vars.yml           
│   │       ├── vault.yml          # encrypted secrets (see below)
│   │       └── vault.yml.example
│   ├── roles/
│   │   ├── common/                 
│   │   ├── tailscale/              
│   │   └── k3s/                   
│   ├── templates/                 
│   ├── requirements.yml            
│   ├── site.yml                    
│   └── deploy_k8s.yml              
├── k8s/
│   ├── namespaces.yml
│   ├── traefik/
│   │   └── helmchartconfig.yaml    
│   ├── grafana/grafana.yaml
│   ├── zabbix/zabbix.yaml
│   ├── netbox/netbox.yaml
│   └── infrahub/ingressroute.yaml  
├── terraform/                      
├── scripts/                        
├── ansible.cfg
└── README.md
```

## Prerequisites

- A Proxmox host (`homelab`) able to run the manager VM
- [Terraform](https://www.terraform.io/) and [Ansible](https://docs.ansible.com/) installed on your workstation
- Ansible collections (`ansible.posix`, `community.general`, `kubernetes.core`): `ansible-galaxy collection install -r ansible/collections/requirements.yml`
- [Helm](https://helm.sh/) installed locally (useful for inspecting/debugging releases, e.g. `helm get values infrahub -n automation`)
- `kubectl` installed locally
- A Tailscale account, with the manager VM and pnetlab joined to the tailnet
- Pnetlab advertising the lab subnet(s) as Tailscale routes

## Validation

Before running a full build, validate the configuration files:

```bash
# Terraform
cd terraform
terraform validate
terraform fmt -check

# Ansible
cd ansible && ansible-playbook --syntax-check -i inventory/hosts.yml site.yml && ansible-playbook --syntax-check -i inventory/hosts.yml deploy_k8s.yml
```

## Setup

### 1. **Provision the VM**

```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars   # edit with real values
   terraform init
   terraform apply
```

`terraform.tfvars` is excluded from git tracking (see `.gitignore`) to prevent committing secrets. Sensitive variables such as `proxmox_api_token`, `proxmox_ssh_password`, and `ci_password` are marked `sensitive = true` in `terraform/variables.tf` so they are redacted from plan and apply output.

See [`terraform/README.md`](terraform/README.md) for Proxmox-side prerequisites. Note the IP from `terraform output manager_vm_ipv4_addresses` for the first Ansible run.

### 2. **Configure inventory**

   Edit `ansible/inventory/hosts.yml`. Use the VM's LAN IP for the *first* run (Tailscale hasn't joined yet); switch to the `netautoai` MagicDNS hostname for subsequent runs.

### 3. **Set up secrets**

```bash
   cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
   # fill in real values, then:
   ansible-vault encrypt ansible/group_vars/all/vault.yml
```

Required variables:

- `tailscale_authkey`
- `grafana_admin_password`
- `zabbix_db_password`
- `netbox_db_password`
- `netbox_secret_key`
- `netbox_redis_password`
- `infrahub_security_secret_key`
- `infrahub_admin_token`
- `infrahub_agent_token`
- `infrahub_neo4j_password`
- `infrahub_rabbitmq_password`

Generate UUID-style tokens with: `python3 -c "import uuid; print(uuid.uuid4())"`

### 4. **Bootstrap the VM**

Installs Tailscale, applies hardening, and installs k3s:

```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --ask-vault-pass
```

Verify with `KUBECONFIG=ansible/.kube/manager-node-k3s.yaml kubectl get nodes` — should show the node `Ready`.

### 5. **Deploy the workloads**

```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/deploy_k8s.yml --ask-vault-pass
```

This applies the namespace, Traefik customization, all per-service manifests, and installs Infrahub via its official Helm chart.

### 6. **Approve pnetlab's subnet routes**

In the Tailscale admin console, approve the route(s) advertised by `pnetlab`.

## Accessing the services

| Service           | URL                     |
|-------------------|-------------------------|
| Grafana           | `http://netautoai:8080` |
| Netbox            | `http://netautoai:8081` |
| Zabbix            | `http://netautoai:8082` |
| Infrahub          | `http://netautoai:8083` |
| Traefik dashboard | `http://netautoai:8090` |

## Notes for future-me

A few things worth knowing if anything ever needs rebuilding from scratch:

- **CPU sizing matters more than it looks.** Running Netbox, Zabbix, Grafana, and Infrahub's full stack (Neo4j, RabbitMQ, Prefect, plus its own Postgres) concurrently needs meaningfully more than 4 vCPUs once Neo4j's resource requests are accounted for — the original Terraform default was too low and had to be increased on the Proxmox side.
- **Neo4j's password and Infrahub's connection credentials are two separate settings.** Setting the Neo4j subchart's password does *not* automatically propagate to `infrahub-server`/`infrahub-task-worker` — they each need their own `INFRAHUB_DB_USERNAME`/`INFRAHUB_DB_PASSWORD` (and `INFRAHUB_BROKER_USERNAME`/`PASSWORD` for RabbitMQ) explicitly set to match, or they'll silently fall back to the chart's defaults and fail to authenticate. See `ansible/templates/infrahub-values.yaml.j2`.
- **After `terraform destroy`/`apply`, the VM has a new SSH host key.** Run `ssh-keygen -R <ip>` or rely on `ansible.cfg`'s `host_key_checking = False`.
- **A reused/expired Tailscale authkey hangs silently.** If the `tailscale up` task in the `k3s` role (sic — `tailscale` role) never completes, it's usually an authkey that's already been consumed; generate a new one in the Tailscale admin console.

## Roadmap

- [ ] Configure Zabbix SNMP polling against pnetlab lab devices
- [ ] Connect Grafana to Zabbix as a data source
- [ ] Populate Netbox with lab topology/documentation
- [ ] Build the Netbox → Infrahub sync script
- [ ] Start automating lab device configuration from Infrahub/Netbox data
- [ ] Evaluate moving to per-service Tailscale hostnames via the Tailscale Kubernetes Operator instead of static Traefik ports

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for
details. Feel free to use, modify, and build on it; attribution is
appreciated but not required beyond what the license states.
