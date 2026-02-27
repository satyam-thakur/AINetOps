#!/usr/bin/env python3
"""
seed_netbox.py — Populate NetBox with baseline AIOps lab data.

Prerequisite: NetBox must be running (docker compose up -d) and reachable.
Install:      pip install pynetbox

Usage:        python seed_netbox.py [--url URL] [--token TOKEN]
"""

import argparse
import sys
import time

try:
    import pynetbox
except ImportError:
    print("ERROR: pynetbox not installed. Run: pip install pynetbox")
    sys.exit(1)


# ── Default Configuration ────────────────────────────────────────────────────

NETBOX_URL = "http://localhost:8000"
NETBOX_TOKEN = "0123456789abcdef0123456789abcdef01234567"

# ── Lab Data ─────────────────────────────────────────────────────────────────

SITE = {"name": "Lab-DC1", "slug": "lab-dc1", "status": "active"}

MANUFACTURER = {"name": "Nokia", "slug": "nokia"}

DEVICE_TYPES = [
    {
        "manufacturer": "Nokia",
        "model": "SRLinux IXR-D3L",
        "slug": "srlinux-ixr-d3l",
        "u_height": 1,
    },
    {
        "manufacturer": "Nokia",
        "model": "SRLinux IXR-D2L",
        "slug": "srlinux-ixr-d2l",
        "u_height": 1,
    },
]

DEVICE_ROLES = [
    {"name": "Spine", "slug": "spine", "color": "4caf50"},
    {"name": "Leaf", "slug": "leaf", "color": "2196f3"},
]

DEVICES = [
    {
        "name": "spine1",
        "device_type": "srlinux-ixr-d3l",
        "role": "spine",
        "site": "lab-dc1",
        "status": "active",
    },
    {
        "name": "leaf1",
        "device_type": "srlinux-ixr-d2l",
        "role": "leaf",
        "site": "lab-dc1",
        "status": "active",
    },
]

INTERFACES = [
    {"device": "spine1", "name": "ethernet-1/1", "type": "10gbase-x-sfpp",
     "description": "to-leaf1:e1-1"},
    {"device": "spine1", "name": "mgmt0", "type": "1000base-t",
     "description": "management", "mgmt_only": True},
    {"device": "leaf1", "name": "ethernet-1/1", "type": "10gbase-x-sfpp",
     "description": "to-spine1:e1-1"},
    {"device": "leaf1", "name": "mgmt0", "type": "1000base-t",
     "description": "management", "mgmt_only": True},
]

IP_ADDRESSES = [
    {"address": "10.0.0.0/31", "device": "spine1", "interface": "ethernet-1/1",
     "status": "active", "description": "fabric link spine1-leaf1"},
    {"address": "10.0.0.1/31", "device": "leaf1", "interface": "ethernet-1/1",
     "status": "active", "description": "fabric link leaf1-spine1"},
]

VLANS = [
    {"vid": 10, "name": "Data", "site": "lab-dc1", "status": "active",
     "description": "Data VLAN"},
    {"vid": 20, "name": "Management", "site": "lab-dc1", "status": "active",
     "description": "Management VLAN"},
]

CABLE = {
    "a_device": "spine1", "a_interface": "ethernet-1/1",
    "b_device": "leaf1", "b_interface": "ethernet-1/1",
    "status": "connected", "label": "fabric-link-1",
}


# ── Helper Functions ─────────────────────────────────────────────────────────

def wait_for_netbox(nb, retries=10, delay=5):
    """Wait for NetBox API to become available."""
    for attempt in range(1, retries + 1):
        try:
            nb.status()
            print(f"  ✓ NetBox API reachable (attempt {attempt})")
            return True
        except Exception:
            print(f"  … Waiting for NetBox (attempt {attempt}/{retries})")
            time.sleep(delay)
    print("  ✗ NetBox API not reachable after all retries")
    return False


def get_or_create(endpoint, search_params, create_params):
    """Get an existing object or create a new one."""
    existing = endpoint.get(**search_params)
    if existing:
        print(f"  ↳ Already exists: {existing}")
        return existing
    obj = endpoint.create(create_params)
    print(f"  ✓ Created: {obj}")
    return obj


# ── Main Seeding Logic ───────────────────────────────────────────────────────

