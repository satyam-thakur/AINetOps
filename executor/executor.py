#!/usr/bin/env python3
"""
executor.py — AIOps Phase 1: Intent-Driven Configuration Executor.

Workflow:
  1. Query NetBox for devices and their intended interface/IP state
  2. Render Jinja2 configuration templates from NetBox data
  3. Push configuration to containerlab nodes via Netmiko (SSH)
  4. Verify applied state matches NetBox intent
  5. Report results

Usage:
  python executor.py                     # full run: query + render + push + verify
  python executor.py --dry-run           # render only, no push
  python executor.py --verify-only       # verify current state against NetBox intent

Prerequisites:
  - NetBox running and seeded (see netbox/seed_netbox.py)
  - Containerlab topology deployed (sudo clab deploy -t containerlab/topology.clab.yaml)
  - pip install -r requirements.txt
"""

import argparse
import sys
from pathlib import Path

try:
    import pynetbox
    from jinja2 import Environment, FileSystemLoader
    from netmiko import ConnectHandler
    from rich.console import Console
    from rich.table import Table
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}")
    print("Run: pip install -r requirements.txt")
    sys.exit(1)

from config import (
    NETBOX_URL,
    NETBOX_TOKEN,
    TEMPLATE_DIR,
    SITE_FILTER,
    DEVICE_USERNAME,
    DEVICE_PASSWORD,
    DEVICE_TYPE,
    get_mgmt_hostname,
)

console = Console()


# ── Step 1: Query NetBox ─────────────────────────────────────────────────────

def fetch_intent(nb):
    """
    Fetch all devices at the configured site and their interface/IP assignments.

    Returns a list of dicts:
    [
        {
            "device": "spine1",
            "interfaces": [
                {
                    "name": "ethernet-1/1",
                    "description": "to-leaf1:e1-1",
                    "ip_address": "10.0.0.0/31",
                },
            ],
        },
    ]
    """
    console.print("\n[bold cyan]── Step 1: Fetching Intent from NetBox ──[/]")

    devices = nb.dcim.devices.filter(site=SITE_FILTER, status="active")
    intent = []

    for device in devices:
        dev_data = {"device": device.name, "interfaces": []}

        # Get non-management interfaces
        interfaces = nb.dcim.interfaces.filter(
            device_id=device.id, mgmt_only=False
        )

        for iface in interfaces:
            # Get IP addresses assigned to this interface
            ips = nb.ipam.ip_addresses.filter(
                interface_id=iface.id
            )

            for ip in ips:
                dev_data["interfaces"].append({
                    "name": iface.name,
                    "description": iface.description or "",
                    "ip_address": str(ip.address),
                })

        if dev_data["interfaces"]:
            intent.append(dev_data)
            console.print(
                f"  ✓ {device.name}: "
                f"{len(dev_data['interfaces'])} interface(s) with IP"
            )

    if not intent:
        console.print("[yellow]  ⚠ No devices with IP-assigned interfaces found[/]")

    return intent


# ── Step 2: Render Templates ─────────────────────────────────────────────────

def render_configs(intent):
    """
    Render Jinja2 templates for each device/interface pair.

    Returns a dict: { "device_name": ["config_line_1", "config_line_2", ...] }
    """
    console.print("\n[bold cyan]── Step 2: Rendering Configuration Templates ──[/]")

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        trim_blocks=True,
        lstrip_blocks=True,
    )

    fabric_tmpl = env.get_template("fabric_interface.j2")
    netinst_tmpl = env.get_template("network_instance.j2")

    configs = {}

    for dev in intent:
        device_name = dev["device"]
        config_lines = []

        for iface in dev["interfaces"]:
            # Render fabric interface config
            rendered_iface = fabric_tmpl.render(
                interface_name=iface["name"],
                description=iface["description"],
                ip_address=iface["ip_address"],
                subinterface_index=1,
            )
            config_lines.append(rendered_iface.strip())

            # Render network instance config
            rendered_ni = netinst_tmpl.render(
                interface_name=iface["name"],
                network_instance="default",
                subinterface_index=1,
            )
            config_lines.append(rendered_ni.strip())

        configs[device_name] = config_lines
        console.print(f"  ✓ {device_name}: {len(config_lines)} config block(s)")

        # Show rendered config in dry-run friendly way
        for block in config_lines:
            for line in block.split("\n"):
                console.print(f"    [dim]{line}[/]")

    return configs


# ── Step 3: Push Configuration ───────────────────────────────────────────────

