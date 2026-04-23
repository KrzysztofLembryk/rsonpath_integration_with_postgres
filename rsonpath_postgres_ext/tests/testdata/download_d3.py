#!/usr/bin/env python3
"""Download the D3 (DBLP Discovery Dataset) papers JSONL.

Source: https://zenodo.org/records/7071698
Downloads ~3.5 GB compressed, decompresses to ~14.7 GB (~5.9M papers).
"""

import gzip
import os
import shutil
import urllib.request
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
D3_DIR = os.path.join(SCRIPT_DIR, "d3")
PAPERS_GZ = os.path.join(D3_DIR, "papers.jsonl.gz")
PAPERS_FULL = os.path.join(D3_DIR, "papers.jsonl")

DOWNLOAD_URL = "https://zenodo.org/records/7071698/files/2022-11-30-papers.jsonl.gz"


def download():
    if os.path.exists(PAPERS_FULL):
        print(f"Already decompressed: {PAPERS_FULL}")
        return
    if os.path.exists(PAPERS_GZ):
        print(f"Already downloaded: {PAPERS_GZ}")
    else:
        os.makedirs(D3_DIR, exist_ok=True)
        print(f"Downloading D3 papers (~3.5 GB)...")
        print(f"URL: {DOWNLOAD_URL}")

        def progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            if total_size > 0:
                pct = min(100, downloaded * 100 // total_size)
                mb = downloaded / (1024 * 1024)
                total_mb = total_size / (1024 * 1024)
                print(f"\r  {mb:.0f} / {total_mb:.0f} MB ({pct}%)", end="", flush=True)

        urllib.request.urlretrieve(DOWNLOAD_URL, PAPERS_GZ, reporthook=progress)
        print("\nDownload complete.")

    print("Decompressing (this may take a few minutes)...")
    with gzip.open(PAPERS_GZ, "rb") as f_in:
        with open(PAPERS_FULL, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)
    print(f"Decompressed: {PAPERS_FULL}")


def summary():
    if not os.path.exists(PAPERS_FULL):
        print("No data found. Run this script to download.")
        return

    size_mb = os.path.getsize(PAPERS_FULL) / (1024 * 1024)
    line_count = sum(1 for _ in open(PAPERS_FULL, "rb"))

    print()
    print("=== D3 Dataset Ready ===")
    print(f"File:   {PAPERS_FULL}")
    print(f"Size:   {size_mb:.0f} MB")
    print(f"Papers: {line_count}")


if __name__ == "__main__":
    download()
    summary()
