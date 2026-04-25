#!/usr/bin/env python3
"""
AIOps Config Compiler — Deploy Script

Compiles Jinja2 templates with intent YAML data to generate device configs.
Does NOT push to devices — use the executor_mcp push_config tool for that.

Usage:
    python scripts/deploy.py --compile-only --device spine1
    python scripts/deploy.py --compile-only --all
    python scripts/deploy.py --compile-only          # defaults to --all
"""

import argparse
import os
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


# ── Configuration ────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent
INTENT_DIR = PROJECT_ROOT / "configs" / "intent_config"
TEMPLATE_DIR = PROJECT_ROOT / "configs" / "templates" / "nokia_srlinux"
GENERATED_DIR = PROJECT_ROOT / "configs" / "generated"


def load_intent(device_name: str) -> dict:
    """Load intent YAML for a device."""
    intent_file = INTENT_DIR / f"{device_name}.yaml"
    if not intent_file.exists():
        print(f"ERROR: Intent file not found: {intent_file}")
        sys.exit(1)

    with open(intent_file) as f:
        return yaml.safe_load(f)


def compile_config(device_name: str, intent_data: dict) -> str:
    """Render Jinja2 templates with intent data to produce device config."""
    env = Environment(loader=FileSystemLoader(str(TEMPLATE_DIR)))
    config_sections = []

    device = intent_data.get("device", {})

    # Render fabric_interface.j2 for each interface
    try:
        iface_template = env.get_template("fabric_interface.j2")
    except Exception:
        iface_template = None

    for iface in device.get("interfaces", []):
        if iface_template:
            rendered = iface_template.render(
                interface_name=iface["name"],
                description=iface.get("description", ""),
                subinterface_index=iface.get("subinterface_index", 1),
                ip_address=iface["ipv4"],
            )
            config_sections.append(rendered.strip())

    # Render network_instance.j2 for each network instance binding
    try:
        ni_template = env.get_template("network_instance.j2")
    except Exception:
        ni_template = None

    for iface in device.get("interfaces", []):
        ni_name = iface.get("network_instance", "default")
        if ni_template:
            rendered = ni_template.render(
                network_instance=ni_name,
                interface_name=iface["name"],
                subinterface_index=iface.get("subinterface_index", 1),
            )
            config_sections.append(rendered.strip())

    return "\n\n".join(config_sections)


def write_generated(device_name: str, config_text: str) -> Path:
    """Write compiled config to configs/generated/<device>.cfg."""
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    output_file = GENERATED_DIR / f"{device_name}.cfg"
    output_file.write_text(config_text + "\n")
    return output_file


def get_all_devices() -> list[str]:
    """List all device names from intent_config/ directory."""
    return sorted(
        f.stem for f in INTENT_DIR.glob("*.yaml") if f.is_file()
    )


def main():
    parser = argparse.ArgumentParser(
        description="Compile Jinja2 templates with intent YAML data."
    )
    parser.add_argument(
        "--device",
        help="Device name to compile (e.g., spine1). Default: all devices.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        default=True,
        help="Compile all devices (default).",
    )
    parser.add_argument(
        "--compile-only",
        action="store_true",
        default=True,
        help="Compile only, do not push (always true — use push_config MCP tool to push).",
    )
    args = parser.parse_args()

    devices = [args.device] if args.device else get_all_devices()

    if not devices:
        print("ERROR: No devices found in configs/intent_config/")
        sys.exit(1)

    print(f"Compiling configs for {len(devices)} device(s)...")
    print(f"  Templates: {TEMPLATE_DIR}")
    print(f"  Intent:    {INTENT_DIR}")
    print(f"  Output:    {GENERATED_DIR}")
    print()

    results = []
    for device_name in devices:
        print(f"  [{device_name}] Loading intent...")
        intent_data = load_intent(device_name)

        print(f"  [{device_name}] Rendering templates...")
        config_text = compile_config(device_name, intent_data)

        output_file = write_generated(device_name, config_text)
        print(f"  [{device_name}] ✓ Written to {output_file}")

        results.append({
            "device": device_name,
            "status": "OK",
            "output_file": str(output_file),
            "lines": len(config_text.splitlines()),
        })

    print()
    print("═══ Compilation Summary ═══")
    for r in results:
        print(f"  {r['device']:12s} {r['status']:6s} {r['lines']:4d} lines → {r['output_file']}")

    print()
    print("Note: Use the executor_mcp push_config tool to push configs to devices.")


if __name__ == "__main__":
    main()
