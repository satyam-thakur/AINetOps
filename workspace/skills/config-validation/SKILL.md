---
name: config-validation
description: "Validate Jinja2 templates and intent YAML configs. Use before deploying to catch syntax errors, lint issues, and schema problems."
user-invocable: true
metadata:
  { "openclaw": { "requires": { "bins": ["python3", "j2lint"] } } }
---

# Config Validation

Validate templates and intent configs before deployment.

## Quick Commands

```bash
# Full validation (lint + YAML + compile dry-run)
python3 scripts/validate.py

# Lint only (no compile)
python3 scripts/validate.py --lint-only

# Validate specific device
python3 scripts/validate.py --device spine1
```

## What It Checks

1. **YAML Syntax** — validates `configs/intent_config/*.yaml` parse correctly
2. **j2lint** — runs Jinja2 linter on `configs/templates/` subdirectories
3. **Compile Dry-Run** — renders templates to check for missing variables

## j2lint Error Reference

| Error Code | Meaning | Fix |
|-----------|---------|-----|
| `jinja-statements-indentation` | Bad Jinja2 block indentation | Align `{% %}` blocks to proper indent level |
| `jinja-statements-delimiter` | Missing/extra spaces in delimiters | Use `{% %}` and `{{ }}` with single spaces |
| `jinja-statements-no-tabs` | Tab characters in template | Replace tabs with spaces |

## Exit Codes

- `0` — All validations passed
- `1` — One or more validations failed (do NOT deploy)
