#!/usr/bin/env python3
"""
Generate a containerlab topology file from NetBox device/cable data.

Rationale: NetBox (synced from Infrahub) is already the source of truth for
devices and cabling. Rather than hand-maintaining a second topology file,
this reads the SoT and emits a .clab.yml -- consistent with the rest of the
pipeline (Infrahub -> NetBox -> Jinja2 -> Ansible).

Scope: only Devices tagged `containerlab` in NetBox (and the Cables between
two such devices) are included. This lets you mirror the whole lab, a
single area, or a brand new set of devices into containerlab without
touching this script -- just tag/untag devices in NetBox.

Role -> containerlab mapping:
  wan_core, wan_hub, site_router        -> kind: cisco_iol            (L3 IOL)
  site_core_switch, site_access_switch  -> kind: cisco_iol, type: l2  (L2 IOL)

Usage:
  NETBOX_URL=http://netautoai:8081 NETBOX_TOKEN=<token> \
    python3 netbox_to_containerlab.py --tag containerlab \
      --output containerlab/netautoai-lab.clab.yml

Requires: pynetbox, pyyaml (pip install pynetbox pyyaml --break-system-packages)
"""
import argparse
import os
import sys

import pynetbox
import yaml

# NetBox device-role slugs that get the L2 IOL image + `type: l2`.
# Adjust if your role slugs differ from schemas/network.yml's `role` enum.
L2_ROLE_SLUGS = {"site-core-switch", "site-access-switch"}

# Built locally via hellt/vrnetlab from the same IOL .bin files used in
# PNETLab -- do NOT pull a prebuilt image from a public registry (IOL
# redistribution isn't permitted by Cisco). Update these tags to match
# whatever you tagged your local build as.
IMAGE_L3 = "vrnetlab/cisco_iol:17.12.01"
IMAGE_L2 = "vrnetlab/cisco_iol:l2-17.12.01"

# Deliberately inside 172.16.0.0/12, which ansible/roles/common already
# FORWARDs + MASQUERADEs for k3s-pod-sourced traffic (10.42.0.0/16) -- see
# ansible/roles/common/tasks/main.yml. Using this range means Zabbix,
# NetBox, and Infrahub pods can reach containerlab mgmt IPs with zero new
# iptables rules, as long as nothing else on the manager VM already uses
# this /24. If PNETLab's own subnet (via Tailscale) ever overlaps this
# range, change it here.
MGMT_SUBNET = "172.20.20.0/24"

TOPOLOGY_NAME = "netautoai-lab"


def build_topology(nb: pynetbox.api, tag: str) -> dict:
    devices = list(nb.dcim.devices.filter(tag=tag))
    if not devices:
        sys.exit(
            f"No devices tagged '{tag}' found in NetBox. Tag the devices you "
            f"want mirrored into containerlab (NetBox UI or a pynetbox "
            f"script) and re-run."
        )

    device_names_by_id = {d.id: d.name for d in devices}
    nodes = {}
    for d in devices:
        role_slug = d.role.slug if getattr(d, "role", None) else None
        is_l2 = role_slug in L2_ROLE_SLUGS
        node = {"kind": "cisco_iol", "image": IMAGE_L2 if is_l2 else IMAGE_L3}
        if is_l2:
            node["type"] = "l2"
        nodes[d.name] = node

    links = []
    seen_cable_ids = set()
    for d in devices:
        for iface in nb.dcim.interfaces.filter(device_id=d.id, cabled=True):
            cable = iface.cable
            if cable is None or cable.id in seen_cable_ids:
                continue

            a_terms = cable.a_terminations or []
            b_terms = cable.b_terminations or []
            if not a_terms or not b_terms:
                continue  # only handle simple point-to-point cables

            a_iface, b_iface = a_terms[0], b_terms[0]
            a_dev_id = a_iface.object.device.id
            b_dev_id = b_iface.object.device.id

            # Skip cables that leave this containerlab subset (e.g. a link
            # to a device that's still only in PNETLab).
            if a_dev_id not in device_names_by_id or b_dev_id not in device_names_by_id:
                continue

            seen_cable_ids.add(cable.id)
            links.append(
                {
                    "endpoints": [
                        f"{device_names_by_id[a_dev_id]}:{a_iface.object.name}",
                        f"{device_names_by_id[b_dev_id]}:{b_iface.object.name}",
                    ]
                }
            )

    return {
        "name": TOPOLOGY_NAME,
        "mgmt": {"network": "clab-mgmt", "ipv4-subnet": MGMT_SUBNET},
        "topology": {"nodes": nodes, "links": links},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default="containerlab", help="NetBox tag to filter devices by")
    parser.add_argument(
        "--output",
        default="containerlab/netautoai-lab.clab.yml",
        help="Path to write the .clab.yml file",
    )
    args = parser.parse_args()

    try:
        url = os.environ["NETBOX_URL"]
        token = os.environ["NETBOX_TOKEN"]
    except KeyError as exc:
        sys.exit(f"Missing required environment variable: {exc}")

    nb = pynetbox.api(url, token=token)
    topology = build_topology(nb, args.tag)

    out_dir = os.path.dirname(args.output)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(args.output, "w") as f:
        yaml.dump(topology, f, sort_keys=False, default_flow_style=False)

    n_nodes = len(topology["topology"]["nodes"])
    n_links = len(topology["topology"]["links"])
    print(f"Wrote {n_nodes} nodes / {n_links} links to {args.output}")
    if n_links == 0:
        print(
            "WARNING: 0 links generated. Either the tagged devices aren't "
            "cabled to each other in NetBox yet, or 03_load_cables_and_ips.py "
            "hasn't been run against them.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
