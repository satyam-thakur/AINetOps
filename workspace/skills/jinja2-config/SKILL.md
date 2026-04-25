---
name: jinja2-config
description: "Compile Nokia SR Linux and Arista/Cisco configs from Jinja2 templates and intent YAML. Use when generating, reviewing, or modifying device configurations."
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3"] } } }
---

# Jinja2 Config Compilation

Generate device configurations from templates and intent YAML data.

## Template Directory Layout

```
configs/templates/
├── nokia_srlinux/          # Nokia SR Linux (set commands)
│   ├── fabric_interface.j2
│   └── network_instance.j2
└── arista_ceos/            # Arista/Cisco IOS style
    ├── bgp.j2, ospf.j2, ospfv3.j2
    ├── interfaces.j2, vlan.j2, vlan_interfaces.j2
    ├── static_routes.j2, rip.j2
    ├── dhcp.j2, snmp.j2
```

## Intent YAML Schema (Nokia SR Linux)

```yaml
device:
  hostname: spine1
  type: ixr-d3l
  role: spine
  interfaces:
    - name: ethernet-1/1
      description: "to leaf1"
      subinterface_index: 1
      ipv4: 10.0.0.0/31
      network_instance: default
  network_instances:
    - name: default
      admin_state: enable
```

## Nokia SR Linux Template Variables

### fabric_interface.j2
| Variable | Type | Example |
|----------|------|---------|
| `interface_name` | str | `ethernet-1/1` |
| `description` | str | `to leaf1 e1-1` |
| `subinterface_index` | int | `1` |
| `ip_address` | str | `10.0.0.0/31` |

### network_instance.j2
| Variable | Type | Example |
|----------|------|---------|
| `network_instance` | str | `default` |
| `interface_name` | str | `ethernet-1/1` |
| `subinterface_index` | int | `1` |

## Compile Workflow

```bash
# Compile all devices
python3 scripts/deploy.py --compile-only

# Compile single device
python3 scripts/deploy.py --compile-only --device spine1

# Output goes to configs/generated/<device>.cfg
```

## Push via MCP (after compile)

```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" push_config '{"device_name":"spine1","dry_run":true}'
```