def push_configs(configs):
    """
    Push rendered configs to containerlab nodes via Netmiko SSH.
    """
    console.print("\n[bold cyan]── Step 3: Pushing Configuration via SSH ──[/]")

    results = {}

    for device_name, config_blocks in configs.items():
        mgmt_host = get_mgmt_hostname(device_name)
        console.print(f"\n  Connecting to {device_name} ({mgmt_host})...")

        try:
            connection = ConnectHandler(
                device_type=DEVICE_TYPE,
                host=mgmt_host,
                username=DEVICE_USERNAME,
                password=DEVICE_PASSWORD,
            )

            # Flatten all config blocks into individual commands
            all_commands = []
            for block in config_blocks:
                for line in block.strip().split("\n"):
                    line = line.strip()
                    if line and not line.startswith("{#"):
                        all_commands.append(line)

            # Send commands
            for cmd in all_commands:
                output = connection.send_command(cmd, expect_string=r"#")
                console.print(f"    [green]→[/] {cmd}")

            # Commit the candidate config
            commit_output = connection.send_command("commit now", expect_string=r"#")
            console.print(f"    [green]✓[/] Committed on {device_name}")

            connection.disconnect()
            results[device_name] = "SUCCESS"

        except Exception as e:
            console.print(f"    [red]✗ Error on {device_name}: {e}[/]")
            results[device_name] = f"FAILED: {e}"

    return results


# ── Step 4: Verify Configuration ─────────────────────────────────────────────

def verify_state(intent):
    """
    SSH to each device and verify the actual interface state matches NetBox intent.
    """
    console.print("\n[bold cyan]── Step 4: Verifying Applied State ──[/]")

    results = []

    for dev in intent:
        device_name = dev["device"]
        mgmt_host = get_mgmt_hostname(device_name)

        try:
            connection = ConnectHandler(
                device_type=DEVICE_TYPE,
                host=mgmt_host,
                username=DEVICE_USERNAME,
                password=DEVICE_PASSWORD,
            )

            for iface in dev["interfaces"]:
                # Query actual interface state
                cmd = f"info from state interface {iface['name']} subinterface 1 ipv4 address"
                output = connection.send_command(cmd)

                intended_ip = iface["ip_address"]
                # Check if the intended IP appears in the output
                # SR Linux shows IP as ip-prefix in the state output
                ip_without_mask = intended_ip.split("/")[0]
                actual_found = ip_without_mask in output

                results.append({
                    "device": device_name,
                    "interface": iface["name"],
                    "intended": intended_ip,
                    "actual": intended_ip if actual_found else "NOT FOUND",
                    "status": "PASS" if actual_found else "FAIL",
                })

            connection.disconnect()

        except Exception as e:
            for iface in dev["interfaces"]:
                results.append({
                    "device": device_name,
                    "interface": iface["name"],
                    "intended": iface["ip_address"],
                    "actual": f"ERROR: {e}",
                    "status": "FAIL",
                })

    return results


# ── Step 5: Report ───────────────────────────────────────────────────────────

def print_report(results):
    """Print a summary table of verification results."""
    console.print("\n[bold cyan]── Step 5: Verification Report ──[/]")

    table = Table(title="AIOps Phase 1 — Intent vs Actual State")
    table.add_column("Device", style="bold")
    table.add_column("Interface")
    table.add_column("Intended IP", style="cyan")
    table.add_column("Actual IP", style="cyan")
    table.add_column("Status")

    all_pass = True
    for r in results:
        status_style = "green" if r["status"] == "PASS" else "red bold"
        status_icon = "✓ PASS" if r["status"] == "PASS" else "✗ FAIL"
        if r["status"] != "PASS":
            all_pass = False

        table.add_row(
            r["device"],
            r["interface"],
            r["intended"],
            r["actual"],
            f"[{status_style}]{status_icon}[/]",
        )

    console.print(table)

    if all_pass:
        console.print(
            "\n[bold green]✓ All interfaces match NetBox intent. "
            "Phase 1 MVP verified![/]"
        )
    else:
        console.print(
            "\n[bold red]✗ Some interfaces do not match intent. "
            "Check device state.[/]"
        )

    return all_pass


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="AIOps Phase 1: Intent-Driven Configuration Executor"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Render configs but do not push to devices",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Only verify current state against NetBox intent",
    )
    args = parser.parse_args()

    console.print("[bold magenta]")
    console.print("╔═══════════════════════════════════════════════════════════╗")
    console.print("║   AIOps — Phase 1: Intent-Driven Configuration Executor  ║")
    console.print("║   NetBox → Jinja2 → Netmiko → Verify                     ║")
    console.print("╚═══════════════════════════════════════════════════════════╝")
    console.print("[/]")

    # Connect to NetBox
    nb = pynetbox.api(NETBOX_URL, token=NETBOX_TOKEN)

    # Step 1: Fetch intent
    intent = fetch_intent(nb)
    if not intent:
        console.print("[red]No intent data found. Is NetBox seeded?[/]")
        sys.exit(1)

    if args.verify_only:
        # Skip render + push, go straight to verify
        results = verify_state(intent)
        success = print_report(results)
        sys.exit(0 if success else 1)

    # Step 2: Render templates
    configs = render_configs(intent)

    if args.dry_run:
        console.print(
            "\n[yellow]── Dry-run mode: configs rendered but NOT pushed ──[/]"
        )
        sys.exit(0)

    # Step 3: Push configs
    push_results = push_configs(configs)

    # Step 4: Verify
    results = verify_state(intent)

    # Step 5: Report
    success = print_report(results)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
