#!/usr/bin/env python3
"""
Placeholder for the Netbox -> Infrahub sync script.

Plan:
- Read devices/sites/racks from Netbox via pynetbox
- Push corresponding nodes into Infrahub via the infrahub SDK
- Run on a schedule (cron, or as an Infrahub task)
"""

def main():
    raise NotImplementedError("TODO: implement Netbox -> Infrahub sync")


if __name__ == "__main__":
    main()
