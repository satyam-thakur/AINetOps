#!/usr/bin/env bash
# AINetOps Platform Setup — Interactive Wizard
# Modeled after: netclaw/scripts/setup.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

AIOPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"
OPENCLAW_ENV="$OPENCLAW_DIR/.env"

prompt() { local var="$1" p="$2" d="${3:-}"; [ -n "$d" ] && echo -ne "${CYAN}${p}${NC} ${DIM}[${d}]${NC}: " || echo -ne "${CYAN}${p}${NC}: "; read -r input; eval "$var=\"${input:-$d}\""; }
prompt_secret() { local var="$1" p="$2"; echo -ne "${CYAN}${p}${NC}: "; read -rs input; echo; eval "$var=\"$input\""; }
yesno() { local p="$1" d="${2:-n}" yn; [ "$d" = "y" ] && echo -ne "${CYAN}${p}${NC} ${DIM}[Y/n]${NC}: " || echo -ne "${CYAN}${p}${NC} ${DIM}[y/N]${NC}: "; read -r yn; yn="${yn:-$d}"; [[ "$yn" =~ ^[Yy] ]]; }
set_env() { local k="$1" v="$2"; [ -z "$v" ] && return; grep -q "^${k}=" "$OPENCLAW_ENV" 2>/dev/null && sed -i "s|^${k}=.*|${k}=${v}|" "$OPENCLAW_ENV" || echo "${k}=${v}" >> "$OPENCLAW_ENV"; }
section() { echo ""; echo -e "${BOLD}═══════════════════════════════════════════${NC}"; echo -e "${BOLD}  $1${NC}"; echo -e "${BOLD}═══════════════════════════════════════════${NC}"; echo ""; }
ok() { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${DIM}– $1 (skipped)${NC}"; }

[ -d "$OPENCLAW_DIR" ] || { echo -e "${RED}Error: ~/.openclaw not found. Run install.sh first.${NC}"; exit 1; }
[ -f "$OPENCLAW_ENV" ] || touch "$OPENCLAW_ENV"

echo ""; echo -e "${BOLD}    AINetOps Platform Setup${NC}"; echo ""
echo -e "  Configure network platform credentials."
echo -e "  Re-run anytime: ${BOLD}./scripts/setup.sh${NC}"
echo -e "  ${DIM}Credentials stored in ~/.openclaw/.env${NC}"

section "Step 1: Network Devices (Nokia SR Linux)"
echo "  Default lab: spine1, leaf1, leaf2 (Containerlab)"; echo ""
prompt DEVICE_USER "Device SSH username" "admin"
prompt_secret DEVICE_PASS "Device SSH password"
prompt CLAB_NAME "Containerlab lab name" "aiops-lab"
[ -n "$DEVICE_USER" ] && set_env "DEVICE_USERNAME" "$DEVICE_USER"
[ -n "$DEVICE_PASS" ] && set_env "DEVICE_PASSWORD" "$DEVICE_PASS"
[ -n "$CLAB_NAME" ] && set_env "CLAB_LAB_NAME" "$CLAB_NAME"
ok "Network devices configured"

section "Step 2: Network Platforms"
if yesno "Do you have a NetBox instance?" "y"; then
    echo ""; prompt NETBOX_URL "NetBox URL" "http://localhost:8000"; prompt_secret NETBOX_TOKEN "NetBox API Token"
    [ -n "$NETBOX_URL" ] && set_env "NETBOX_URL" "$NETBOX_URL"; [ -n "$NETBOX_TOKEN" ] && set_env "NETBOX_TOKEN" "$NETBOX_TOKEN"; ok "NetBox configured"
else skip "NetBox"; fi; echo ""
if yesno "Do you have a GitHub account?"; then
    echo -e "  Get a PAT at: ${BOLD}https://github.com/settings/tokens${NC}"; prompt_secret GH_PAT "GitHub PAT (ghp_...)"
    [ -n "$GH_PAT" ] && { set_env "GITHUB_PERSONAL_ACCESS_TOKEN" "$GH_PAT"; ok "GitHub configured"; } || skip "GitHub"
else skip "GitHub"; fi; echo ""
if yesno "Do you have a Containerlab API server?"; then
    prompt CLAB_API "Containerlab API URL" "http://localhost:8080"; prompt CLAB_API_USER "Username" "admin"; prompt_secret CLAB_API_PASS "Password"
    [ -n "$CLAB_API" ] && set_env "CLAB_API_SERVER_URL" "$CLAB_API"; [ -n "$CLAB_API_USER" ] && set_env "CLAB_API_USERNAME" "$CLAB_API_USER"
    [ -n "$CLAB_API_PASS" ] && set_env "CLAB_API_PASSWORD" "$CLAB_API_PASS"; ok "Containerlab configured"
else skip "Containerlab API"; fi

section "Step 3: Observability"
if yesno "Do you have a Grafana instance?"; then
    prompt GRAFANA_URL "Grafana URL" "http://localhost:3000"; [ -n "$GRAFANA_URL" ] && set_env "GRAFANA_URL" "$GRAFANA_URL"; ok "Grafana configured"
else skip "Grafana"; fi; echo ""
if yesno "Do you have a Prometheus instance?"; then
    prompt PROM_URL "Prometheus URL" "http://localhost:9090"; [ -n "$PROM_URL" ] && set_env "PROMETHEUS_URL" "$PROM_URL"; ok "Prometheus configured"
else skip "Prometheus"; fi

section "Step 4: Notifications"
if yesno "Do you have a Slack Webhook URL?"; then
    prompt SLACK_URL "Slack Webhook URL" ""; [ -n "$SLACK_URL" ] && { set_env "SLACK_WEBHOOK_URL" "$SLACK_URL"; ok "Slack configured"; }
else skip "Slack"; echo -e "  ${DIM}Tip: Use 'openclaw configure' for Slack channel setup${NC}"; fi

section "Step 5: About You"
prompt USER_NAME "Your name" ""; prompt USER_ROLE "Your role" "Network Engineer"; prompt USER_TZ "Your timezone" ""
USER_MD="$OPENCLAW_DIR/workspace/USER.md"
if [ -n "$USER_NAME" ] || [ -n "$USER_ROLE" ]; then
    cat > "$USER_MD" << USEREOF
# About My Human
- **Name:** ${USER_NAME:-[your name]}
- **Role:** ${USER_ROLE:-Network Engineer}
- **Timezone:** ${USER_TZ:-[your timezone]}
- Communication: technical, direct
- Lab: Nokia SR Linux spine/leaf (Containerlab)
USEREOF
    ok "USER.md personalized"
fi

section "Setup Complete"
echo "  Credentials saved to: ~/.openclaw/.env"; echo ""
grep -q "^DEVICE_USERNAME=" "$OPENCLAW_ENV" 2>/dev/null && ok "Nokia SR Linux" || skip "Nokia SR Linux"
grep -q "^NETBOX_URL=" "$OPENCLAW_ENV" 2>/dev/null && ok "NetBox" || skip "NetBox"
grep -q "^GITHUB_PERSONAL_ACCESS_TOKEN=" "$OPENCLAW_ENV" 2>/dev/null && ok "GitHub" || skip "GitHub"
grep -q "^GRAFANA_URL=" "$OPENCLAW_ENV" 2>/dev/null && ok "Grafana" || skip "Grafana"
grep -q "^PROMETHEUS_URL=" "$OPENCLAW_ENV" 2>/dev/null && ok "Prometheus" || skip "Prometheus"
grep -q "^SLACK_WEBHOOK_URL=" "$OPENCLAW_ENV" 2>/dev/null && ok "Slack" || skip "Slack"
echo ""; echo -e "  ${CYAN}openclaw gateway${NC}   # Terminal 1"; echo -e "  ${CYAN}openclaw tui${NC}       # Terminal 2"; echo ""
