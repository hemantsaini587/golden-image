#!/usr/bin/env python3
import argparse
import time
import boto3
from scripts.aws.utils import parse_csv, parse_kms_map

def wait_for_ami(ec2, ami_id, region):
    print(f"[INFO] Waiting for AMI {ami_id} in {region}...")
    while True:
        resp = ec2.describe_images(ImageIds=[ami_id])
        state = resp["Images"][0]["State"]
        if state == "available":
            print(f"[INFO] AMI {ami_id} is available in {region}")
            return
        print(f"[INFO] AMI state={state}. Sleeping 20s...")
        time.sleep(20)

def get_snapshots(ec2, ami_id):
    resp = ec2.describe_images(ImageIds=[ami_id])
    snaps = []
    for m in resp["Images"][0].get("BlockDeviceMappings", []):
        ebs = m.get("Ebs")
        if ebs and ebs.get("SnapshotId"):
            snaps.append(ebs["SnapshotId"])
    return snaps

def share_ami_and_snapshots(ec2, ami_id, snapshots, accounts):
    print(f"[INFO] Sharing AMI {ami_id} with {accounts}")
    ec2.modify_image_attribute(
        ImageId=ami_id,
        LaunchPermission={"Add": [{"UserId": a} for a in accounts]}
    )

    for snap in snapshots:
        print(f"[INFO] Sharing Snapshot {snap} with {accounts}")
        ec2.modify_snapshot_attribute(
            SnapshotId=snap,
            Attribute="createVolumePermission",
            OperationType="add",
            UserIds=accounts
        )

def copy_ami(source_region, target_region, source_ami_id, encrypt, kms_key):
    ec2 = boto3.client("ec2", region_name=target_region)
    args = {
        "Name": f"golden-copy-{source_ami_id}-{int(time.time())}",
        "SourceImageId": source_ami_id,
        "SourceRegion": source_region
    }
    if encrypt:
        args["Encrypted"] = True
        if kms_key:
            args["KmsKeyId"] = kms_key

    resp = ec2.copy_image(**args)
    return resp["ImageId"]

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-ami-id", required=True)
    p.add_argument("--source-region", required=True)
    p.add_argument("--target-regions", required=True)
    p.add_argument("--share-accounts", required=True)
    p.add_argument("--enable-encryption", required=True)
    p.add_argument("--kms-key-map", default="")
    args = p.parse_args()

    targets = parse_csv(args.target_regions)
    accounts = parse_csv(args.share_accounts)
    encrypt = str(args.enable_encryption).lower() == "true"
    kms_map = parse_kms_map(args.kms_key_map)

    for region in targets:
        kms_key = kms_map.get(region)
        copied_ami = copy_ami(args.source_region, region, args.source_ami_id, encrypt, kms_key)

        ec2 = boto3.client("ec2", region_name=region)
        wait_for_ami(ec2, copied_ami, region)

        snaps = get_snapshots(ec2, copied_ami)
        print(f"[INFO] Copied AMI {copied_ami} snapshots: {snaps}")

        share_ami_and_snapshots(ec2, copied_ami, snaps, accounts)
        print(f"[SUCCESS] Shared AMI {copied_ami} in {region}")

if __name__ == "__main__":
    main()
