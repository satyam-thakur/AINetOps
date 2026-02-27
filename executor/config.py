"""
config.py — Executor configuration for AIOps Phase 1.

Reads from environment variables or .env file.
"""

import os
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = PROJECT_ROOT / "templates"

# ── NetBox ────────────────────────────────────────────────────────────────────

NETBOX_URL = os.environ.get("NETBOX_URL", "http://localhost:8000")
NETBOX_TOKEN = os.environ.get(
    "NETBOX_TOKEN", "0123456789abcdef0123456789abcdef01234567"
)

# ── Site Filter ───────────────────────────────────────────────────────────────

SITE_FILTER = os.environ.get("SITE_FILTER", "lab-dc1")

# ── Device Credentials (containerlab defaults) ───────────────────────────────

DEVICE_USERNAME = os.environ.get("DEVICE_USERNAME", "admin")
DEVICE_PASSWORD = os.environ.get("DEVICE_PASSWORD", "NokiaSrl1!")

# Nokia SR Linux Netmiko device type
DEVICE_TYPE = "nokia_srl"

# ── Containerlab Management Network ──────────────────────────────────────────
# Containerlab assigns management IPs from 172.20.20.0/24 by default.
# We resolve device management IPs via DNS:
#   clab-<lab-name>-<node-name>  (e.g., clab-aiops-lab-spine1)
#
# The lab name comes from topology.clab.yaml `name:` field.
CLAB_LAB_NAME = os.environ.get("CLAB_LAB_NAME", "aiops-lab")

def get_mgmt_hostname(device_name: str) -> str:
    """Return the containerlab management hostname for a device."""
    return f"clab-{CLAB_LAB_NAME}-{device_name}"
