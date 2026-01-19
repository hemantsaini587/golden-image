#!/usr/bin/env python3
import argparse
import yaml
import json
import sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--config", required=True)
    p.add_argument("--os", required=True)
    p.add_argument("--platform", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    with open(args.config, "r") as f:
        cfg = yaml.safe_load(f)

    for img in cfg.get("images", []):
        if img.get("os") == args.os and img.get("platform") == args.platform:
            with open(args.out, "w") as out:
                json.dump(img, out, indent=2)
            print(f"[INFO] Selected image config written to {args.out}")
            return

    print(f"[ERROR] No image found for os={args.os}, platform={args.platform}", file=sys.stderr)
    sys.exit(2)

if __name__ == "__main__":
    main()
