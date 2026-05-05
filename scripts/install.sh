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

ensure_local_paths() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if [[ ":$PATH:" != *":$HOME/.local/npm/bin:"* ]]; then
        export PATH="$HOME/.local/npm/bin:$PATH"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        log_error "sudo not available. Run as root to install packages."
        return 1
    fi
}

detect_pkg_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo ""
    fi
}

APT_UPDATED=0
APT_OPTS=(
    -o Acquire::ForceIPv4=true
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=20
    -o Acquire::https::Timeout=20
)
APT_MIRROR_CHECKED=0
APT_SECURITY_MIRROR="http://us-west-2.ec2.archive.ubuntu.com/ubuntu"
NODE_REQUIRED_MAJOR=22
NODE_SETUP_URL="https://deb.nodesource.com/setup_22.x"
SKIPPED_ITEMS=()
DEFAULT_INSTALL_YES=1

confirm_install() {
    local label="$1"
    local reply
    while true; do
        if [ "$DEFAULT_INSTALL_YES" -eq 1 ]; then
            read -r -p "Install ${label}? [Y/n] " reply
        else
            read -r -p "Install ${label}? [y/N] " reply
        fi
        case "$reply" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO])
                return 1
                ;;
            "")
                if [ "$DEFAULT_INSTALL_YES" -eq 1 ]; then
                    return 0
                fi
                return 1
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

confirm_action() {
    local prompt="$1"
    local reply
    while true; do
        if [ "$DEFAULT_INSTALL_YES" -eq 1 ]; then
            read -r -p "${prompt} [Y/n] " reply
        else
            read -r -p "${prompt} [y/N] " reply
        fi
        case "$reply" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO])
                return 1
                ;;
            "")
                if [ "$DEFAULT_INSTALL_YES" -eq 1 ]; then
                    return 0
                fi
                return 1
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

