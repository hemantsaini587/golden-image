#!/usr/bin/env python3
import yaml

def load_tuning(path: str, os_name: str):
    with open(path, "r") as f:
        cfg = yaml.safe_load(f)

    defaults = cfg.get("defaults", {})
    overrides = cfg.get("os_overrides", {}).get(os_name, {})

    merged = dict(defaults)
    merged.update(overrides)
    return merged
