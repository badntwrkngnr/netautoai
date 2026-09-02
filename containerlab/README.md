# containerlab — second lab environment (k3s)

A containerlab topology, generated from NetBox and deployed **via k3s** on the
manager VM (`netautoai`). Lab nodes run as Docker containers on the host
(docker.sock); k3s orchestrates the deploy through a privileged Job.

This is a **separate** environment from PNETLab, not a replacement — same
devices/roles can exist in both, or you can mirror a different subset.

## Architecture

```text
NetBox (SoT)  →  netbox_to_containerlab.py  →  ConfigMap
                                                    ↓
k3s Job (ghcr.io/srl-labs/clab)  →  docker.sock  →  IOL containers on host
                                                    ↓
                              /opt/containerlab/netautoai-lab/  (inventory, state)
```

k3s (containerd) runs the automation stack; Docker on the host runs the lab
nodes. The `docker` Ansible role installs Docker during `site.yml` bootstrap.

## Why NetBox-generated instead of hand-written

`scripts/netbox_to_containerlab.py` reads Devices and Cables from NetBox and
emits `netautoai-lab.clab.yml`. Scope is controlled by a NetBox tag: tag
devices with `containerlab` to include them (and cables between tagged devices).

Given the manager VM's CPU/RAM pressure (see main README), start with one area
(e.g. Site A, 6 devices) rather than all 20.

## Prerequisites

1. **Bootstrap** with Docker enabled (included in `site.yml` since this refactor):
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --ask-vault-pass
   ```
2. **IOL images** built locally on the manager node via
   [hellt/vrnetlab](https://github.com/hellt/vrnetlab) — Cisco does not permit
   redistribution:
   ```bash
   git clone https://github.com/hellt/vrnetlab
   cd vrnetlab/cisco/iol
   cp /path/to/your/cisco_iol-17.12.01.bin .
   cp /path/to/your/cisco_iol-l2-17.12.01.bin .
   make docker-build   # tags must match IMAGE_L3/IMAGE_L2 in the generator script
   ```
3. Devices tagged `containerlab` in NetBox with cabling loaded.

## Networking model

- **Mgmt subnet**: `172.20.20.0/24` (inside `172.16.0.0/12`). The `common` role
  already FORWARDs/MASQUERADEs k3s pod traffic (`10.42.0.0/16`) toward
  `172.16.0.0/12`, so Zabbix/NetBox/Infrahub pods reach containerlab mgmt IPs
  without new iptables rules. Confirm PNETLab's Tailscale subnet does not overlap.
- Lab nodes are reachable from pods via their `172.20.20.x` mgmt addresses.

## Deploying

### Via Ansible (recommended — regenerates topology from NetBox)

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/deploy_containerlab.yml --ask-vault-pass
```

### Via kubectl (manual)

```bash
export KUBECONFIG=ansible/.kube/manager-node-k3s.yaml

# 1. Generate topology (NetBox must be reachable)
NETBOX_URL=http://netautoai:8081 NETBOX_TOKEN=<token> \
  python3 scripts/netbox_to_containerlab.py --tag containerlab

# 2. Apply ConfigMap + Job
kubectl create configmap containerlab-topology \
  --from-file=netautoai-lab.clab.yml=containerlab/netautoai-lab.clab.yml \
  -n automation --dry-run=client -o yaml | kubectl apply -f -

kubectl delete job containerlab-deploy -n automation --ignore-not-found
kubectl apply -f k8s/containerlab/job.yaml

# 3. Wait and check
kubectl wait --for=condition=complete job/containerlab-deploy -n automation --timeout=600s
kubectl logs -n automation -l app=containerlab-deploy
kubectl get pods -n automation -l app=containerlab-deploy
```

Inventory after deploy: `/opt/containerlab/netautoai-lab/clab-netautoai-lab/ansible-inventory.yml`
on the manager node (also fetched to `containerlab/generated-inventory/` by Ansible).

## Connecting existing services

- **Zabbix**: SNMP poll each node's `172.20.20.x` mgmt IP.
- **NetBox / Infrahub**: source of truth — topology is generated from NetBox.
- **Ansible/Nornir**: use fetched inventory; add `ansible_connection: network_cli`
  and `ansible_network_os: cisco.ios.ios` group_vars on top.
- **Grafana**: unchanged (reads Zabbix).

## Kubernetes manifests

| File | Purpose |
|------|---------|
| `k8s/containerlab/configmap.yaml` | Stub — real ConfigMap applied by Ansible/kubectl |
| `k8s/containerlab/job.yaml` | Privileged Job running `containerlab deploy` |

## Known gaps / TODO

- Cables where either end is untagged are skipped (expected).
- `--reconfigure` tears down and rebuilds every deploy — config pushed via
  Ansible/Nornir must be re-applied after each run.
- No per-node CPU/memory limits in the generated topology yet.
- Clabernetes (native multi-node k8s labs) was not adopted — too heavy for this
  single-node homelab; revisit if you add worker nodes.
