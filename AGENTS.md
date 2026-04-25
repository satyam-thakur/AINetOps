# Operating Instructions

## NAF Toolchain Mapping
You govern the platform using specific MCP tool integrations based on the NAF functional mapping.

### Intent (Data & Code)
* **NetBox MCP**: Read-only queries for IPAM/DCIM intent mapping.
* **GitHub MCP**: PRs, issues, code search for config-as-code versioning.

### Plan & Compile
Executed locally using CLI scripts.
* `python3 scripts/validate.py --device DEVICE`
* `python3 scripts/deploy.py --compile-only --device DEVICE`

### Apply & Execute
**Executor MCP**: Device configuration via candidate mode commits.
All MCP tools are called via `scripts/mcp-call.py` (stdio).
```bash
# Push compiled config (dry_run)
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" push_config '{"device_name":"spine1","dry_run":true}'
# Push compiled config (live)
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" push_config '{"device_name":"spine1"}'
# Verify state after push
python3 $MCP_CALL "python3 -u $EXECUTOR_MCP_SCRIPT" verify_device_state '{"device_name":"spine1","interface_name":"ethernet-1/1","expected_ip":"10.0.0.1/31"}'
```

### Observe
* **Containerlab MCP**: Topology discovery and node states.
* **Grafana / Prometheus**: Metric queries and observability dashboards.

## Standard "Plan & Apply" Workflow
1. **[INTENT]** Query NetBox/YAML for the intended device state and IPs.
2. **[VERIFY]** Check the current device state before attempting changes to detect drift.
3. **[PLAN]** Use `scripts/deploy.py` to compile configuration for the device. Present diffs/compiled configuration to user for review.
4. **[EXECUTE]** Use the `push_config` MCP tool with `dry_run: true` to test candidate commit process. Upon approval, run without `dry_run`.
5. **[VERIFY]** Rerun verification tools to ensure device state matches the explicit intent.
6. **Report** status to the user in a consolidated summary table.

## Error Handling
- **Agent/SSH Error**: If connection fails, check Containerlab via MCP or `docker ps`.
- **Commit Error**: If `commit now` fails on the SR Linux side, read the error message clearly, identify the syntax/dependency issue, and fix the Jinja2 template or YAML intent. Do NOT retry blindly.
