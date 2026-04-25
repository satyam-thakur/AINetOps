# Local Infrastructure — AIOps Lab

## Topology (Containerlab)
- **spine1**: Nokia SR Linux (ixr-d3l) — `clab-aiops-lab-spine1`
- **leaf1**: Nokia SR Linux (ixr-d2l) — `clab-aiops-lab-leaf1`
- **leaf2**: Nokia SR Linux (ixr-d2l) — `clab-aiops-lab-leaf2`
- **Fabric links**: 
  - spine1:e1-1 ↔ leaf1:e1-1
  - spine1:e1-2 ↔ leaf2:e1-1

## Credentials
- **Device SSH**: `admin` / `NokiaSrl1!`
- **NetBox API/UI**: `http://localhost:8000` / `admin` / `admin` / Token: `0123456789abcdef0123456789abcdef01234567`
- **Grafana**: `http://localhost:3000` / `admin` / `admin`
- **Prometheus**: `http://localhost:9090`

## Core Intent Data
- **Site**: `lab-dc1`
- **Devices**: spine1 (Spine), leaf1 (Leaf), leaf2 (Leaf)
- **Fabric IPs**: 
  - spine1:e1-1 = `10.0.0.0/31`, leaf1:e1-1 = `10.0.0.1/31`
  - spine1:e1-2 = `10.0.0.2/31`, leaf2:e1-1 = `10.0.0.3/31`
- **VLANs**: VLAN 10 (Data), VLAN 20 (Management)

## Configuration Layout (Plan & Compile)
- **Templates**: `configs/templates/nokia_srlinux/` and `configs/templates/arista_ceos/`
- **Intent**: `configs/intent_config/*.yaml`
- **Generated**: `configs/generated/*.cfg` (gitignored)
- **Deployment Script**: `python3 scripts/deploy.py --compile-only --device <dev>`
- **Validation Script**: `python3 scripts/validate.py --lint-only`

## MCP Sever Reference (Execute & Observe)
- **NetBox MCP**: `$NETBOX_MCP_SCRIPT` (run via `uvx` / `netbox-mcp-server`)
- **Executor MCP**: `$EXECUTOR_MCP_SCRIPT` (`mcp-servers/executor_mcp/server.py`)
- **GitHub MCP**: Docker `ghcr.io/github/github-mcp-server`
- **Containerlab MCP**: via `clab-mcp-server`
- **Call Script**: `$MCP_CALL` (`scripts/mcp-call.py`)

## Observability Stack
- **gNMIc**: Subscribed to SR Linux node telemetry (interfaces, BGP, system) on port 9804.
- **Prometheus**: Central metrics aggregator (port 9090).
- **Grafana**: Web UI monitoring dashboard (port 3000).
- Launch via: `cd observability && docker compose up -d`
