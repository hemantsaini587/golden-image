#!/usr/bin/env python3
import argparse
import subprocess
from qualys.tuning import load_tuning

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--os", required=True)
    p.add_argument("--dns", required=True)
    p.add_argument("--ip", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--tuning-file", default="config/qualys_tuning.yml")
    args = p.parse_args()

    t = load_tuning(args.tuning_file, args.os)

    cmd = [
        "python3", "qualys/host_lookup.py",
        "--dns", args.dns,
        "--ip", args.ip,
        "--timeout-seconds", str(t["lookup_timeout_seconds"]),
        "--poll-seconds", str(t["poll_seconds"]),
        "--out", args.out
    ]

    subprocess.check_call(cmd)

if __name__ == "__main__":
    main()
