#!/usr/bin/env python3
"""
AIOps Executor MCP Server — Nokia SR Linux Device Configuration

Exposes MCP tools for provisioning and verifying Nokia SR Linux devices
via SSH (Netmiko). Designed to be called by OpenClaw via mcp-call.py.

Tools:
  - provision_interface: Configure an interface with IP on a device
  - verify_device_state: Check actual state matches expected IP
  - get_running_config:  Retrieve running config section from a device

Usage (stdio, via mcp-call.py):
  python3 mcp-call.py "python3 -u mcp_servers/executor_mcp/server.py" \
    provision_interface '{"device_name":"leaf1","interface_name":"ethernet-1/1","ip_address":"10.0.0.1/31"}'
"""

import json
import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP
from netmiko import ConnectHandler

# ── Configuration ────────────────────────────────────────────────────────────

DEVICE_USERNAME = os.environ.get("DEVICE_USERNAME", "admin")
DEVICE_PASSWORD = os.environ.get("DEVICE_PASSWORD", "NokiaSrl1!")
DEVICE_TYPE = "nokia_srl"
CLAB_LAB_NAME = os.environ.get("CLAB_LAB_NAME", "aiops-lab")
TEMPLATE_DIR = Path(__file__).resolve().parent.parent.parent / "configs" / "templates" / "nokia_srlinux"


def _get_mgmt_hostname(device_name: str) -> str:
    """Return the containerlab management hostname for a device."""
    return f"clab-{CLAB_LAB_NAME}-{device_name}"


def _ssh_connect(device_name: str) -> ConnectHandler:
    """Open an SSH connection to a containerlab device."""
    return ConnectHandler(
        device_type=DEVICE_TYPE,
        host=_get_mgmt_hostname(device_name),
        username=DEVICE_USERNAME,
        password=DEVICE_PASSWORD,
    )


# ── MCP Server ───────────────────────────────────────────────────────────────

mcp = FastMCP(
    "AIOps Executor",
    instructions=(
        "Nokia SR Linux device configuration tools for the AIOps lab. "
        "Use provision_interface to configure interfaces, verify_device_state "
        "to check actual state, and get_running_config to inspect device config."
    ),
)


@mcp.tool()
def provision_interface(
    device_name: str,
    interface_name: str,
    ip_address: str,
    description: str = "",
    network_instance: str = "default",
    subinterface_index: int = 1,
    dry_run: bool = False,
) -> dict:
    """Configure an interface on a Nokia SR Linux device with the given IP address.

    Enters candidate mode, applies set commands, and commits.

    Args:
        device_name: Device name in containerlab (e.g., 'spine1', 'leaf1')
        interface_name: Interface name (e.g., 'ethernet-1/1')
        ip_address: IP address with prefix length (e.g., '10.0.0.0/31')
        description: Optional interface description
        network_instance: Network instance to add the interface to (default: 'default')
        subinterface_index: Subinterface index (default: 1)
        dry_run: If True, render commands but do not push to device

    Returns:
        Dictionary with status, commands rendered, and any output
    """
    # Build the set commands
    commands = [
        f"set / interface {interface_name} admin-state enable",
    ]
    if description:
        commands.append(
            f'set / interface {interface_name} description "{description}"'
        )
    commands.extend([
        f"set / interface {interface_name} subinterface {subinterface_index} "
        f"ipv4 admin-state enable",
        f"set / interface {interface_name} subinterface {subinterface_index} "
        f"ipv4 address {ip_address}",
        f"set / network-instance {network_instance} admin-state enable",
        f"set / network-instance {network_instance} interface "
        f"{interface_name}.{subinterface_index}",
    ])

    if dry_run:
        return {
            "status": "DRY_RUN",
            "device": device_name,
            "commands": commands,
            "message": "Commands rendered but NOT pushed (dry_run=True)",
        }

    try:
        conn = _ssh_connect(device_name)

        # Ensure we are in the basic CLI environment and enter candidate mode
        conn.send_command_timing("environment cli-engine type basic")
        conn.send_command("enter candidate", expect_string=r"#")

        # Send each set command
        for cmd in commands:
            conn.send_command(cmd, expect_string=r"#")

        # Commit
        commit_output = conn.send_command("commit now", expect_string=r"#")
        conn.disconnect()

        return {
            "status": "SUCCESS",
            "device": device_name,
            "interface": interface_name,
            "ip_address": ip_address,
            "commands_applied": len(commands),
            "commit_output": commit_output.strip(),
        }

    except Exception as e:
        return {
            "status": "ERROR",
            "device": device_name,
            "error": str(e),
        }


