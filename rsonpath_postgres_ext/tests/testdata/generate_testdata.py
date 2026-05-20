#!/usr/bin/env python3
"""Generate large JSON test data for rsonpath_postgres_ext benchmarks.

Deterministic (seeded RNG) so the output is identical on every run.
"""

from faker import Faker
import json
import os
import random
import string
import sys

SEED = 42

Faker.seed(SEED)
fake = Faker()

SIZE_90_MB = 400_000
SIZE_180_MB = 800_000
SIZE_225_MB = 1_000_000
SIZE_450_MB = 2_000_000
SIZE_900_MB = 4_000_000
SIZE_2_GB = 2 * SIZE_900_MB

NUM_RECORDS = 10_000
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "large.json")
OUTPUT_FILE_JSONL = os.path.join(OUTPUT_DIR, "large.jsonl")


HOBBIES = ["reading", "cycling", "cooking", "gaming", "hiking", "swimming", "painting", "coding", "traveling", "photography"]


def rand_str(n=8):
    return "".join(random.choices(string.ascii_lowercase, k=n))


def rand_phone():
    return f"{random.randint(100,999)}-{random.randint(100,999)}-{random.randint(1000,9999)}"


def generate_jsonl():
    """
    Generates a JSONL file where each line is a separate JSON object.
    1 in 10 records will have a "hobby" key with a list of hobbies,
    """
    print("###########################################")
    print("######## RUNNING generate_jsonl ###########")
    print("###########################################")
    random.seed(SEED)
    
    bytes_written = 0
    with open(OUTPUT_FILE_JSONL, "w") as f:
        for i in range(NUM_RECORDS):
            record = {
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
            }
            
            # 10% rows gets the 'hobby' key
            if random.random() < 0.10:
                record["hobby"] = random.sample(HOBBIES, random.randint(3, 5))
                
            # Convert dict to JSON string without pretty formatting, then add a newline
            row_json = json.dumps(record, separators=(",", ":"))
            f.write(row_json + "\n")
            bytes_written += len(row_json) + 1

    size_mb = bytes_written / 1024 / 1024
    print(f"Generated JSONL {OUTPUT_FILE_JSONL} ({bytes_written} bytes, {size_mb:.1f} MB)")

def generate_jsonl_2():
    """
    Generates a JSONL file where each line is a separate JSON object.
    1 in 10 records will have a "hobby" key with a list of hobbies,
    """
    print("###########################################")
    print("######## RUNNING generate_jsonl ###########")
    print("###########################################")
    random.seed(SEED)
    word_pool = [fake.word() for _ in range(1000)]
    country_pool = [fake.country() for _ in range(250)]
    city_pool = [fake.city() for _ in range(500)]

    # Generates jsons of size around 1MB 
    bytes_written = 0
    with open(OUTPUT_FILE_JSONL, "w") as f:
        for i in range(NUM_RECORDS):
            if i % 100 == 0:
                print(f"i: {i}")
            record = {
                "id": i,
                "name1": f"person_{i}",
                "active1": i % 2 == 0,
                "email1": f"person_{i}@example.com",
                "phone1": rand_phone(),
                "tags1": random.choices(word_pool, k=15000),
                "address1": {
                    "city1": f"city_{i % 200}",
                    "zip1": str(10000 + i % 90000),
                    "street1": f"{random.randint(1,999)} {rand_str(6)} St",
                },
                "nested1" :{
                    "nested2": {
                        "countries": random.choices(country_pool, k=30000)
                    }
                },
                "scores1": [random.randint(1000, 10000) for _ in range(random.randint(200, 3000))],
                "name2": f"person_{i}",
                "active2": i % 2 == 0,
                "email2": f"person_{i}@example.com",
                "phone2": rand_phone(),
                "tags2": random.choices(word_pool, k=15000),
                "address2": {
                    "city2": f"city_{i % 200}",
                    "zip2": str(10000 + i % 90000),
                    "street2": f"{random.randint(1,999)} {rand_str(6)} St",
                },
                "scores2": [random.randint(1000, 10000) for _ in range(random.randint(200, 3000))],

                "cities": random.choices(city_pool, k=30000),
            }
            
            # 10% rows gets the 'hobby' key
            if random.random() < 0.10:
                record["hobby"] = random.sample(HOBBIES, random.randint(3, 5))
                
            # Convert dict to JSON string without pretty formatting, then add a newline
            row_json = json.dumps(record, separators=(",", ":"))
            # record_size_bytes = len(row_json.encode('utf-8'))
            # print(f"Size of single record: {record_size_bytes / (1024.0*1024.0)} MB")
            f.write(row_json + "\n")
            bytes_written += len(row_json) + 1

    size_mb = bytes_written / 1024 / 1024
    print(f"Generated JSONL {OUTPUT_FILE_JSONL} ({bytes_written} bytes, {size_mb:.1f} MB)")

def generate_json():
    print("###########################################")
    print("######### RUNNING generate_json ###########")
    print("###########################################")
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

def main():
    generate_jsonl_2()

if __name__ == "__main__":
    main()
