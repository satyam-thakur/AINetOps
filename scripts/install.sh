#!/usr/bin/env bash
# AIOps Installation Script — Full MCP Server Setup
# Clones, builds, and configures all MCP servers for the AINetOps platform
#
# Modeled after: netclaw/scripts/install.sh
# MCP servers are run via uvx for fast, isolated execution

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        log_info "$1 found: $(command -v "$1")"
        return 0
    else
        log_error "$1 not found"
        return 1
    fi
}

clone_or_pull() {
    local dir="$1" url="$2"
    if [ -d "$dir" ]; then
        log_info "Already cloned. Pulling latest..."
        git -C "$dir" pull --quiet 2>/dev/null || log_warn "git pull failed, using existing version"
    else
        log_info "Cloning from $url..."
        git clone "$url" "$dir"
    fi
}

AIOPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="$AIOPS_DIR/mcp-servers"
TOTAL_STEPS=14

echo "========================================="
echo "  AINetOps — Full Installation"
echo "  OpenClaw + MCP Servers (via uvx)"
echo "========================================="
echo ""
echo "  Project: $AIOPS_DIR"
echo ""

# ═══════════════════════════════════════════
# Step 1: Check Prerequisites
# ═══════════════════════════════════════════

log_step "1/$TOTAL_STEPS Checking prerequisites..."

MISSING=0

# Node.js
if ! check_command node; then
    log_error "Node.js is required (>= 18). Install from https://nodejs.org/"
    MISSING=1
else
    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js >= 18 required. Found: $(node --version)"
        MISSING=1
    else
        log_info "Node.js version: $(node --version)"
    fi
fi

for cmd in npm npx python3 git; do
    if ! check_command "$cmd"; then
        MISSING=1
    fi
done

# pip
if ! check_command pip3; then
    if ! check_command pip; then
        log_error "pip3 is required for Python package installation"
        MISSING=1
    fi
fi

# uv / uvx
if ! check_command uv; then
    log_warn "uv not found — installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
        log_error "Failed to install uv. Install manually: https://docs.astral.sh/uv/"
        MISSING=1
    }
    # Source the new PATH
    export PATH="$HOME/.local/bin:$PATH"
    if check_command uv; then
        log_info "uv installed successfully"
    else
        log_error "uv still not found after install"
        MISSING=1
    fi
fi

if ! check_command uvx; then
    log_warn "uvx not found on PATH (should be installed with uv)"
    log_info "Trying: export PATH=\"\$HOME/.local/bin:\$PATH\""
    export PATH="$HOME/.local/bin:$PATH"
fi

# Docker (optional, for GitHub MCP)
if check_command docker; then
    log_info "Docker available (used for GitHub MCP server)"
else
    log_warn "Docker not found — GitHub MCP will need Docker later"
fi

if [ "$MISSING" -eq 1 ]; then
    log_error "Missing prerequisites. Please install them and re-run this script."
    exit 1
fi

log_info "All prerequisites satisfied."
echo ""

# ═══════════════════════════════════════════
# Step 2: Install OpenClaw
# ═══════════════════════════════════════════

log_step "2/$TOTAL_STEPS Installing OpenClaw..."

if command -v openclaw &> /dev/null; then
    log_info "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"
else
    log_info "Installing OpenClaw via npm..."
    npm install -g openclaw@latest
    if command -v openclaw &> /dev/null; then
        log_info "OpenClaw installed successfully"
    else
        log_error "openclaw not found on PATH after install"
        log_warn "Try: export PATH=\"$(npm config get prefix)/bin:\$PATH\""
    fi
fi

echo ""

# ═══════════════════════════════════════════
# Step 3: OpenClaw Onboard
# ═══════════════════════════════════════════

log_step "3/$TOTAL_STEPS Running OpenClaw onboard..."

echo ""
echo "  This is OpenClaw's built-in setup wizard."
echo "  Pick your AI provider and set your API key."
echo ""

if command -v openclaw &> /dev/null; then
    openclaw onboard --install-daemon || {
        log_warn "openclaw onboard exited with an error."
        log_warn "You can re-run it later: openclaw onboard --install-daemon"
    }
    log_info "OpenClaw onboard complete"
else
    log_error "openclaw command not found — skipping onboard"
    log_warn "After fixing your PATH, run: openclaw onboard --install-daemon"
fi

echo ""

