#!/usr/bin/env python3
import argparse
import json
import re

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--packer-log", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    ami_id = None
    with open(args.packer_log, "r") as f:
        for line in f:
            m = re.search(r"(ami-[0-9a-fA-F]{8,})", line)
            if m:
                ami_id = m.group(1)

    if not ami_id:
        raise SystemExit("ERROR: AMI ID not found in packer log")

    with open(args.out, "w") as f:
        json.dump({"golden_ami_id": ami_id}, f, indent=2)

    print(f"[INFO] Extracted AMI ID: {ami_id}")

if __name__ == "__main__":
    main()
