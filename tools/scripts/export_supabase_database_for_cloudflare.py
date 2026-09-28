#!/usr/bin/env python3
"""Export a private PostgreSQL archive through Supabase's session pooler.

This is a staged preservation artifact. Excluded table data must be exported
separately and a complete restore must pass before it can be a cutover backup.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import subprocess
import sys
import urllib.parse

from inventory_cloudflare_migration import (
    DEFAULT_ENV, DEFAULT_OUTPUT, get_management_list, read_env, write_json,
)


IMAGE = "postgres:17"
EXCLUDED_DATA = ("cron.job_run_details",)


def docker(
    args: list[str], directory: pathlib.Path, *, timeout: int,
    environment: tuple[str, ...] = (),
) -> subprocess.CompletedProcess[str]:
    mount = f"type=bind,source={directory.resolve()},target=/backup"
    return subprocess.run(
        ["docker", "run", "--rm", "--mount", mount,
         *(option for entry in environment for option in ("--env", entry)), IMAGE, *args],
        capture_output=True, text=True, timeout=timeout, check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", type=pathlib.Path, default=DEFAULT_ENV)
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    env = read_env(args.env_file)
    source_host = urllib.parse.urlsplit(env.get("NEXT_PUBLIC_SUPABASE_URL", "")).hostname or ""
    direct = urllib.parse.urlsplit(env.get("POSTGRES_URL", ""))
    token = env.get("SUPABASE_ACCESS_TOKEN", "")
    if not source_host.endswith(".supabase.co") or not token or not direct.password:
        raise SystemExit("Database export credentials are unavailable")
    ref = source_host.split(".")[0]
    password = urllib.parse.unquote(direct.password)
    poolers = get_management_list(ref, token, "config/database/pooler")
    if not poolers or not poolers[0].get("db_host"):
        raise SystemExit("Session pooler host is unavailable")
    host = str(poolers[0]["db_host"])
    directory = DEFAULT_OUTPUT / "database"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    filename = f"africlub-excluding-cron-history-{today}.dump"
    partial = directory / f"{filename}.partial"
    final = directory / filename
    password_file = directory / ".pgpass"
    escaped_password = password.replace("\\", "\\\\").replace(":", "\\:")
    password_file.write_text(f"{host}:5432:postgres:postgres.{ref}:{escaped_password}\n", encoding="utf-8")
    password_file.chmod(0o600)
    command = [
        "pg_dump", "--no-password", "--host", host, "--port", "5432",
        "--username", f"postgres.{ref}", "--dbname", "postgres",
        "--format", "custom", "--lock-wait-timeout", "10s",
        *(f"--exclude-table-data={name}" for name in EXCLUDED_DATA),
        "--file", f"/backup/{partial.name}",
    ]
    try:
        result = docker(command, directory, timeout=args.timeout,
                        environment=("PGPASSFILE=/backup/.pgpass", "PGCONNECT_TIMEOUT=10"))
    except subprocess.TimeoutExpired:
        partial.unlink(missing_ok=True)
        print("Database archive timed out and its partial file was removed", file=sys.stderr)
        return 2
    finally:
        password_file.unlink(missing_ok=True)
    if result.returncode:
        partial.unlink(missing_ok=True)
        detail = result.stderr.replace(password, "[redacted]")[-800:]
        print(f"Database archive failed with exit {result.returncode}: {detail}", file=sys.stderr)
        return 2
    listing = docker(["pg_restore", "--list", f"/backup/{partial.name}"], directory, timeout=60)
    extract = docker(["pg_restore", "--file=/dev/null", f"/backup/{partial.name}"], directory, timeout=60)
    if listing.returncode or extract.returncode:
        partial.unlink(missing_ok=True)
        print("Database archive validation failed", file=sys.stderr)
        return 2
    toc = [line for line in listing.stdout.splitlines() if line and not line.startswith(";")]
    if any("TABLE DATA cron job_run_details " in line for line in toc):
        partial.unlink(missing_ok=True)
        print("Excluded cron history unexpectedly appears in archive data", file=sys.stderr)
        return 2
    if not any("TABLE DATA public " in line for line in toc) or not any("TABLE DATA auth users " in line for line in toc):
        partial.unlink(missing_ok=True)
        print("Expected application or auth data is missing from archive", file=sys.stderr)
        return 2
    partial.chmod(0o600)
    partial.replace(final)
    digest = hashlib.sha256(final.read_bytes()).hexdigest()
    write_json(directory / f"{filename}.manifest.json", {
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "file": filename, "bytes": final.stat().st_size, "sha256": digest,
        "archive_entries": len(toc), "excluded_table_data": EXCLUDED_DATA,
        "archive_readable": True, "restore_tested": False,
    })
    print(f"Archive verified: {final.stat().st_size} bytes, {len(toc)} entries; excluded {', '.join(EXCLUDED_DATA)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
