#!/usr/bin/env python3
import json
import os
from pathlib import Path
from typing import Any

from netbox_mcp_server.netbox_client import NetBoxRestClient
from netbox_mcp_server.netbox_types import NETBOX_OBJECT_TYPES


def endpoint_for(object_type: str) -> str:
    info = NETBOX_OBJECT_TYPES.get(object_type)
    if not info:
        raise ValueError(f"Unknown object_type: {object_type}")
    return info["endpoint"]


def list_objects(client: NetBoxRestClient, object_type: str, filters: dict[str, Any] | None = None) -> list[dict]:
    params = (filters or {}).copy()
    params.setdefault("limit", 200)
    data = client.get(endpoint_for(object_type), params=params)
    return data.get("results", []) if isinstance(data, dict) else data


def find_object(client: NetBoxRestClient, object_type: str, filters: dict[str, Any]) -> dict | None:
    results = list_objects(client, object_type, filters)
    return results[0] if results else None


def create_object(client: NetBoxRestClient, object_type: str, payload: dict[str, Any]) -> dict:
    endpoint = endpoint_for(object_type)
    return client.create(endpoint, payload)


def update_object(client: NetBoxRestClient, object_type: str, object_id: int, payload: dict[str, Any]) -> dict:
    endpoint = endpoint_for(object_type)
    return client.update(endpoint, object_id, payload)


def ensure_site(client: NetBoxRestClient, name: str) -> dict:
    slug = name.lower().replace(" ", "-")
    existing = find_object(client, "dcim.site", {"slug": slug})
    if existing:
        return existing
    return create_object(
        client,
        "dcim.site",
        {"name": name, "slug": slug, "status": "active"},
    )


def ensure_manufacturer(client: NetBoxRestClient, name: str) -> dict:
    slug = name.lower().replace(" ", "-")
    existing = find_object(client, "dcim.manufacturer", {"slug": slug})
    if existing:
        return existing
    return create_object(
        client,
        "dcim.manufacturer",
        {"name": name, "slug": slug},
    )


def ensure_role(client: NetBoxRestClient, name: str) -> dict:
    slug = name.lower().replace(" ", "-")
    existing = find_object(client, "dcim.devicerole", {"slug": slug})
    if existing:
        return existing
    return create_object(
        client,
        "dcim.devicerole",
        {"name": name, "slug": slug, "vm_role": False},
    )


def ensure_device_type(client: NetBoxRestClient, name: str, manufacturer_id: int) -> dict:
    slug = name.lower().replace(" ", "-")
    existing = find_object(client, "dcim.devicetype", {"slug": slug})
    if existing:
        return existing
    return create_object(
        client,
        "dcim.devicetype",
        {
            "model": name,
            "slug": slug,
            "manufacturer": manufacturer_id,
            "part_number": name,
            "u_height": 1,
        },
    )


def ensure_device(
    client: NetBoxRestClient,
    name: str,
    site_id: int,
    role_id: int,
    device_type_id: int,
) -> dict:
    existing = find_object(client, "dcim.device", {"name": name})
    payload = {
        "site": site_id,
        "role": role_id,
        "device_type": device_type_id,
        "status": "active",
    }
    if existing:
        update_object(client, "dcim.device", existing["id"], payload)
        return existing
    payload["name"] = name
    return create_object(client, "dcim.device", payload)


def ensure_ip_address(
    client: NetBoxRestClient,
    address: str,
    device_id: int,
    description: str,
) -> dict:
    existing = find_object(client, "ipam.ipaddress", {"address": address})
    payload = {
        "address": address,
        "status": "active",
        "description": description,
        "assigned_object_type": "dcim.device",
        "assigned_object_id": device_id,
    }
    if existing:
        return existing
    try:
        return create_object(client, "ipam.ipaddress", payload)
    except Exception as exc:
        print(f'Failed to create IP {address}:', exc.response.text)
        raise




def main() -> None:
    netbox_url = os.environ["NETBOX_URL"]
    netbox_token = os.environ["NETBOX_TOKEN"]
    topology_path = Path("/home/ubuntu/AINetOps/containerlab/clab-aiops-lab/topology-data.json")
    if not topology_path.exists():
        raise SystemExit(f"Topology file not found: {topology_path}")

    with open(topology_path) as topo_file:
        topo = json.load(topo_file)

    client = NetBoxRestClient(netbox_url, netbox_token, verify_ssl=False)
    site = ensure_site(client, topo["name"])
    manufacturer = ensure_manufacturer(client, "Nokia")
    spine_role = ensure_role(client, "spine")
    leaf_role = ensure_role(client, "leaf")

    node_roles = {"spine": spine_role["id"], "leaf": leaf_role["id"]}
    node_types: dict[str, dict] = {}

    for node_name, node in topo["nodes"].items():
        device_type_name = (
            node.get("labels", {}).get("clab-node-type")
            or node.get("kind")
            or "unknown"
        )
        if device_type_name not in node_types:
            node_types[device_type_name] = ensure_device_type(
                client,
                device_type_name,
                manufacturer["id"],
            )

        role_key = "spine" if "spine" in node_name else "leaf"
        device = ensure_device(
            client,
            node_name,
            site["id"],
            node_roles[role_key],
            node_types[device_type_name]["id"],
        )

        mgmt_ip = node.get("mgmt-ipv4-address")
        mgmt_prefix = node.get("mgmt-ipv4-prefix-length")
        if mgmt_ip and mgmt_prefix:
            address = f"{mgmt_ip}/{mgmt_prefix}"
            description = f"mgmt for {node_name}"
            ip_obj = ensure_ip_address(
                client,
                address,
                device["id"],
                description,
            )
            update_object(
                client,
                "dcim.device",
                device["id"],
                {"primary_ip4": ip_obj["id"]},
            )

    print("NetBox sync complete: devices", list(topo["nodes"].keys()))


if __name__ == "__main__":
    main()
