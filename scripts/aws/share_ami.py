#!/usr/bin/env python3
import argparse
import boto3
import time
import json
from typing import List, Dict

def wait_for_image(ec2, image_id: str, timeout=3600):
    deadline = time.time() + timeout
    while time.time() < deadline:
        resp = ec2.describe_images(ImageIds=[image_id])
        state = resp["Images"][0]["State"]
        if state == "available":
            return
        if state in ["failed", "error"]:
            raise RuntimeError(f"AMI {image_id} entered failure state: {state}")
        time.sleep(20)
    raise TimeoutError(f"Timed out waiting for AMI {image_id} to become available")

def get_snapshot_ids(ec2, image_id: str) -> List[str]:
    resp = ec2.describe_images(ImageIds=[image_id])
    mappings = resp["Images"][0].get("BlockDeviceMappings", [])
    snap_ids = []
    for m in mappings:
        ebs = m.get("Ebs", {})
        sid = ebs.get("SnapshotId")
        if sid:
            snap_ids.append(sid)
    return snap_ids

def share_ami_and_snapshots(ec2, image_id: str, account_ids: List[str]):
    if not account_ids:
        return

    ec2.modify_image_attribute(
        ImageId=image_id,
        LaunchPermission={"Add": [{"UserId": a} for a in account_ids]}
    )

    snaps = get_snapshot_ids(ec2, image_id)
    for sid in snaps:
        ec2.modify_snapshot_attribute(
            SnapshotId=sid,
            Attribute="createVolumePermission",
            OperationType="add",
            UserIds=account_ids
        )

def tag_image(ec2, image_id: str, tags: Dict[str, str]):
    ec2.create_tags(
        Resources=[image_id],
        Tags=[{"Key": k, "Value": v} for k, v in tags.items()]
    )

def copy_ami_to_region(src_region: str, dst_region: str, image_id: str, name: str,
                       encrypted: bool, kms_key_id: str | None):
    dst = boto3.client("ec2", region_name=dst_region)

    copy_args = {
        "SourceRegion": src_region,
        "SourceImageId": image_id,
        "Name": name
    }

    if encrypted:
        copy_args["Encrypted"] = True
        if kms_key_id:
            copy_args["KmsKeyId"] = kms_key_id

    resp = dst.copy_image(**copy_args)
    new_image_id = resp["ImageId"]
    wait_for_image(dst, new_image_id)
    return new_image_id

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-region", required=True)
    p.add_argument("--source-ami", required=True)
    p.add_argument("--target-regions", default="")
    p.add_argument("--target-accounts", default="")
    p.add_argument("--kms-encrypt", action="store_true")
    p.add_argument("--kms-key-id", default="")
    p.add_argument("--name-prefix", default="golden-shared")
    p.add_argument("--manifest-out", default="output/share_manifest.json")
    args = p.parse_args()

    target_regions = [r.strip() for r in args.target_regions.split(",") if r.strip()]
    target_accounts = [a.strip() for a in args.target_accounts.split(",") if a.strip()]

    src_ec2 = boto3.client("ec2", region_name=args.source_region)

    manifest = {
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_region": args.source_region,
        "source_ami": args.source_ami,
        "target_accounts": target_accounts,
        "kms_encrypt": args.kms_encrypt,
        "kms_key_id": args.kms_key_id if args.kms_key_id else None,
        "target_regions": {}
    }

    # Share in source region (if requested)
    if target_accounts:
        share_ami_and_snapshots(src_ec2, args.source_ami, target_accounts)

    # Copy/share to regions
    for r in target_regions:
        name = f"{args.name_prefix}-{r}-{int(time.time())}"
        new_ami = copy_ami_to_region(
            src_region=args.source_region,
            dst_region=r,
            image_id=args.source_ami,
            name=name,
            encrypted=args.kms_encrypt,
            kms_key_id=args.kms_key_id if args.kms_key_id else None
        )

        dst_ec2 = boto3.client("ec2", region_name=r)

        tag_image(dst_ec2, new_ami, {
            "ImageType": "Golden",
            "CopiedFrom": args.source_ami,
            "SourceRegion": args.source_region,
            "ManagedBy": "GoldenImageFactory"
        })

        if target_accounts:
            share_ami_and_snapshots(dst_ec2, new_ami, target_accounts)

        manifest["target_regions"][r] = {
            "copied_ami": new_ami,
            "shared_accounts": target_accounts
        }

    # Write manifest
    import os
    os.makedirs(os.path.dirname(args.manifest_out), exist_ok=True)
    with open(args.manifest_out, "w") as f:
        json.dump(manifest, f, indent=2)

    print("[INFO] Share AMI completed.")
    print("[INFO] Manifest written:", args.manifest_out)

if __name__ == "__main__":
    main()