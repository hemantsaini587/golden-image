#!/usr/bin/env python3
import argparse
import boto3
import sys

def tags_to_dict(tags):
    if not tags:
        return {}
    return {t["Key"]: t["Value"] for t in tags}

def fail(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(2)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--region", required=True)
    p.add_argument("--ami-id", required=True)
    p.add_argument("--require-managedby", default="GoldenImageFactory")
    p.add_argument("--require-imagetype", default="Golden")
    p.add_argument("--require-os", default="", help="Optional: enforce OS tag equals this value")
    args = p.parse_args()

    ec2 = boto3.client("ec2", region_name=args.region)

    try:
        resp = ec2.describe_images(ImageIds=[args.ami_id])
    except Exception as e:
        fail(f"Unable to describe AMI {args.ami_id} in {args.region}: {e}")

    images = resp.get("Images", [])
    if not images:
        fail(f"AMI not found: {args.ami_id}")

    img = images[0]
    state = img.get("State", "unknown")
    if state != "available":
        fail(f"AMI {args.ami_id} is not available (state={state})")

    tags = tags_to_dict(img.get("Tags", []))

    # Mandatory validations
    if tags.get("ImageType") != args.require_imagetype:
        fail(f"AMI tag validation failed: ImageType must be '{args.require_imagetype}', got '{tags.get('ImageType')}'")

    if tags.get("ManagedBy") != args.require_managedby:
        fail(f"AMI tag validation failed: ManagedBy must be '{args.require_managedby}', got '{tags.get('ManagedBy')}'")

    # Optional OS enforcement
    if args.require_os:
        if tags.get("OS") != args.require_os:
            fail(f"AMI tag validation failed: OS must be '{args.require_os}', got '{tags.get('OS')}'")

    print("[INFO] AMI tag validation passed.")
    print(f"[INFO] AMI={args.ami_id} Region={args.region}")
    print(f"[INFO] Tags={tags}")

if __name__ == "__main__":
    main()