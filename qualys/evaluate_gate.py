#!/usr/bin/env python3
import argparse
import json
import sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--summary-json", required=True)
    p.add_argument("--fail-on", required=True, choices=["CRITICAL", "HIGH", "NONE"])
    args = p.parse_args()

    if args.fail_on == "NONE":
        print("[INFO] Gate disabled.")
        return

    with open(args.summary_json, "r") as f:
        s = json.load(f)

    critical = int(s.get("severity_5_critical", 0))
    high = int(s.get("severity_4_high", 0))

    print(f"[INFO] Gate check: critical={critical}, high={high}, mode={args.fail_on}")

    if args.fail_on == "CRITICAL" and critical > 0:
        print("[ERROR] Gate failed: CRITICAL vulnerabilities detected.")
        sys.exit(2)

    if args.fail_on == "HIGH" and (critical > 0 or high > 0):
        print("[ERROR] Gate failed: HIGH/CRITICAL vulnerabilities detected.")
        sys.exit(2)

    print("[INFO] Gate passed.")

if __name__ == "__main__":
    main()