# ═══════════════════════════════════════════
# Step 4: Create mcp-servers directory
# ═══════════════════════════════════════════

log_step "4/$TOTAL_STEPS Setting up MCP servers directory..."

mkdir -p "$MCP_DIR"
log_info "MCP servers directory: $MCP_DIR"
echo ""

# ═══════════════════════════════════════════
# Step 5: NetBox MCP Server
# ═══════════════════════════════════════════

log_step "5/$TOTAL_STEPS Installing NetBox MCP Server..."
echo "  Source: https://github.com/netboxlabs/netbox-mcp-server"
echo "  Run: uvx --from netbox-mcp-server netbox-mcp-server"

NETBOX_MCP_DIR="$MCP_DIR/netbox-mcp-server"
clone_or_pull "$NETBOX_MCP_DIR" "https://github.com/netboxlabs/netbox-mcp-server.git"

log_info "NetBox MCP ready (run via uvx)"

echo ""

# ═══════════════════════════════════════════
# Step 6: NetBox RW MCP Server
# ═══════════════════════════════════════════

log_step "6/$TOTAL_STEPS Installing NetBox RW MCP Server..."
echo "  Source: https://github.com/alexkiwi1/netbox-mcp-rw.git"
echo "  Run: uvx --from netbox-mcp-rw netbox-mcp-rw"

NETBOX_RW_MCP_DIR="$MCP_DIR/netbox-mcp-rw"
clone_or_pull "$NETBOX_RW_MCP_DIR" "https://github.com/alexkiwi1/netbox-mcp-rw.git"

log_info "NetBox RW MCP ready (run via uvx)"

echo ""

# ═══════════════════════════════════════════
# Step 7: GitHub MCP Server
# ═══════════════════════════════════════════

log_step "6/$TOTAL_STEPS Installing GitHub MCP Server..."
echo "  Source: https://github.com/github/github-mcp-server"
echo "  Auth: GITHUB_PERSONAL_ACCESS_TOKEN"

GITHUB_MCP_DIR="$MCP_DIR/github-mcp-server"
clone_or_pull "$GITHUB_MCP_DIR" "https://github.com/github/github-mcp-server.git"

# Also pull Docker image if Docker available
if command -v docker &> /dev/null; then
    log_info "Pulling GitHub MCP Server Docker image..."
    docker pull ghcr.io/github/github-mcp-server 2>/dev/null || \
        log_warn "Could not pull Docker image — will pull on first use"
    log_info "GitHub MCP ready: docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server"
else
    log_info "GitHub MCP cloned — Docker pull skipped (Docker not available)"
fi

echo ""

# ═══════════════════════════════════════════
# Step 7: Containerlab MCP Server
# ═══════════════════════════════════════════

log_step "7/$TOTAL_STEPS Installing Containerlab MCP Server..."
echo "  Source: https://github.com/seanerama/clab-mcp-server"

CLAB_MCP_DIR="$MCP_DIR/clab-mcp-server"
clone_or_pull "$CLAB_MCP_DIR" "https://github.com/seanerama/clab-mcp-server.git"

log_info "Containerlab MCP ready (run via uvx)"

echo ""

# ═══════════════════════════════════════════
# Step 8: Executor MCP dependencies
# ═══════════════════════════════════════════

log_step "8/$TOTAL_STEPS Installing Executor MCP dependencies..."

pip3 install -r "$AIOPS_DIR/requirements.txt" 2>/dev/null || \
    log_warn "Some executor deps failed — run via uvx for isolated env"

log_info "Executor MCP ready: $AIOPS_DIR/mcp-servers/executor_mcp/server.py"
log_info "  Run: uvx --from . python3 server.py  (or python3 -u server.py)"

echo ""

# ═══════════════════════════════════════════
# Step 9: Copy MCP call script
# ═══════════════════════════════════════════

log_step "9/$TOTAL_STEPS Setting up MCP call script..."

if [ -f "$AIOPS_DIR/scripts/mcp-call.py" ]; then
    log_info "mcp-call.py already present"
else
    NETCLAW_DIR="${NETCLAW_DIR:-/home/ubuntu/netclaw}"
    if [ -f "$NETCLAW_DIR/scripts/mcp-call.py" ]; then
        cp "$NETCLAW_DIR/scripts/mcp-call.py" "$AIOPS_DIR/scripts/mcp-call.py"
        log_info "Copied mcp-call.py from NetClaw"
    else
        log_warn "mcp-call.py not found"
    fi
