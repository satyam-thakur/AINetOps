# AIOps with MCP

**AI-Powered Intent-Driven Network Automation Platform**

> A SOTA agentic platform following the Network Automation Forum (NAF) Framework.  
> Static Intent (NetBox) → Orchestration (OpenClaw + MCP) → Execution (NetClaw / Ansible / pyATS) → Observability (gNMIc + Prometheus + Grafana)

---

## Architecture (NAF Framework)

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                           │
│   OpenClaw ChatOps  │  Web Dashboard (future)                    │
├─────────────────────────────────────────────────────────────────┤
│                     ORCHESTRATION LAYER                          │
│   LLM (Claude) via OpenClaw Gateway + MCP                        │
├─────────────────────────────────────────────────────────────────┤
│  INTENT LAYER          │  EXECUTOR LAYER                         │
│  NetBox (IPAM/SoT)     │  Python executor (Netmiko)              │
│  Git (templates)       │  NetClaw Skills / Ansible (future)      │
├─────────────────────────────────────────────────────────────────┤
│                     OBSERVABILITY LAYER                          │
│   gNMIc → Prometheus → Grafana (future)                          │
├─────────────────────────────────────────────────────────────────┤
│                     INFRASTRUCTURE LAYER                         │
│   Containerlab (Nokia SR Linux spine/leaf)                        │
│   AWS EC2 (Terraform-managed)                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- Linux host with Docker + Docker Compose
- Containerlab installed (`curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"`)
- Python 3.11+
- Node.js 18+ (for OpenClaw)

### 1. Deploy the Lab Topology

```bash
sudo clab deploy -t containerlab/topology.clab.yaml
sudo clab inspect --name aiops-lab   # verify nodes running
```

### 2. Start NetBox (Source of Truth)

```bash
cd netbox/
docker compose up -d
# Wait ~2 minutes for first startup, then:
curl -s http://localhost:8000/api/status/ | python3 -m json.tool
```

### 3. Seed NetBox with Lab Data

```bash
pip install pynetbox
python netbox/seed_netbox.py
# Open http://localhost:8000 → login admin/admin → verify devices
```

### 4. Run the Executor (Phase 1 — Manual)

```bash
pip install -r requirements.txt
cd executor/
python executor.py              # full run: query + render + push + verify
python executor.py --dry-run    # render only, no push
python executor.py --verify-only # check current state vs NetBox
```

### 5. Install Agentic Orchestration (Phase 2 — OpenClaw + MCP)

```bash
bash scripts/install.sh
# Follow the OpenClaw onboard wizard (pick Anthropic, set API key)

# Start the agent:
openclaw gateway         # Terminal 1
openclaw tui             # Terminal 2 (interactive chat)

# Try these commands:
#   "What devices are in my lab?"
#   "Verify spine1 ethernet-1/1 has IP 10.0.0.0/31"
#   "Provision interface ethernet-1/1 on leaf1 with IP 10.0.0.1/31"
```

---

## Project Structure

```
AIOps/
├── containerlab/                    # Lab topology (digital twin)
│   ├── topology.clab.yaml           # 2-node spine/leaf SR Linux
│   └── configs/                     # Device startup configs
├── netbox/                          # Source of Truth
│   ├── docker-compose.yml           # NetBox + PostgreSQL + Redis
│   ├── .env                         # NetBox credentials
│   └── seed_netbox.py               # Populate baseline data
├── templates/                       # Jinja2 config templates (Git-managed)
│   ├── fabric_interface.j2          # SR Linux interface config
│   └── network_instance.j2          # SR Linux network instance
├── executor/                        # Python configuration executor
│   ├── executor.py                  # NetBox → Jinja2 → Netmiko → Verify
│   └── config.py                    # Configuration module
├── mcp_servers/                     # MCP servers (Phase 2)
│   └── executor_mcp/               # Custom Nokia SR Linux MCP tools
│       └── server.py               # provision, verify, get_running_config
├── workspace/                       # OpenClaw skills
│   └── skills/                      # Agentic skill definitions
│       ├── network-provision/       # Interface provisioning
│       ├── network-verify/          # State verification
│       └── network-inventory/       # NetBox inventory queries
├── scripts/                         # Automation scripts
│   ├── install.sh                   # Phase 2 installer
│   └── mcp-call.py                  # MCP stdio protocol handler
├── config/                          # OpenClaw configuration
│   └── openclaw.json                # Gateway config template
├── SOUL.md                          # Agent personality
├── AGENTS.md                        # Agent operating instructions
├── TOOLS.md                         # Lab infrastructure notes
├── requirements.txt                 # Python dependencies (all phases)
├── memory-bank/                     # Project context (gitignored)
│   └── project-plan.md              # NAF master plan
└── .env.example                     # Environment variable template
```

---

## Phases

| Phase | Objective | Status |
|---|---|---|
| **1: Foundational MVP** | Static Intent → Execution → Infra | ✅ Complete |
| **2: Agentic Orchestration** | OpenClaw + MCP + LLM | ✅ Implemented |
| **3: Observability** | gNMIc + Prometheus + Grafana | ⏳ Next |
| **4: Closed-Loop** | Dry-run, drift detection, self-healing | 🔜 |

---

## Reference Projects

- [NetworkOps_Platform](https://github.com/E-Conners-Lab/NetworkOps_Platform) — Dashboard, 178 MCP tools, React + Flask
- [NetClaw](https://github.com/automateyournetwork/netclaw) — 44 skills, 20 MCP servers, OpenClaw-based

---

## License

MIT