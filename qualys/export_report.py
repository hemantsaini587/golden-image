#!/usr/bin/env python3
import argparse
import os
import xml.etree.ElementTree as ET
from datetime import datetime

from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

from qualys.client import QualysClient

def utc_ts():
    return datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

def fetch_host_detections(client: QualysClient, host_id: str):
    r = client.get(
        "/api/2.0/fo/asset/host/vm/detection/",
        params={
            "action": "list",
            "ids": host_id,
            "show_results": 1,
            "truncation_limit": 0
        }
    )
    return r.text

def parse_detections(xml_text: str):
    root = ET.fromstring(xml_text)
    detections = []

    for det in root.findall(".//DETECTION"):
        qid = det.findtext("QID", default="").strip()
        severity = det.findtext("SEVERITY", default="").strip()
        title = det.findtext("TITLE", default="").strip()
        cve_list = []

        for cve in det.findall(".//CVE_LIST/CVE"):
            if cve.text:
                cve_list.append(cve.text.strip())

        detections.append({
            "qid": qid,
            "severity": severity,
            "title": title,
            "cves": cve_list
        })

    detections.sort(key=lambda x: (int(x["severity"] or 0), x["qid"]), reverse=True)
    return detections

def generate_pdf(outpath: str, phase: str, os_name: str, host_id: str, detections: list):
    c = canvas.Canvas(outpath, pagesize=letter)
    width, height = letter

    # Audit metadata (optional)
    instance_id = os.environ.get("INSTANCE_ID", "N/A")
    source_ami  = os.environ.get("SOURCE_AMI_ID", "N/A")
    build_num   = os.environ.get("BUILD_NUMBER", "N/A")
    build_url   = os.environ.get("BUILD_URL", "N/A")

    y = height - 50
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, y, f"Qualys Vulnerability Report ({phase.upper()})")
    y -= 20

    c.setFont("Helvetica", 10)
    c.drawString(50, y, f"OS: {os_name}")
    y -= 14
    c.drawString(50, y, f"Qualys Host ID: {host_id}")
    y -= 14
    c.drawString(50, y, f"Instance ID: {instance_id}")
    y -= 14
    c.drawString(50, y, f"Source AMI: {source_ami}")
    y -= 14
    c.drawString(50, y, f"Jenkins Build #: {build_num}")
    y -= 14
    c.drawString(50, y, f"Jenkins URL: {build_url}")
    y -= 14
    c.drawString(50, y, f"Generated (UTC): {datetime.utcnow().isoformat()}Z")
    y -= 20

    sev_count = {"5": 0, "4": 0, "3": 0, "2": 0, "1": 0}
    for d in detections:
        sev = d.get("severity", "")
        if sev in sev_count:
            sev_count[sev] += 1

    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Summary:")
    y -= 14

    c.setFont("Helvetica", 10)
    c.drawString(
        60, y,
        f"Critical (5): {sev_count['5']} | High (4): {sev_count['4']} | "
        f"Medium (3): {sev_count['3']} | Low (2): {sev_count['2']} | Info (1): {sev_count['1']}"
    )
    y -= 20

    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Detections (Top 200):")
    y -= 16

    c.setFont("Helvetica", 9)

    if not detections:
        c.drawString(60, y, "No detections found for this host.")
        c.save()
        return

    for d in detections[:200]:
        line = f"SEV={d['severity']} | QID={d['qid']} | {d['title'][:95]}"
        c.drawString(60, y, line)
        y -= 12

        if d["cves"]:
            c.drawString(80, y, f"CVEs: {', '.join(d['cves'][:10])}")
            y -= 12

        if y < 80:
            c.showPage()
            c.setFont("Helvetica", 9)
            y = height - 50

    c.save()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--phase", required=True, choices=["pre", "post"])
    p.add_argument("--os", required=True)
    p.add_argument("--host-id", required=True)
    p.add_argument("--outdir", required=True)
    args = p.parse_args()

    user = os.environ.get("QUALYS_USERNAME")
    pwd = os.environ.get("QUALYS_PASSWORD")
    if not user or not pwd:
        raise SystemExit("ERROR: QUALYS_USERNAME / QUALYS_PASSWORD env vars not set")

    client = QualysClient(user, pwd)

    ts = utc_ts()
    if args.phase == "pre":
        fname = f"pre-hardening-report-{args.os}-{ts}.pdf"
    else:
        fname = f"post-hardening-report-{args.os}-{ts}.pdf"

    outpath = os.path.join(args.outdir, fname)

    xml_text = fetch_host_detections(client, args.host_id)
    detections = parse_detections(xml_text)
    generate_pdf(outpath, args.phase, args.os, args.host_id, detections)

    print(f"[INFO] Real PDF report generated: {outpath}")
    print(f"[INFO] Total detections: {len(detections)}")

if __name__ == "__main__":
    main()