fi

echo ""

# ═══════════════════════════════════════════
# Step 10: Deploy workspace files
# ═══════════════════════════════════════════

log_step "10/$TOTAL_STEPS Deploying workspace and skills..."

OPENCLAW_DIR="$HOME/.openclaw"
if [ ! -d "$OPENCLAW_DIR" ]; then
    log_info "OpenClaw directory not found. Bootstrapping..."
    mkdir -p "$OPENCLAW_DIR/workspace/skills"
    mkdir -p "$OPENCLAW_DIR/agents/main/sessions"
    log_info "Created $OPENCLAW_DIR"
fi

# Deploy workspace MD files
for mdfile in SOUL.md AGENTS.md TOOLS.md; do
    if [ -f "$AIOPS_DIR/$mdfile" ]; then
        cp "$AIOPS_DIR/$mdfile" "$OPENCLAW_DIR/workspace/$mdfile"
        log_info "Deployed $mdfile to workspace"
    fi
done

# Deploy skills
mkdir -p "$OPENCLAW_DIR/workspace/skills"
if [ -d "$AIOPS_DIR/workspace/skills" ]; then
    cp -r "$AIOPS_DIR/workspace/skills/"* "$OPENCLAW_DIR/workspace/skills/" 2>/dev/null || true
    log_info "Deployed AIOps skills to workspace"
fi

# Copy github-ops skill from NetClaw (if available)
NETCLAW_DIR="${NETCLAW_DIR:-/home/ubuntu/netclaw}"
if [ -d "$NETCLAW_DIR/workspace/skills/github-ops" ]; then
    cp -r "$NETCLAW_DIR/workspace/skills/github-ops" "$OPENCLAW_DIR/workspace/skills/"
    log_info "Copied github-ops skill from NetClaw"
fi

echo ""

# ═══════════════════════════════════════════
# Step 11: Set environment variables
# ═══════════════════════════════════════════

log_step "11/$TOTAL_STEPS Configuring environment..."

OPENCLAW_ENV="$OPENCLAW_DIR/.env"
[ -f "$OPENCLAW_ENV" ] || touch "$OPENCLAW_ENV"

NETBOX_MCP_SCRIPT="$NETBOX_MCP_DIR/src/netbox_mcp_server/server.py"
EXECUTOR_MCP_SCRIPT="$AIOPS_DIR/mcp-servers/executor_mcp/server.py"
MCP_CALL_SCRIPT="$AIOPS_DIR/scripts/mcp-call.py"

declare -A ENV_VARS=(
    ["MCP_CALL"]="$MCP_CALL_SCRIPT"
    ["NETBOX_MCP_SCRIPT"]="$NETBOX_MCP_SCRIPT"
    ["EXECUTOR_MCP_SCRIPT"]="$EXECUTOR_MCP_SCRIPT"
    ["NETBOX_URL"]="http://localhost:8000"
    ["NETBOX_TOKEN"]="0123456789abcdef0123456789abcdef01234567"
    ["DEVICE_USERNAME"]="admin"
    ["DEVICE_PASSWORD"]="NokiaSrl1!"
    ["CLAB_LAB_NAME"]="aiops-lab"
)

for key in "${!ENV_VARS[@]}"; do
    if grep -q "^${key}=" "$OPENCLAW_ENV" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${ENV_VARS[$key]}|" "$OPENCLAW_ENV"
    else
        echo "${key}=${ENV_VARS[$key]}" >> "$OPENCLAW_ENV"
    fi
done

# Remind about API keys
if ! grep -q "^ANTHROPIC_API_KEY=" "$OPENCLAW_ENV" 2>/dev/null && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "" >> "$OPENCLAW_ENV"
    echo "# ANTHROPIC_API_KEY=sk-ant-your-key-here" >> "$OPENCLAW_ENV"
    log_warn "ANTHROPIC_API_KEY not set. Add it to $OPENCLAW_ENV or export it."
fi

if ! grep -q "^GITHUB_PERSONAL_ACCESS_TOKEN=" "$OPENCLAW_ENV" 2>/dev/null; then
    echo "# GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your-token-here" >> "$OPENCLAW_ENV"
    log_warn "GITHUB_PERSONAL_ACCESS_TOKEN not set. Add it for GitHub MCP."
