#!/usr/bin/env python3
"""Export the large pg_cron run-history table in bounded CSV segments.

Output is private and git-ignored. Segments are not one transactional snapshot.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import io
import pathlib
import subprocess
import sys
import urllib.parse

from inventory_cloudflare_migration import (
    DEFAULT_ENV, DEFAULT_OUTPUT, get_management_list, read_env, run_read_only, write_json,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", type=pathlib.Path, default=DEFAULT_ENV)
    parser.add_argument("--chunk-size", type=int, default=5000)
    parser.add_argument("--limit-chunks", type=int, default=0, help="Bounded diagnostic run; zero exports all")
    args = parser.parse_args()
    if not 1 <= args.chunk_size <= 10000 or args.limit_chunks < 0:
        parser.error("Chunk size must be 1..10000 and limit-chunks nonnegative")
    env = read_env(args.env_file)
    source_host = urllib.parse.urlsplit(env.get("NEXT_PUBLIC_SUPABASE_URL", "")).hostname or ""
    direct = urllib.parse.urlsplit(env.get("POSTGRES_URL", ""))
    token = env.get("SUPABASE_ACCESS_TOKEN", "")
    if not source_host.endswith(".supabase.co") or not direct.password or not token:
        raise SystemExit("Cron history export credentials are unavailable")
    ref = source_host.split(".")[0]
    password = urllib.parse.unquote(direct.password)
    host = str(get_management_list(ref, token, "config/database/pooler")[0]["db_host"])
    bounds = run_read_only(ref, token, """
      select count(*) as row_count, min(runid) as min_runid, max(runid) as max_runid
      from cron.job_run_details
    """)[0]
    minimum = int(bounds["min_runid"] or 0)
    maximum = int(bounds["max_runid"] or 0)
    destination = DEFAULT_OUTPUT / "database" / "cron-job-run-details"
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination.chmod(0o700)
    password_file = destination / ".pgpass"
    escaped_password = password.replace("\\", "\\\\").replace(":", "\\:")
    password_file.write_text(f"{host}:5432:postgres:postgres.{ref}:{escaped_password}\n", encoding="utf-8")
    password_file.chmod(0o600)
    mount = f"type=bind,source={destination.resolve()},target=/backup"
    columns = "jobid,runid,job_pid,database,username,command,status,return_message,start_time,end_time"
    segments: list[dict[str, object]] = []
    seen_runids: set[int] = set()
    try:
        for index, start in enumerate(range(minimum, maximum + 1, args.chunk_size)):
            if args.limit_chunks and index >= args.limit_chunks:
                break
            end = min(start + args.chunk_size - 1, maximum)
            query = (
                f"COPY (SELECT {columns} FROM cron.job_run_details "
                f"WHERE runid BETWEEN {start} AND {end} ORDER BY runid) "
                "TO STDOUT WITH (FORMAT csv, HEADER true)"
            )
            command = [
                "docker", "run", "--rm", "--mount", mount,
                "--env", "PGPASSFILE=/backup/.pgpass", "--env", "PGCONNECT_TIMEOUT=10",
                "postgres:17", "psql", "--no-password", "--no-psqlrc",
                "--set", "ON_ERROR_STOP=1", "--host", host, "--port", "5432",
                "--username", f"postgres.{ref}", "--dbname", "postgres", "--command", query,
            ]
            result = subprocess.run(command, capture_output=True, timeout=120, check=False)
            if result.returncode:
                detail = result.stderr.decode(errors="replace").replace(password, "[redacted]")[-500:]
                print(f"Cron segment {index} failed: {detail}", file=sys.stderr)
                return 2
            rows = list(csv.reader(io.StringIO(result.stdout.decode("utf-8"))))
            if not rows or rows[0] != columns.split(","):
                print(f"Cron segment {index} has an invalid CSV header", file=sys.stderr)
                return 2
            for row in rows[1:]:
                if len(row) != len(rows[0]):
                    print(f"Cron segment {index} has an invalid row", file=sys.stderr)
                    return 2
                runid = int(row[1])
                if runid < start or runid > end or runid in seen_runids:
                    print(f"Cron segment {index} has an out-of-range or repeated run ID", file=sys.stderr)
                    return 2
                seen_runids.add(runid)
            name = f"runid-{start:012d}-{end:012d}.csv"
            partial = destination / f"{name}.partial"
            partial.write_bytes(result.stdout)
            partial.chmod(0o600)
            partial.replace(destination / name)
            segments.append({
                "file": name, "first_runid": start, "last_runid": end,
                "rows": len(rows) - 1, "bytes": len(result.stdout),
                "sha256": hashlib.sha256(result.stdout).hexdigest(),
            })
    finally:
        password_file.unlink(missing_ok=True)
    complete = bool(not args.limit_chunks or len(segments) * args.chunk_size >= maximum - minimum + 1)
    exported_rows = len(seen_runids)
    write_json(destination / "manifest.json", {
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_count_at_start": int(bounds["row_count"]),
        "min_runid_at_start": minimum, "max_runid_at_start": maximum,
        "segments": segments, "exported_rows": exported_rows,
        "range_complete": complete,
        "count_matches_start": complete and exported_rows == int(bounds["row_count"]),
        "transactionally_consistent": False,
    })
    print(f"Cron history: {exported_rows} rows in {len(segments)} segments; complete={complete}")
    return 0 if complete and exported_rows == int(bounds["row_count"]) else 2


if __name__ == "__main__":
    sys.exit(main())
