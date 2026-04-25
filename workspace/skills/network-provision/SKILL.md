---
name: network-provision
description: "Provision network interfaces on Nokia SR Linux devices from NetBox intent"
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3"], "env": ["NETBOX_MCP_SCRIPT", "EXECUTOR_MCP_SCRIPT"] } } }
---

# Interface Provisioning

Configure device interfaces with IP addresses based on NetBox intent.

## How to Call the Tools

### NetBox MCP (query intent)
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.devices","filters":{"status":"active"}}'
```

### Executor MCP (push config)
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" provision_interface '{"device_name":"DEVICE","interface_name":"IFACE","ip_address":"IP/MASK"}'
```

## Workflow

### Step 1: Query NetBox for target device
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.devices","filters":{"name":"DEVICE_NAME"}}'
```

### Step 2: Get interfaces and IPs from NetBox
```bash
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"dcim.interfaces","filters":{"device":"DEVICE_NAME"}}'
python3 $MCP_CALL "python3 -u $NETBOX_MCP_SCRIPT" netbox_get_objects '{"object_type":"ipam.ip-addresses","filters":{"device":"DEVICE_NAME"}}'
```

### Step 3: Verify current state BEFORE changes
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" verify_device_state '{"device_name":"DEVICE","interface_name":"IFACE","expected_ip":"IP/MASK"}'
```

### Step 3b: Compile and push via deploy.py + MCP (alternative)
```bash
# Compile intent to config
python3 scripts/deploy.py --compile-only --device DEVICE

# Push compiled config (dry-run first)
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" push_config '{"device_name":"DEVICE","dry_run":true}'

# Push for real (after user confirms)
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" push_config '{"device_name":"DEVICE"}'
```

### Step 4: Provision (direct MCP, or use Step 3b)
```bash
# Dry run
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" provision_interface '{"device_name":"DEVICE","interface_name":"IFACE","ip_address":"IP/MASK","dry_run":true}'

# Actual push (after user confirms)
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" provision_interface '{"device_name":"DEVICE","interface_name":"IFACE","ip_address":"IP/MASK","description":"DESCRIPTION"}'
```

### Step 5: Verify AFTER changes
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" verify_device_state '{"device_name":"DEVICE","interface_name":"IFACE","expected_ip":"IP/MASK"}'
```

### Step 6: Report results
```
Provisioning Report - DEVICE
Interface: IFACE
Intended IP: IP/MASK (from NetBox)
Applied IP: IP/MASK
Status: PASS ✓
```