ensure_apt_security_mirror() {
    if [ "$APT_MIRROR_CHECKED" -eq 1 ]; then
        return 0
    fi
    APT_MIRROR_CHECKED=1

    if ! command_exists curl; then
        return 0
    fi

    if curl -fsS --max-time 5 "http://security.ubuntu.com/ubuntu/dists/jammy/InRelease" >/dev/null 2>&1; then
        return 0
    fi

    log_warn "security.ubuntu.com appears slow or unreachable."
    if confirm_action "Switch security mirror to ${APT_SECURITY_MIRROR}?"; then
        local old_shopt
        old_shopt=$(shopt -p nullglob)
        shopt -s nullglob
        local files=(/etc/apt/sources.list /etc/apt/sources.list.d/*.list)
        eval "$old_shopt"
        if [ "${#files[@]}" -gt 0 ]; then
            as_root sed -i "s|http://security.ubuntu.com/ubuntu|${APT_SECURITY_MIRROR}|g" "${files[@]}" || return 1
            log_info "Updated security mirror to ${APT_SECURITY_MIRROR}"
        fi
    fi
    return 0
}

add_skipped() {
    local label="$1"
    SKIPPED_ITEMS+=("$label")
}

install_packages() {
    local pm="$1"
    shift
    local pkgs=("$@")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        return 0
    fi

    case "$pm" in
        apt)
            if [ "$APT_UPDATED" -eq 0 ]; then
                ensure_apt_security_mirror || return 1
                as_root apt-get "${APT_OPTS[@]}" update || return 1
                APT_UPDATED=1
            fi
            as_root apt-get "${APT_OPTS[@]}" install -y "${pkgs[@]}" || return 1
            ;;
        dnf)
            as_root dnf install -y "${pkgs[@]}" || return 1
            ;;
        yum)
            as_root yum install -y "${pkgs[@]}" || return 1
            ;;
        pacman)
            as_root pacman -Sy --noconfirm "${pkgs[@]}" || return 1
            ;;
        zypper)
            as_root zypper --non-interactive install "${pkgs[@]}" || return 1
            ;;
        *)
            log_error "No supported package manager found."
            return 1
            ;;
    esac
}

remove_packages() {
    local pm="$1"
    shift
    local pkgs=("$@")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        return 0
    fi

    case "$pm" in
        apt)
            as_root apt-get "${APT_OPTS[@]}" remove -y "${pkgs[@]}" || return 1
            ;;
        dnf)
            as_root dnf remove -y "${pkgs[@]}" || return 1
            ;;
        yum)
            as_root yum remove -y "${pkgs[@]}" || return 1
            ;;
        pacman)
            as_root pacman -Rns --noconfirm "${pkgs[@]}" || return 1
            ;;
        zypper)
            as_root zypper --non-interactive remove "${pkgs[@]}" || return 1
            ;;
        *)
            log_error "No supported package manager found."
            return 1
            ;;
    esac
}

ensure_command() {
    local cmd="$1"
    local pm="$2"
    shift 2
    local pkgs=("$@")

    if command_exists "$cmd"; then
        log_info "$cmd found: $(command -v "$cmd")"
        return 0
    fi

    log_warn "$cmd not found. Installing: ${pkgs[*]}"
    if ! confirm_install "${pkgs[*]}"; then
        log_warn "Skipping install: ${pkgs[*]}"
        add_skipped "${pkgs[*]}"
        return 2
    fi
    if ! install_packages "$pm" "${pkgs[@]}"; then
        log_error "Failed to install: ${pkgs[*]}"
        return 1
    fi

    if command_exists "$cmd"; then
        log_info "$cmd found: $(command -v "$cmd")"
        return 0
    fi

    log_error "$cmd not found after install"
    return 1
}

ensure_node() {
    local pm="$1"
    local node_major
    local need_install=1

    if command_exists node; then
        node_major=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$node_major" -ge "$NODE_REQUIRED_MAJOR" ]; then
            need_install=0
        else
            log_warn "Node.js ${NODE_REQUIRED_MAJOR}+ required. Found: $(node --version)"
            if confirm_install "remove Node.js ${node_major}"; then
                if ! remove_packages "$pm" nodejs npm; then
                    log_error "Failed to remove old Node.js packages"
                    return 1
                fi
            else
                log_warn "Skipping removal of old Node.js"
                add_skipped "remove Node.js ${node_major}"
                return 2
            fi
        fi
    fi

    if [ "$need_install" -eq 1 ]; then
        log_warn "Installing Node.js >= ${NODE_REQUIRED_MAJOR}..."
        if ! confirm_install "Node.js ${NODE_REQUIRED_MAJOR}+"; then
            log_warn "Skipping install: Node.js ${NODE_REQUIRED_MAJOR}+"
            add_skipped "Node.js ${NODE_REQUIRED_MAJOR}+"
            return 2
        fi
        if [ "$pm" = "apt" ]; then
            install_packages "$pm" curl ca-certificates gnupg || return 1
            curl -fsSL "$NODE_SETUP_URL" | as_root bash - &> /dev/null || {
                log_error "Failed to configure NodeSource repo for Node.js ${NODE_REQUIRED_MAJOR}."
                return 1
            }
            install_packages "$pm" nodejs || return 1
        else
            install_packages "$pm" nodejs npm || return 1
        fi
    fi

    if ! command_exists node; then
        log_error "Node.js not found after installation."
        return 1
    fi

    node_major=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$node_major" -lt "$NODE_REQUIRED_MAJOR" ]; then
        log_error "Node.js >= ${NODE_REQUIRED_MAJOR} required. Found: $(node --version)"
        return 1
    fi

    if ! command_exists npm; then
        if confirm_install "npm"; then
            install_packages "$pm" npm || return 1
        else
            log_warn "Skipping install: npm"
            add_skipped "npm"
            return 2
        fi
    fi

    if ! command_exists npx; then
        if confirm_install "npx"; then
            install_packages "$pm" npm || return 1
        else
            log_warn "Skipping install: npx"
            add_skipped "npx"
            return 2
        fi
    fi

    log_info "Node.js version: $(node --version)"
    log_info "npm found: $(command -v npm)"
    log_info "npx found: $(command -v npx)"
    return 0
}

ensure_uvx() {
    ensure_local_paths
    if command_exists uv && command_exists uvx; then
        log_info "uv found: $(command -v uv)"
        log_info "uvx found: $(command -v uvx)"
        return 0
    fi

    if ! confirm_install "uv/uvx"; then
        log_warn "Skipping install: uv/uvx"
        add_skipped "uv/uvx"
        return 2
    fi

    log_warn "uv not found — installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
        log_error "Failed to install uv. Install manually: https://docs.astral.sh/uv/"
        return 1
    }

    export PATH="$HOME/.local/bin:$PATH"
    if command_exists uv && command_exists uvx; then
        log_info "uv found: $(command -v uv)"
        log_info "uvx found: $(command -v uvx)"
        return 0
    fi

    log_error "uv/uvx not found after install"
    return 1
}

ensure_docker() {
    local pm="$1"
    if command_exists docker; then
        log_info "Docker found: $(command -v docker)"
        return 0
    fi

    if ! confirm_install "docker"; then
        log_warn "Skipping install: docker"
        add_skipped "docker"
        return 2
    fi

    log_warn "Docker not found — installing..."
    case "$pm" in
        apt)
            install_packages "$pm" docker.io || return 1
            ;;
        dnf|yum)
            install_packages "$pm" docker || return 1
            ;;
        pacman)
            install_packages "$pm" docker || return 1
            ;;
        zypper)
            install_packages "$pm" docker || return 1
            ;;
        *)
            log_error "No supported package manager found for Docker install."
            return 1
            ;;
    esac

    if command_exists docker; then
        log_info "Docker installed: $(command -v docker)"
        return 0
    fi

    log_error "Docker not found after install"
    return 1
}

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

ensure_local_paths

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

PKG_MGR="$(detect_pkg_manager)"
if [ -z "$PKG_MGR" ]; then
    log_error "No supported package manager found (apt-get, dnf, yum, pacman, zypper)."
    exit 1
fi

MISSING=0
OPENCLAW_OK=1
SKIPPED=0

# Base tools
ensure_command curl "$PKG_MGR" curl ca-certificates; rc=$?
if [ "$rc" -eq 1 ]; then
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

ensure_command python3 "$PKG_MGR" python3; rc=$?
if [ "$rc" -eq 1 ]; then
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

ensure_command git "$PKG_MGR" git; rc=$?
if [ "$rc" -eq 1 ]; then
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

# pip
ensure_command pip3 "$PKG_MGR" python3-pip; rc=$?
if [ "$rc" -eq 1 ]; then
    if ! command_exists pip; then
        log_error "pip3 is required for Python package installation"
        MISSING=1
    fi
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

# Node.js + npm/npx
ensure_node "$PKG_MGR"; rc=$?
if [ "$rc" -eq 1 ]; then
    OPENCLAW_OK=0
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    OPENCLAW_OK=0
    SKIPPED=1
    MISSING=1
fi

# uv / uvx
ensure_uvx; rc=$?
if [ "$rc" -eq 1 ]; then
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

# Docker
ensure_docker "$PKG_MGR"; rc=$?
if [ "$rc" -eq 1 ]; then
    MISSING=1
elif [ "$rc" -eq 2 ]; then
    SKIPPED=1
    MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
    if [ "$SKIPPED" -eq 1 ]; then
        log_warn "Skipped required installs: ${SKIPPED_ITEMS[*]}"
    fi
    log_error "Missing prerequisites. Please install them and re-run this script."
    exit 1
fi

log_info "All prerequisites satisfied."
if [ "$SKIPPED" -eq 1 ]; then
    log_warn "Some installs were skipped: ${SKIPPED_ITEMS[*]}"
fi
if [ "$OPENCLAW_OK" -ne 1 ]; then
    log_warn "OpenClaw prerequisites missing — OpenClaw steps will be skipped."
fi
echo ""

# ═══════════════════════════════════════════
# Step 2: Install OpenClaw
# ═══════════════════════════════════════════

log_step "2/$TOTAL_STEPS Installing OpenClaw..."

if [ "$OPENCLAW_OK" -ne 1 ]; then
    log_warn "Skipping OpenClaw install (Node.js/npm/npx missing)."
else
    if command -v openclaw &> /dev/null; then
        log_info "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"
    else
        log_info "Installing OpenClaw via npm..."
        if [ "$(id -u)" -eq 0 ]; then
            npm install -g openclaw@latest
        else
            if ! as_root npm install -g openclaw@latest; then
                log_warn "sudo install failed or unavailable; using user-local npm prefix"
                mkdir -p "$HOME/.local/npm"
                npm config set prefix "$HOME/.local/npm"
                export PATH="$HOME/.local/npm/bin:$PATH"
                npm install -g openclaw@latest
            fi
        fi

        if command -v openclaw &> /dev/null; then
            log_info "OpenClaw installed successfully"
        else
            log_error "openclaw not found on PATH after install"
            log_warn "Try: export PATH=\"$(npm config get prefix)/bin:\$PATH\""
        fi
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

if [ "$OPENCLAW_OK" -ne 1 ]; then
    log_warn "Skipping OpenClaw onboard (Node.js/npm/npx missing)."
elif command -v openclaw &> /dev/null; then
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

log_step "7/$TOTAL_STEPS Installing GitHub MCP Server..."
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
OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"
OPENCLAW_WORKSPACE_DEFAULT="$OPENCLAW_DIR/workspace"
OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE_DEFAULT"
if [ ! -d "$OPENCLAW_DIR" ]; then
    log_info "OpenClaw directory not found. Bootstrapping..."
    mkdir -p "$OPENCLAW_DIR/workspace/skills"
    mkdir -p "$OPENCLAW_DIR/agents/main/sessions"
    log_info "Created $OPENCLAW_DIR"
fi

# Use configured workspace path if available
if [ -f "$OPENCLAW_JSON" ]; then
    OPENCLAW_WORKSPACE=$(python3 - <<'PY'
import json
import os

path = os.environ.get("OPENCLAW_JSON")
workspace = ""
if path and os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    workspace = (
        data.get("agents", {})
        .get("defaults", {})
        .get("workspace", "")
    )
print(workspace)
PY
)
fi
if [ -z "$OPENCLAW_WORKSPACE" ]; then
    OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE_DEFAULT"
fi

# Ensure workspace paths exist even if ~/.openclaw already existed
mkdir -p "$OPENCLAW_WORKSPACE"
mkdir -p "$OPENCLAW_WORKSPACE/skills"
mkdir -p "$OPENCLAW_DIR/workspace"
mkdir -p "$OPENCLAW_DIR/workspace/skills"

# Deploy workspace MD files
for mdfile in SOUL.md AGENTS.md TOOLS.md; do
    if [ -f "$AIOPS_DIR/$mdfile" ]; then
        cp "$AIOPS_DIR/$mdfile" "$OPENCLAW_WORKSPACE/$mdfile"
        log_info "Deployed $mdfile to $OPENCLAW_WORKSPACE"
        if [ "$OPENCLAW_WORKSPACE" != "$OPENCLAW_DIR/workspace" ]; then
            cp "$AIOPS_DIR/$mdfile" "$OPENCLAW_DIR/workspace/$mdfile"
            log_info "Deployed $mdfile to $OPENCLAW_DIR/workspace"
        fi
    fi
done

# Deploy skills
if [ -d "$AIOPS_DIR/workspace/skills" ]; then
    cp -r "$AIOPS_DIR/workspace/skills/"* "$OPENCLAW_WORKSPACE/skills/" 2>/dev/null || true
    log_info "Deployed AIOps skills to $OPENCLAW_WORKSPACE"
    if [ "$OPENCLAW_WORKSPACE" != "$OPENCLAW_DIR/workspace" ]; then
        cp -r "$AIOPS_DIR/workspace/skills/"* "$OPENCLAW_DIR/workspace/skills/" 2>/dev/null || true
        log_info "Deployed AIOps skills to $OPENCLAW_DIR/workspace"
    fi
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
