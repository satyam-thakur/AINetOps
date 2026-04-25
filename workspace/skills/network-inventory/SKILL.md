---
name: network-inventory
description: "Query lab inventory from NetBox — devices, interfaces, IPs, VLANs, cables"
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3"], "env": ["NETBOX_MCP_SCRIPT"] } } }
---

# Network Inventory

Query the AIOps lab inventory from NetBox source of truth.

## NetBox Tools Reference

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| `netbox_get_objects` | Bulk query objects by type | `object_type`, `filters`, `limit`, `brief` |
| `netbox_get_object_by_id` | Get single object by ID | `object_type`, `object_id` |
| `netbox_search_objects` | Global text search | `query`, `object_types` |

## Common Queries

### List all devices
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.devices","filters":{"status":"active"},"brief":true}'
```

### List interfaces for a device
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.interfaces","filters":{"device":"spine1"}}'
```

### List IP addresses
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"ipam.ip-addresses","filters":{"device":"spine1"}}'
```

### List VLANs
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"ipam.vlans"}'
```

### List cables
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.cables"}'
```

### List sites
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.sites"}'
```

### Search for anything
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_search_objects '{"query":"spine1"}'
```
