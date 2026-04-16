#!/usr/bin/env python3
"""Generate large JSON test data for rsonpath_postgres_ext benchmarks.

Deterministic (seeded RNG) so the output is identical on every run.
"""

import json
import os
import random
import string
import sys

SEED = 42
SIZE_90_MB = 400_000
SIZE_180_MB = 800_000
SIZE_225_MB = 1_000_000
SIZE_450_MB = 2_000_000
SIZE_900_MB = 4_000_000

NUM_RECORDS = SIZE_450_MB 
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "large.json")


def rand_str(n=8):
    return "".join(random.choices(string.ascii_lowercase, k=n))


def rand_phone():
    return f"{random.randint(100,999)}-{random.randint(100,999)}-{random.randint(1000,9999)}"


def main():
    random.seed(SEED)

    records = []
    for i in range(NUM_RECORDS):
        records.append({
            "id": i,
            "name": f"person_{i}",
            "active": i % 2 == 0,
            "email": f"person_{i}@example.com",
            "phone": rand_phone(),
            "tags": [rand_str(5) for _ in range(random.randint(1, 5))],
            "address": {
                "city": f"city_{i % 200}",
                "zip": str(10000 + i % 90000),
                "street": f"{random.randint(1,999)} {rand_str(6)} St",
            },
            "scores": [random.randint(0, 100) for _ in range(random.randint(1, 8))],
        })

    data = {"records": records}
    s = json.dumps(data, separators=(",", ":"))

    with open(OUTPUT_FILE, "w") as f:
        f.write(s)

    size_mb = len(s) / 1024 / 1024
    print(f"Generated {OUTPUT_FILE} ({len(s)} bytes, {size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
