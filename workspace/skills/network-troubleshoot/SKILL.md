---
name: network-troubleshoot
description: "Diagnose Nokia SR Linux network issues. Use when devices have connectivity problems, BGP peer drops, interface failures, or config drift."
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3"], "env": ["EXECUTOR_MCP_SCRIPT"] } } }
---

# Network Troubleshooting

Diagnose and resolve Nokia SR Linux device issues.

## Diagnostic Commands (via Executor MCP)

### Check interface state
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" get_running_config '{"device_name":"DEVICE","section":"interface IFACE"}'
```

### Check BGP neighbors
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" get_running_config '{"device_name":"DEVICE","section":"network-instance default protocols bgp"}'
```

### Check full running config
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" get_running_config '{"device_name":"DEVICE"}'
```

### Verify expected IP
```bash
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" verify_device_state '{"device_name":"DEVICE","interface_name":"IFACE","expected_ip":"IP/MASK"}'
```

## Troubleshooting Flow

1. **Gather** — query device state via `get_running_config` and `verify_device_state`
2. **Compare** — diff actual state against NetBox intent (use NetBox MCP)
3. **Diagnose** — identify root cause from the diff
4. **Propose** — suggest remediation commands
5. **Approve** — present fix to user, get explicit approval
6. **Execute** — use `push_config` MCP tool (with dry_run first)
7. **Verify** — re-run `verify_device_state` to confirm fix

## Common Symptoms

| Symptom | Check | Likely Cause |
|---------|-------|-------------|
| Interface down | `get_running_config` section `interface` | admin-state disabled |
| IP mismatch | `verify_device_state` | Config drift from intent |
| BGP peer down | `get_running_config` section BGP | Neighbor IP or ASN mismatch |
| No connectivity | Check both ends of link | Missing network-instance binding |

## Important Rules
- NEVER auto-remediate without explicit user approval
- Always dry-run before applying fixes
- Log all diagnostic findings
- If unsure, escalate to human operator
