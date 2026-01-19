#!/usr/bin/env python3
import argparse
import json
from datetime import datetime

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--os", required=True)
    p.add_argument("--platform", required=True)
    p.add_argument("--artifact-id", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    manifest = {
        "os": args.os,
        "platform": args.platform,
        "artifact_id": args.artifact_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

    with open(args.out, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"[INFO] Manifest written to {args.out}")

if __name__ == "__main__":
    main()
