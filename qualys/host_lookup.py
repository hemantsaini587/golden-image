#!/usr/bin/env python3
import argparse
import os
import time
import xml.etree.ElementTree as ET
from qualys.client import QualysClient

def find_host_id_by_dns(client: QualysClient, dns: str):
    r = client.get(
        "/api/2.0/fo/asset/host/",
        params={"action": "list", "details": "Basic", "dns": dns}
    )
    root = ET.fromstring(r.text)
    for host in root.findall(".//HOST"):
        host_id = host.findtext("ID")
        if host_id:
            return host_id.strip()
    return None

def find_host_id_by_ip(client: QualysClient, ip: str):
    r = client.get(
        "/api/2.0/fo/asset/host/",
        params={"action": "list", "details": "Basic", "ips": ip}
    )
    root = ET.fromstring(r.text)
    for host in root.findall(".//HOST"):
        host_id = host.findtext("ID")
        if host_id:
            return host_id.strip()
    return None

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dns", required=False)
    p.add_argument("--ip", required=False)
    p.add_argument("--timeout-seconds", type=int, default=1200)
    p.add_argument("--poll-seconds", type=int, default=30)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    if not args.dns and not args.ip:
        raise SystemExit("ERROR: Provide --dns or --ip")

    user = os.environ.get("QUALYS_USERNAME")
    pwd = os.environ.get("QUALYS_PASSWORD")
    if not user or not pwd:
        raise SystemExit("ERROR: QUALYS_USERNAME / QUALYS_PASSWORD env vars not set")

    client = QualysClient(user, pwd)

    deadline = time.time() + args.timeout_seconds
    host_id = None

    while time.time() < deadline:
        if args.dns:
            host_id = find_host_id_by_dns(client, args.dns)
        if not host_id and args.ip:
            host_id = find_host_id_by_ip(client, args.ip)

        if host_id:
            print(f"[INFO] Found Qualys Host ID: {host_id}")
            with open(args.out, "w") as f:
                f.write(host_id)
            return

        print("[INFO] Host not found yet in Qualys. Waiting for Cloud Agent check-in...")
        time.sleep(args.poll_seconds)

    raise SystemExit("[ERROR] Timed out waiting for Qualys Host ID")

if __name__ == "__main__":
    main()