@mcp.tool()
def verify_device_state(
    device_name: str,
    interface_name: str,
    expected_ip: str,
    subinterface_index: int = 1,
) -> dict:
    """Verify that a device interface has the expected IP address configured.

    SSHs to the device, queries the interface state, and checks if the
    expected IP appears in the output.

    Args:
        device_name: Device name in containerlab (e.g., 'spine1')
        interface_name: Interface name (e.g., 'ethernet-1/1')
        expected_ip: Expected IP address with prefix (e.g., '10.0.0.0/31')
        subinterface_index: Subinterface index (default: 1)

    Returns:
        Dictionary with status (PASS/FAIL), actual state output
    """
    try:
        conn = _ssh_connect(device_name)

        # Ensure we are in the basic CLI environment before querying state
        conn.send_command_timing("environment cli-engine type basic")

        # Query interface IPv4 state
        # Note: 'ipv4 address' fails on SR Linux (keyed list needs ip-prefix)
        # Query 'ipv4' instead and search for the IP in the output
        cmd = (
            f"info from state interface {interface_name} "
            f"subinterface {subinterface_index} ipv4"
        )
        output = conn.send_command(cmd, expect_string=r"#", read_timeout=30)
        conn.disconnect()

        ip_without_mask = expected_ip.split("/")[0]
        found = ip_without_mask in output

        return {
            "status": "PASS" if found else "FAIL",
            "device": device_name,
            "interface": interface_name,
            "expected_ip": expected_ip,
            "actual_ip": expected_ip if found else "NOT FOUND",
            "raw_output": output.strip()[:500],  # truncate for readability
        }

    except Exception as e:
        return {
            "status": "ERROR",
            "device": device_name,
            "interface": interface_name,
            "error": str(e),
        }


@mcp.tool()
def get_running_config(
    device_name: str,
    section: str = "",
) -> dict:
    """Retrieve the running configuration from a Nokia SR Linux device.

    Args:
        device_name: Device name in containerlab (e.g., 'spine1')
        section: Optional config section to filter (e.g., 'interface ethernet-1/1',
                 'network-instance default'). If empty, returns full running config.

    Returns:
        Dictionary with the config output
    """
    try:
        conn = _ssh_connect(device_name)

        if section:
            cmd = f"info running {section}"
        else:
            cmd = "info running"

        output = conn.send_command(cmd)
        conn.disconnect()

        return {
            "status": "SUCCESS",
            "device": device_name,
            "section": section or "(full)",
            "config": output.strip(),
        }

    except Exception as e:
        return {
            "status": "ERROR",
            "device": device_name,
            "error": str(e),
        }


@mcp.tool()
def push_config(
    device_name: str,
    config_file: str = "",
    dry_run: bool = False,
) -> dict:
    """Push a generated config file to a Nokia SR Linux device via SSH.

    Reads the compiled config from configs/generated/<device>.cfg and
    applies each command in candidate mode.

    Args:
        device_name: Device name in containerlab (e.g., 'spine1', 'leaf1')
        config_file: Optional path to config file. Defaults to
                     configs/generated/<device_name>.cfg
        dry_run: If True, read the config but do not push to device

    Returns:
        Dictionary with status, commands count, and any output
    """
    # Resolve config file path
    if config_file:
        cfg_path = Path(config_file)
    else:
        cfg_path = (
            Path(__file__).resolve().parent.parent.parent
            / "configs" / "generated" / f"{device_name}.cfg"
        )

    if not cfg_path.exists():
        return {
            "status": "ERROR",
            "device": device_name,
            "error": f"Config file not found: {cfg_path}. Run deploy.py --compile-only first.",
        }

    # Read and parse the config file
    config_text = cfg_path.read_text().strip()
    commands = [
        line.strip()
        for line in config_text.splitlines()
        if line.strip() and not line.strip().startswith("#") and not line.strip().startswith("{")
    ]

    if not commands:
        return {
            "status": "ERROR",
            "device": device_name,
            "error": "Config file is empty or contains no valid commands.",
        }

    if dry_run:
        return {
            "status": "DRY_RUN",
            "device": device_name,
            "config_file": str(cfg_path),
            "commands": commands,
            "commands_count": len(commands),
            "message": "Commands loaded but NOT pushed (dry_run=True)",
        }

    try:
        conn = _ssh_connect(device_name)

        # Ensure basic CLI environment and enter candidate mode
        conn.send_command("environment cli-engine type basic", expect_string=r"#")
        conn.send_command("enter candidate", expect_string=r"#")

        # Send each command
        for cmd in commands:
            conn.send_command(cmd, expect_string=r"#")

        # Commit
        commit_output = conn.send_command("commit now", expect_string=r"#")
        conn.disconnect()

        return {
            "status": "SUCCESS",
            "device": device_name,
            "config_file": str(cfg_path),
            "commands_applied": len(commands),
            "commit_output": commit_output.strip(),
        }

    except Exception as e:
        return {
            "status": "ERROR",
            "device": device_name,
            "error": str(e),
        }


# ── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run(transport="stdio")
