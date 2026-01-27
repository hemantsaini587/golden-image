#!/usr/bin/env python3
import argparse
import boto3
import json
import time
import os

def assume_role(role_arn, session_name):
    sts = boto3.client("sts")
    resp = sts.assume_role(
        RoleArn=role_arn,
        RoleSessionName=session_name
    )
    creds = resp["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"]
    )

def wait_for_ami(ec2, ami_id, timeout=3600):
    end = time.time() + timeout
    while time.time() < end:
        img = ec2.describe_images(ImageIds=[ami_id])["Images"][0]
        if img["State"] == "available":
            return
        if img["State"] in ["failed", "error"]:
            raise RuntimeError(f"AMI {ami_id} failed")
        time.sleep(20)
    raise TimeoutError(f"Timeout waiting for {ami_id}")

def resolve_kms_key(region):
    kms = boto3.client("kms", region_name=region)
    alias_name = f"alias/golden-ami-{region}"

    aliases = kms.list_aliases()["Aliases"]
    for a in aliases:
        if a["AliasName"] == alias_name:
            return a["TargetKeyId"]

    raise RuntimeError(f"KMS alias not found: {alias_name}")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-region", required=True)
    p.add_argument("--source-ami", required=True)
    p.add_argument("--target-region", required=True)
    p.add_argument("--child-account-id", required=True)
    p.add_argument("--child-role-name", required=True)
    p.add_argument("--kms-key-arn", required=True)
    p.add_argument("--name-prefix", default="golden")
    p.add_argument("--manifest-out", default="output/share_manifest.json")
    args = p.parse_args()

    role_arn = f"arn:aws:iam::{args.child_account_id}:role/{args.child_role_name}"
    session = assume_role(role_arn, "GoldenImageShare")

    ec2 = session.client("ec2", region_name=args.target_region)

    name = f"{args.name_prefix}-{args.target_region}-{int(time.time())}"

    print(f"[INFO] Copying AMI into child account {args.child_account_id}")
    print(f"[INFO] Encryption key: {args.kms_key_arn}")

    resp = ec2.copy_image(
        SourceRegion=args.source_region,
        SourceImageId=args.source_ami,
        Name=name,
        Encrypted=True,
        KmsKeyId=args.kms_key_arn
    )

    new_ami = resp["ImageId"]
    wait_for_ami(ec2, new_ami)

    ec2.create_tags(
        Resources=[new_ami],
        Tags=[
            {"Key": "ImageType", "Value": "Golden"},
            {"Key": "ManagedBy", "Value": "GoldenImageFactory"},
            {"Key": "CopiedFrom", "Value": args.source_ami}
        ]
    )

    manifest = {
        "source_ami": args.source_ami,
        "source_region": args.source_region,
        "child_account": args.child_account_id,
        "target_region": args.target_region,
        "encrypted": True,
        "kms_key": args.kms_key_arn,
        "copied_ami": new_ami
    }

    os.makedirs(os.path.dirname(args.manifest_out), exist_ok=True)
    with open(args.manifest_out, "w") as f:
        json.dump(manifest, f, indent=2)

    print("[SUCCESS] Encrypted AMI copied into child account")
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()

