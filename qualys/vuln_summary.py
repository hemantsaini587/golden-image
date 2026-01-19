#!/usr/bin/env python3
import argparse
import os
import json
import xml.etree.ElementTree as ET
from collections import Counter
from qualys.client import QualysClient

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host-id", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    user = os.environ.get("QUALYS_USERNAME")
    pwd = os.environ.get("QUALYS_PASSWORD")
    if not user or not pwd:
        raise SystemExit("ERROR: QUALYS_USERNAME / QUALYS_PASSWORD env vars not set")

    client = QualysClient(user, pwd)

    r = client.get(
        "/api/2.0/fo/asset/host/vm/detection/",
        params={
            "action": "list",
            "ids": args.host_id,
            "show_results": 1,
            "truncation_limit": 0
        }
    )

    root = ET.fromstring(r.text)
    sev_counter = Counter()

    for det in root.findall(".//DETECTION"):
        sev = det.findtext("SEVERITY")
        if sev:
            try:
                sev_counter[int(sev)] += 1
            except ValueError:
                pass

    summary = {
        "host_id": args.host_id,
        "severity_5_critical": sev_counter.get(5, 0),
        "severity_4_high": sev_counter.get(4, 0),
        "severity_3_medium": sev_counter.get(3, 0),
        "severity_2_low": sev_counter.get(2, 0),
        "severity_1_info": sev_counter.get(1, 0)
    }

    with open(args.out, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"[INFO] Vulnerability summary written: {args.out}")
    print(summary)

if __name__ == "__main__":
    main()