fi

log_info "Set ${#ENV_VARS[@]} environment variables in $OPENCLAW_ENV"

echo ""

# ═══════════════════════════════════════════
# Step 12: Install Python dependencies
# ═══════════════════════════════════════════

log_step "12/$TOTAL_STEPS Installing Python project dependencies..."

pip3 install -r "$AIOPS_DIR/requirements.txt" 2>/dev/null || \
    log_warn "Some Python deps failed (use uvx for isolated runs)"

echo ""

# ═══════════════════════════════════════════
# Step 13: Verify installation
# ═══════════════════════════════════════════

log_step "13/$TOTAL_STEPS Verifying installation..."

SERVERS_OK=0
SERVERS_FAIL=0

verify_dir() {
    local name="$1" path="$2"
    if [ -d "$path" ]; then
        log_info "$name: OK ($path)"
        SERVERS_OK=$((SERVERS_OK + 1))
    else
        log_error "$name: MISSING ($path)"
        SERVERS_FAIL=$((SERVERS_FAIL + 1))
    fi
}

verify_file() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        log_info "$name: OK"
        SERVERS_OK=$((SERVERS_OK + 1))
    else
        log_error "$name: MISSING ($path)"
        SERVERS_FAIL=$((SERVERS_FAIL + 1))
    fi
}

verify_dir "NetBox MCP" "$NETBOX_MCP_DIR"
verify_dir "GitHub MCP" "$GITHUB_MCP_DIR"
verify_dir "Containerlab MCP" "$CLAB_MCP_DIR"
verify_file "Executor MCP" "$EXECUTOR_MCP_SCRIPT"
verify_file "MCP Call Script" "$MCP_CALL_SCRIPT"
verify_file "deploy.py" "$AIOPS_DIR/scripts/deploy.py"
verify_file "validate.py" "$AIOPS_DIR/scripts/validate.py"

echo ""
log_info "Verification: $SERVERS_OK OK, $SERVERS_FAIL FAILED"
echo ""

# ═══════════════════════════════════════════
# Step 14: Summary
# ═══════════════════════════════════════════

log_step "14/$TOTAL_STEPS Installation Summary"
echo ""
echo "========================================="
echo "  AINetOps Installation Complete"
echo "========================================="
echo ""

SKILL_COUNT=$(ls -d "$OPENCLAW_DIR/workspace/skills/"*/ 2>/dev/null | wc -l)

echo "MCP Servers (run via uvx):"
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ NetBox MCP        Read-only DCIM/IPAM (netboxlabs)"
echo "  │ GitHub MCP        PRs, issues, code search (GitHub official)"
echo "  │ Containerlab MCP  Lab topology management (seanerama)"
echo "  │ Executor MCP      Nokia SR Linux config via SSH (local)"
echo "  └──────────────────────────────────────────────────────"
echo ""
echo "Skills Deployed ($SKILL_COUNT):"
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ network-provision   Interface provisioning"
echo "  │ network-verify      State verification"
echo "  │ network-inventory   NetBox inventory queries"
if [ -d "$OPENCLAW_DIR/workspace/skills/github-ops" ]; then
echo "  │ github-ops          GitHub PR/issue workflows"
fi
echo "  └──────────────────────────────────────────────────────"
echo ""
echo "Scripts:"
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ deploy.py     Compile templates (python3 scripts/deploy.py --compile-only)"
echo "  │ validate.py   Lint & validate   (python3 scripts/validate.py --lint-only)"
echo "  └──────────────────────────────────────────────────────"
echo ""
echo "Next Steps:"
echo "  1. Set your API keys:"
echo "     export ANTHROPIC_API_KEY=sk-ant-..."
echo "     export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_..."
echo "     # Or add to ~/.openclaw/.env"
echo ""
echo "  2. Run interactive setup:"
echo "     bash scripts/setup.sh"
echo ""
echo "  3. Ensure infrastructure is running:"
echo "     cd netbox-docker && docker compose up -d"
echo "     sudo clab deploy -t containerlab/topology.clab.yaml"
echo ""
echo "  4. Start OpenClaw:"
echo "     openclaw gateway   # Terminal 1"
echo "     openclaw tui       # Terminal 2 (interactive chat)"
echo ""
echo "  5. Try a command:"
echo "     \"What devices are in my lab?\""
echo "     \"Compile configs for spine1\""
echo ""
