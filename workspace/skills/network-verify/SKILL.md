---
name: network-verify
description: "Verify actual device state matches NetBox source of truth intent"
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3"], "env": ["NETBOX_MCP_SCRIPT", "EXECUTOR_MCP_SCRIPT"] } } }
---

# State Verification

Compare actual Nokia SR Linux device state against NetBox intent.

## Workflow

### Step 1: Get all devices from NetBox
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.devices","filters":{"status":"active"},"brief":true}'
```

### Step 2: For each device, get intended IPs from NetBox
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"ipam.ip-addresses","filters":{"device":"DEVICE_NAME"}}'
```

### Step 3: Verify each interface against intent
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" verify_device_state '{"device_name":"DEVICE","interface_name":"IFACE","expected_ip":"IP/MASK"}'
```

### Step 4: Report

```
Verification Report
┌──────────┬──────────────┬─────────────┬─────────────┬────────┐
│ Device   │ Interface    │ Intended IP │ Actual IP   │ Status │
├──────────┼──────────────┼─────────────┼─────────────┼────────┤
│ spine1   │ ethernet-1/1 │ 10.0.0.0/31 │ 10.0.0.0/31 │ PASS   │
│ leaf1    │ ethernet-1/1 │ 10.0.0.1/31 │ 10.0.0.1/31 │ PASS   │
└──────────┴──────────────┴─────────────┴─────────────┴────────┘
```
