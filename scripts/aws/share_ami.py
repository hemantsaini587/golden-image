#!/usr/bin/env python3
import argparse
import boto3
import time
from typing import List

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
    # Share AMI
    ec2.modify_image_attribute(
        ImageId=image_id,
        LaunchPermission={"Add": [{"UserId": a} for a in account_ids]}
    )

    # Share snapshots
    snaps = get_snapshot_ids(ec2, image_id)
    for sid in snaps:
        ec2.modify_snapshot_attribute(
            SnapshotId=sid,
            Attribute="createVolumePermission",
            OperationType="add",
            UserIds=account_ids
        )

def copy_ami_to_region(src_region: str, dst_region: str, image_id: str, name: str,
                       encrypted: bool, kms_key_id: str | None):
    src = boto3.client("ec2", region_name=src_region)
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
    p.add_argument("--target-regions", default="", help="Comma-separated regions")
    p.add_argument("--target-accounts", default="", help="Comma-separated AWS account IDs")
    p.add_argument("--kms-encrypt", action="store_true")
    p.add_argument("--kms-key-id", default="", help="Optional KMS Key ARN/ID for target region copy")
    p.add_argument("--name-prefix", default="golden-shared")
    args = p.parse_args()

    target_regions = [r.strip() for r in args.target_regions.split(",") if r.strip()]
    target_accounts = [a.strip() for a in args.target_accounts.split(",") if a.strip()]

    src_ec2 = boto3.client("ec2", region_name=args.source_region)

    # Share in source region first (optional)
    if target_accounts:
        print(f"[INFO] Sharing AMI {args.source_ami} in {args.source_region} with accounts {target_accounts}")
        share_ami_and_snapshots(src_ec2, args.source_ami, target_accounts)

    # Copy to other regions
    copied = {}
    for r in target_regions:
        name = f"{args.name_prefix}-{r}-{int(time.time())}"
        print(f"[INFO] Copying AMI {args.source_ami} from {args.source_region} to {r} (encrypt={args.kms_encrypt})")
        new_ami = copy_ami_to_region(
            src_region=args.source_region,
            dst_region=r,
            image_id=args.source_ami,
            name=name,
            encrypted=args.kms_encrypt,
            kms_key_id=args.kms_key_id if args.kms_key_id else None
        )
        copied[r] = new_ami
        print(f"[INFO] Copied AMI in {r}: {new_ami}")

        if target_accounts:
            dst_ec2 = boto3.client("ec2", region_name=r)
            print(f"[INFO] Sharing copied AMI {new_ami} in {r} with accounts {target_accounts}")
            share_ami_and_snapshots(dst_ec2, new_ami, target_accounts)

    print("[INFO] Share AMI completed.")
    print("[INFO] Copied AMIs:", copied)

if __name__ == "__main__":
    main()
