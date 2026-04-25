#!/usr/bin/env python3
"""
AIOps Config Validator — Validate Script

Runs Jinja2 lint (j2lint), YAML syntax validation, and compile dry-run
against the configs/ directory.

Usage:
    python scripts/validate.py --lint-only           # j2lint + YAML only
    python scripts/validate.py --device spine1       # validate specific device
    python scripts/validate.py                       # full validation
"""

import argparse
import subprocess
import sys
from pathlib import Path

import yaml


# ── Configuration ────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = PROJECT_ROOT / "configs" / "templates"
INTENT_DIR = PROJECT_ROOT / "configs" / "intent_config"


def validate_yaml_syntax(intent_dir: Path, device: str | None = None) -> list[dict]:
    """Validate YAML syntax of intent config files."""
    results = []

    if device:
        files = [intent_dir / f"{device}.yaml"]
    else:
        files = sorted(intent_dir.glob("*.yaml"))

    for yaml_file in files:
        if not yaml_file.exists():
            results.append({
                "file": str(yaml_file),
                "status": "FAIL",
                "error": "File not found",
            })
            continue

        try:
            with open(yaml_file) as f:
                yaml.safe_load(f)
            results.append({
                "file": yaml_file.name,
                "status": "PASS",
                "error": None,
            })
        except yaml.YAMLError as e:
            results.append({
                "file": yaml_file.name,
                "status": "FAIL",
                "error": str(e),
            })

    return results


def run_j2lint(template_dir: Path) -> dict:
    """Run j2lint against all template directories."""
    results = {"status": "PASS", "output": "", "errors": []}

    # Find all subdirectories with .j2 files
    template_subdirs = [d for d in template_dir.iterdir() if d.is_dir()]

    for subdir in template_subdirs:
        j2_files = list(subdir.glob("*.j2"))
        if not j2_files:
            continue

        try:
            result = subprocess.run(
                ["j2lint", str(subdir)],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode != 0:
                results["status"] = "WARN"
                results["errors"].append({
                    "directory": subdir.name,
                    "output": result.stdout + result.stderr,
                })
            results["output"] += f"[{subdir.name}] {result.stdout}"
        except FileNotFoundError:
            results["status"] = "SKIP"
            results["output"] = "j2lint not installed. Install: pip install j2lint"
            return results
        except subprocess.TimeoutExpired:
            results["status"] = "FAIL"
            results["errors"].append({
                "directory": subdir.name,
                "output": "Timeout after 30 seconds",
            })

    return results


def run_compile_dryrun(device: str | None = None) -> list[dict]:
    """Run deploy.py --compile-only as a dry-run validation."""
    results = []
    deploy_script = PROJECT_ROOT / "scripts" / "deploy.py"

    if not deploy_script.exists():
        return [{"status": "SKIP", "error": "deploy.py not found"}]

    cmd = [sys.executable, str(deploy_script), "--compile-only"]
    if device:
        cmd.extend(["--device", device])

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,
        )
        results.append({
            "status": "PASS" if result.returncode == 0 else "FAIL",
            "output": result.stdout,
            "errors": result.stderr if result.returncode != 0 else None,
        })
    except subprocess.TimeoutExpired:
        results.append({"status": "FAIL", "error": "Compile timed out"})

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Validate Jinja2 templates and intent YAML configs."
    )
    parser.add_argument(
        "--device",
        help="Validate specific device (e.g., spine1).",
    )
    parser.add_argument(
        "--lint-only",
        action="store_true",
        help="Run j2lint and YAML validation only (no compile).",
    )
    args = parser.parse_args()

    all_pass = True
    print("═══ AIOps Config Validation ═══")
    print()

    # Step 1: YAML Syntax
    print("Step 1: YAML Syntax Validation")
    yaml_results = validate_yaml_syntax(INTENT_DIR, args.device)
    for r in yaml_results:
        status_icon = "✓" if r["status"] == "PASS" else "✗"
        print(f"  {status_icon} {r['file']:20s} {r['status']}")
        if r["error"]:
            print(f"    Error: {r['error']}")
            all_pass = False
    print()

    # Step 2: j2lint
    print("Step 2: Jinja2 Template Linting")
    j2_results = run_j2lint(TEMPLATE_DIR)
    print(f"  Status: {j2_results['status']}")
    if j2_results["output"]:
        for line in j2_results["output"].strip().splitlines():
            print(f"    {line}")
    if j2_results["errors"]:
        all_pass = False
        for err in j2_results["errors"]:
            print(f"  ✗ {err['directory']}: {err['output'][:200]}")
    print()

    # Step 3: Compile dry-run
    if not args.lint_only:
        print("Step 3: Compile Dry-Run")
        compile_results = run_compile_dryrun(args.device)
        for r in compile_results:
            print(f"  Status: {r['status']}")
            if r.get("output"):
                for line in r["output"].strip().splitlines():
                    print(f"    {line}")
            if r.get("errors"):
                all_pass = False
                print(f"  Error: {r['errors'][:300]}")
        print()

    # Summary
    print("═══ Result ═══")
    if all_pass:
        print("  ✓ All validations PASSED")
        sys.exit(0)
    else:
        print("  ✗ Some validations FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
