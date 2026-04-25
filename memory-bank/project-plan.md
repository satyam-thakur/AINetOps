# AINetOps Project Plan

This document is the master architectural specification and historical record for the AINetOps project. It is strictly aligned with the Network Automation Forum (NAF) framework and serves as the project's defining reference.

## 1. Goal

Build an enterprise-grade, AI-driven, closed-loop network automation platform. The system follows the NAF separation of concerns: declarative Intent → LLM-orchestrated execution → streaming observability → autonomous verification and self-healing.

## 2. NAF Functional Mapping (The Stack)

| NAF Layer | Technology | Purpose |
|---|---|---|
| **Intent (Data)** | NetBox | Dynamic SoT for inventory, IPAM, topology |
| **Intent (Code)** | Git (GitHub) | Version-controlled IaC: YAML variables + Jinja2 templates |
| **Orchestration** | OpenClaw + Claude (LLM) | Event-driven workflow coordination, webhook processing, reasoning |
| **Executor** | OpenClaw Skills + Executor MCP | Translate intent into device write-commands (Nokia SR Linux) |
| **Collector** | gNMIc | Streaming telemetry via gNMI (read interfaces) |
| **Observability** | Prometheus + Grafana | Time-series metrics persistence + visual dashboards |
| **Presentation** | OpenClaw Chat + Grafana | Conversational read/write + dashboard monitoring |
| **Infrastructure** | Containerlab (Nokia SR Linux) | Simulated spine-leaf topology, Docker-managed |

## 3. Primary Workflows

### A. GitOps Pipeline (Direct Code Entry)
1. Engineer modifies declarative YAML data (e.g., `configs/intent_config/`) and opens a PR.
2. CI/CD (GitHub Actions) lints syntax, renders Jinja2, runs a dry-run to generate a config diff.
3. Peer reviews the diff and merges the PR.
4. Git fires a webhook to the OpenClaw API → triggers the closed-loop executor.

### B. ChatOps Pipeline (AI-Assisted Entry)
1. Engineer prompts OpenClaw: *"Configure OSPF on Leaf-1."*
2. OpenClaw queries NetBox for available IPs.
3. OpenClaw drafts config using Jinja2 templates, opens a PR via Git MCP.
4. CI/CD dry-run executes; OpenClaw posts the diff to chat for approval.
5. On approval, PR merges → standard webhook to OpenClaw → closed-loop execution.

### C. Closed-Loop Execution (Sense → Logic → Act → Verify)
Once a PR merges (via either workflow):
1. **Act:** OpenClaw receives merge webhook, pushes config via Executor MCP.
2. **Document:** OpenClaw updates NetBox to reflect provisioned resources as "Active".
3. **Sense:** gNMIc detects state change, streams telemetry to Prometheus.
4. **Observe:** Prometheus persists the new operational state.
5. **Verify:** OpenClaw queries Prometheus to confirm actual state matches intent, reports to chat.

## 4. Implementation Phases & Progress

### Phase 1: Foundational MVP ✅
- Containerlab spine-leaf topology (spine1, leaf1, leaf2 — Nokia SR Linux).
- NetBox as SoT with seed data (site, devices, interfaces, IPs, VLANs, cables).
- Python executor: NetBox → Jinja2 → Netmiko SSH → Verify.

### Phase 2: Agentic Orchestration ✅
- OpenClaw Gateway + LLM integration.
- Executor MCP Server (`provision_interface`, `verify_device_state`, `get_running_config`).
- NetBox MCP Server for LLM-native intent queries.
- OpenClaw skills: `network-provision`, `network-verify`, `network-inventory`.

### Iteration 1–8: Architecture Refinement ✅
- **Iter 1:** Unified `configs/` structure (templates + intent YAML per device type).
- **Iter 2:** `deploy.py` (Jinja2 compile), `validate.py` (lint/dry-run), `push_config` MCP tool.
- **Iter 3:** `install.sh` rewrite with `uvx` for all MCP servers.
- **Iter 4:** Interactive `setup.sh` wizard for credentials and `.env`.
- **Iter 5:** GitHub MCP Server + `github-ops` skill.
- **Iter 6:** Skills layer expansion (`jinja2-config`, `config-validation`, `network-troubleshoot`).
- **Iter 7:** Observability stack (gNMIc + Prometheus + Grafana via Docker Compose).
- **Iter 8:** Documentation alignment (README, AGENTS, TOOLS, SOUL).

### Phase 3: Full Observability 🔜
- **3A:** Prometheus MCP Server (query tools: interface status, counters, protocol neighbors, PromQL).
- **3B:** `network-observe` OpenClaw skill for ChatOps telemetry queries.
- **3C:** Grafana alerting rules (InterfaceDown, ConfigDrift, HighErrorRate).

### Phase 4: Closed-Loop System 🔜
- **4A:** GitOps CI/CD pipeline (GitHub Actions: lint → dry-run → deploy on merge).
- **4B:** ChatOps pipeline (Git MCP: branch → edit YAML → PR → approve → merge).
- **4C:** Webhook listener (FastAPI) receiving Git merge + Grafana alert webhooks.
- **4D:** Closed-loop skills (`network-deploy`, `network-heal`): deploy → document → sense → verify.
- **4E:** Drift detection (`detect_drift` MCP tool) + self-healing with human approval gate.

## 5. Deferred / Future Enhancements
- Alertmanager integration for multi-channel notifications
- Automated `troubleshoot.py` execution from alert context
- `configs/known_issues.yaml` for symptom-to-remediation mappings
- Ephemeral Containerlab staging for pre-production dry-runs
- Multi-vendor support (Arista cEOS templates already scaffolded)

## 6. Maintenance
This file must be updated alongside every architectural change. It acts as the constitution for the project plan and its execution state.
