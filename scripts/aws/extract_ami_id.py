#!/usr/bin/env python3
import argparse
import json
import sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--manifest", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    with open(args.manifest, "r") as f:
        data = json.load(f)

    # Packer manifest format:
    # {
    #   "builds": [
    #     {
    #       "artifact_id": "us-east-1:ami-0abc123...",
    #       ...
    #     }
    #   ]
    # }
    builds = data.get("builds", [])
    if not builds:
        print("ERROR: No builds found in manifest", file=sys.stderr)
        sys.exit(2)

    artifact_id = builds[-1].get("artifact_id", "")
    if ":" not in artifact_id:
        print(f"ERROR: Unexpected artifact_id format: {artifact_id}", file=sys.stderr)
        sys.exit(2)

    region, ami_id = artifact_id.split(":", 1)

    with open(args.out, "w") as f:
        f.write(ami_id.strip())

    print(f"[INFO] Extracted AMI ID: {ami_id.strip()} (region={region})")

if __name__ == "__main__":
    main()