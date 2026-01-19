def parse_csv(value: str):
    return [x.strip() for x in value.split(",") if x.strip()]

def parse_kms_map(value: str):
    out = {}
    if not value:
        return out
    for pair in value.split(","):
        pair = pair.strip()
        if "=" in pair:
            r, k = pair.split("=", 1)
            out[r.strip()] = k.strip()
    return out
