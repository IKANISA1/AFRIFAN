"""Resume raw Drive-to-checkout SHA-256 checks for generated AFRICLUB files.

The input register is the committed 2026-09-28 Drive inventory. Progress is
kept in a local SQLite database beside this script, and can be exported to a
new TSV register without losing completed comparisons.
"""

import argparse
import concurrent.futures
import csv
import gzip
import hashlib
import os
import random
import sqlite3
import threading
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
INPUT = BASE / "full-tree-generated-byte-comparison.tsv.gz"
PROGRESS = BASE / ".generated-byte-progress.sqlite3"
LOCAL = threading.local()
STOP = threading.Event()


def sha256_file(path):
    digest = hashlib.sha256()
    total = 0
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
            total += len(chunk)
    return total, digest.hexdigest()


def download(row):
    path, file_id, prior_bytes, prior_hash = row
    if STOP.is_set():
        return path, file_id, "stopped", None, "", None, "", "quota stop"
    target = (ROOT / path).resolve()
    if not target.is_relative_to(ROOT.resolve()):
        return path, file_id, "unsafe_local_path", None, "", None, "", "path escapes checkout"
    if not target.is_file():
        local_size, local_hash = None, ""
    else:
        try:
            local_size, local_hash = sha256_file(target)
        except OSError as exc:
            return path, file_id, "local_read_error", None, "", None, "", str(exc)[:300]
    if not hasattr(LOCAL, "session"):
        LOCAL.session = requests.Session()
        LOCAL.session.headers.update({"User-Agent": "Mozilla/5.0"})
    url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download"
    for attempt in range(3):
        if STOP.is_set():
            return path, file_id, "stopped", None, "", local_size, local_hash, "quota stop"
        try:
            response = LOCAL.session.get(url, stream=True, timeout=(15, 90))
            response.raise_for_status()
            if "text/html" in response.headers.get("Content-Type", ""):
                html = response.text
                page = BeautifulSoup(html, "html.parser")
                title = page.title.get_text(" ", strip=True) if page.title else ""
                if "quota exceeded" in title.lower() or "quota exceeded" in page.get_text(" ", strip=True).lower():
                    STOP.set()
                    return path, file_id, "quota_exceeded", None, "", local_size, local_hash, title[:300]
                form = page.find("form", action="https://drive.usercontent.google.com/download")
                if form is None:
                    raise RuntimeError("Drive returned HTML without a download confirmation form: " + title[:100])
                params = {item.get("name"): item.get("value") for item in form.find_all("input") if item.get("name")}
                response.close()
                response = LOCAL.session.get(form.get("action"), params=params, stream=True, timeout=(15, 90))
                response.raise_for_status()
                if "text/html" in response.headers.get("Content-Type", ""):
                    page = BeautifulSoup(response.text, "html.parser")
                    title = page.title.get_text(" ", strip=True) if page.title else ""
                    if "quota exceeded" in title.lower() or "quota exceeded" in page.get_text(" ", strip=True).lower():
                        STOP.set()
                        return path, file_id, "quota_exceeded", None, "", local_size, local_hash, title[:300]
                    raise RuntimeError("Drive returned HTML after confirmation: " + title[:100])
            drive_digest = hashlib.sha256()
            drive_size = 0
            for chunk in response.iter_content(1024 * 1024):
                if chunk:
                    drive_digest.update(chunk)
                    drive_size += len(chunk)
            response.close()
            drive_hash = drive_digest.hexdigest()
            if local_size is None:
                status = "local_missing"
            elif drive_size == local_size and drive_hash == local_hash:
                status = "identical"
            else:
                status = "different"
            if local_size != prior_bytes or local_hash != prior_hash:
                status += "_local_changed_since_index"
            return path, file_id, status, drive_size, drive_hash, local_size, local_hash, ""
        except Exception as exc:
            if attempt == 2:
                return path, file_id, "error", None, "", local_size, local_hash, str(exc)[:300]
            time.sleep(2 ** attempt)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=96)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--random", action="store_true")
    args = parser.parse_args()
    db = sqlite3.connect(PROGRESS)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("CREATE TABLE IF NOT EXISTS checks(path TEXT,id TEXT,status TEXT,drive_bytes INTEGER,drive_sha256 TEXT,local_bytes INTEGER,local_sha256 TEXT,error TEXT,PRIMARY KEY(path,id))")
    complete = {(p, i) for p, i in db.execute("SELECT path,id FROM checks WHERE status IN ('identical','different','local_missing','identical_local_changed_since_index','different_local_changed_since_index','local_missing_local_changed_since_index')")}
    rows = []
    with gzip.open(INPUT, "rt", encoding="utf-8", newline="") as source:
        for item in csv.DictReader(source, delimiter="\t"):
            key = (item["drive_path"], item["drive_id"])
            if item["comparison_status"] in ("identical", "different") or key in complete:
                continue
            rows.append((item["drive_path"], item["drive_id"], int(item["local_bytes"]), item["local_sha256"]))
    if args.random:
        random.Random(20260929).shuffle(rows)
    if args.limit:
        rows = rows[:args.limit]
    print(f"pending={len(rows)} workers={args.workers}", flush=True)
    started = time.time()
    processed = 0
    source = iter(rows)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = set()
        for _ in range(min(args.workers * 2, len(rows))):
            pending.add(pool.submit(download, next(source)))
        while pending:
            finished, pending = concurrent.futures.wait(pending, return_when=concurrent.futures.FIRST_COMPLETED)
            for future in finished:
                result = future.result()
                if result[2] != "stopped":
                    db.execute("INSERT OR REPLACE INTO checks VALUES (?,?,?,?,?,?,?,?)", result)
                processed += 1
                if not STOP.is_set():
                    next_row = next(source, None)
                    if next_row is not None:
                        pending.add(pool.submit(download, next_row))
            if processed % 256 < len(finished):
                db.commit()
            if processed % 2048 < len(finished) or STOP.is_set():
                db.commit()
                counts = dict(db.execute("SELECT status,count(*) FROM checks GROUP BY status"))
                print(f"checked={processed}/{len(rows)} counts={counts} elapsed={time.time()-started:.1f}s", flush=True)
    db.commit()
    counts = dict(db.execute("SELECT status,count(*) FROM checks GROUP BY status"))
    print(f"FINAL checked={processed}/{len(rows)} counts={counts} elapsed={time.time()-started:.1f}s", flush=True)


if __name__ == "__main__":
    main()
