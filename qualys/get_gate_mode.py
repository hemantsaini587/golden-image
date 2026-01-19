#!/usr/bin/env python3
import argparse
from qualys.tuning import load_tuning

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--os", required=True)
    p.add_argument("--tuning-file", default="config/qualys_tuning.yml")
    args = p.parse_args()

    t = load_tuning(args.tuning_file, args.os)
    print(t.get("gate_mode", "HIGH"))

if __name__ == "__main__":
    main()
