#!/usr/bin/env python3
import argparse
import os
import time
import xml.etree.ElementTree as ET
from scripts.common.time_utils import utc_timestamp_compact
from qualys.client import QualysClient

def create_report(client: QualysClient, template_id: str, host_id: str):
    """
    Qualys Report API (classic):
      /api/2.0/fo/report/?action=launch
    """
    r = client.post(
        "/api/2.0/fo/report/",
        data={
            "action": "launch",
            "template_id": template_id,
            "output_format": "pdf",
            "report_type": "Scan",
            "asset_group_ids": "",  # optional
            "ips": "",              # optional
            "host_ids": host_id
        }
    )
    root = ET.fromstring(r.text)
    report_id = root.findtext(".//VALUE")
    if not report_id:
        raise RuntimeError(f"Failed to launch report: {r.text}")
    return report_id.strip()

def wait_report_finished(client: QualysClient, report_id: str, timeout=1200):
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = client.get(
            "/api/2.0/fo/report/",
            params={"action": "list", "id": report_id}
        )
        root = ET.fromstring(r.text)
        state = root.findtext(".//STATUS/STATE")
        if state and state.lower() == "finished":
            return True
        time.sleep(20)
    return False

def download_report(client: QualysClient, report_id: str, outpath: str):
    r = client.get(
        "/api/2.0/fo/report/",
        params={"action": "fetch", "id": report_id}
    )
    with open(outpath, "wb") as f:
        f.write(r.content)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--phase", required=True, choices=["pre", "post"])
    p.add_argument("--os", required=True)
    p.add_argument("--host-id", required=True)
    p.add_argument("--outdir", required=True)
    args = p.parse_args()

    user = os.environ.get("QUALYS_USERNAME")
    pwd = os.environ.get("QUALYS_PASSWORD")
    template_id = os.environ.get("QUALYS_REPORT_TEMPLATE_ID")

    if not user or not pwd:
        raise SystemExit("ERROR: QUALYS_USERNAME/QUALYS_PASSWORD not set")
    if not template_id:
        raise SystemExit("ERROR: QUALYS_REPORT_TEMPLATE_ID not set")

    client = QualysClient(user, pwd)

    ts = utc_timestamp_compact()
    fname = f"{'pre' if args.phase=='pre' else 'post'}-hardening-report-{args.os}-{ts}.pdf"
    outpath = os.path.join(args.outdir, fname)

    report_id = create_report(client, template_id, args.host_id)
    print(f"[INFO] Report launched: {report_id}")

    ok = wait_report_finished(client, report_id)
    if not ok:
        raise SystemExit("[ERROR] Report generation timed out")

    download_report(client, report_id, outpath)
    print(f"[INFO] Report downloaded: {outpath}")

if __name__ == "__main__":
    main()