def seed(nb):
    """Populate NetBox with all lab data."""

    # ── Site ──────────────────────────────────────────────────────────────
    print("\n[1/8] Creating site...")
    site = get_or_create(nb.dcim.sites, {"slug": SITE["slug"]}, SITE)

    # ── Manufacturer ──────────────────────────────────────────────────────
    print("\n[2/8] Creating manufacturer...")
    mfr = get_or_create(
        nb.dcim.manufacturers,
        {"slug": MANUFACTURER["slug"]},
        MANUFACTURER,
    )

    # ── Device Types ──────────────────────────────────────────────────────
    print("\n[3/8] Creating device types...")
    for dt in DEVICE_TYPES:
        dt_create = {**dt, "manufacturer": mfr.id}
        get_or_create(nb.dcim.device_types, {"slug": dt["slug"]}, dt_create)

    # ── Device Roles ──────────────────────────────────────────────────────
    print("\n[4/8] Creating device roles...")
    for role in DEVICE_ROLES:
        get_or_create(nb.dcim.device_roles, {"slug": role["slug"]}, role)

    # ── Devices ───────────────────────────────────────────────────────────
    print("\n[5/8] Creating devices...")
    device_objs = {}
    for dev in DEVICES:
        dt = nb.dcim.device_types.get(slug=dev["device_type"])
        role = nb.dcim.device_roles.get(slug=dev["role"])
        create_params = {
            "name": dev["name"],
            "device_type": dt.id,
            "role": role.id,
            "site": site.id,
            "status": dev["status"],
        }
        device_objs[dev["name"]] = get_or_create(
            nb.dcim.devices, {"name": dev["name"]}, create_params
        )

    # ── Interfaces ────────────────────────────────────────────────────────
    print("\n[6/8] Creating interfaces...")
    iface_objs = {}
    for iface in INTERFACES:
        device = device_objs[iface["device"]]
        create_params = {
            "device": device.id,
            "name": iface["name"],
            "type": iface["type"],
            "description": iface.get("description", ""),
            "mgmt_only": iface.get("mgmt_only", False),
        }
        key = f"{iface['device']}:{iface['name']}"
        iface_objs[key] = get_or_create(
            nb.dcim.interfaces,
            {"device_id": device.id, "name": iface["name"]},
            create_params,
        )

    # ── IP Addresses ──────────────────────────────────────────────────────
    print("\n[7/8] Creating IP addresses...")
    for ip in IP_ADDRESSES:
        iface_key = f"{ip['device']}:{ip['interface']}"
        iface = iface_objs[iface_key]
        create_params = {
            "address": ip["address"],
            "status": ip["status"],
            "description": ip.get("description", ""),
            "assigned_object_type": "dcim.interface",
            "assigned_object_id": iface.id,
        }
        get_or_create(
            nb.ipam.ip_addresses,
            {"address": ip["address"]},
            create_params,
        )

    # ── VLANs ─────────────────────────────────────────────────────────────
    print("\n[8/8] Creating VLANs...")
    for vlan in VLANS:
        create_params = {
            "vid": vlan["vid"],
            "name": vlan["name"],
            "site": site.id,
            "status": vlan["status"],
            "description": vlan.get("description", ""),
        }
        get_or_create(
            nb.ipam.vlans,
            {"vid": vlan["vid"], "site_id": site.id},
            create_params,
        )

    # ── Cable ─────────────────────────────────────────────────────────────
    print("\n[Bonus] Creating cable...")
    a_iface = iface_objs[f"{CABLE['a_device']}:{CABLE['a_interface']}"]
    b_iface = iface_objs[f"{CABLE['b_device']}:{CABLE['b_interface']}"]

    # Check if cable already exists on either termination
    existing_cables = nb.dcim.cables.filter(device_id=device_objs[CABLE["a_device"]].id)
    cable_exists = False
    for c in existing_cables:
        # Cable already connects these interfaces
        cable_exists = True
        print(f"  ↳ Cable already exists: {c}")
        break

    if not cable_exists:
        try:
            cable = nb.dcim.cables.create({
                "a_terminations": [
                    {"object_type": "dcim.interface", "object_id": a_iface.id}
                ],
                "b_terminations": [
                    {"object_type": "dcim.interface", "object_id": b_iface.id}
                ],
                "status": CABLE["status"],
                "label": CABLE["label"],
            })
            print(f"  ✓ Created cable: {cable}")
        except Exception as e:
            print(f"  ⚠ Cable creation skipped: {e}")

    print("\n" + "=" * 60)
    print("  NetBox seeding complete!")
    print(f"  URL: {nb.base_url}")
    print(f"  Devices: {len(DEVICES)}")
    print(f"  Interfaces: {len(INTERFACES)}")
    print(f"  IPs: {len(IP_ADDRESSES)}")
    print(f"  VLANs: {len(VLANS)}")
    print("=" * 60)


# ── Entry Point ──────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Seed NetBox with AIOps lab data")
    parser.add_argument("--url", default=NETBOX_URL, help="NetBox URL")
    parser.add_argument("--token", default=NETBOX_TOKEN, help="NetBox API token")
    args = parser.parse_args()

    print(f"Connecting to NetBox at {args.url}...")
    nb = pynetbox.api(args.url, token=args.token)

    if not wait_for_netbox(nb):
        sys.exit(1)

    seed(nb)


if __name__ == "__main__":
    main()
