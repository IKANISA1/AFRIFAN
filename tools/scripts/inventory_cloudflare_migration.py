#!/usr/bin/env python3
"""Read-only Supabase exit inventory. Writes metadata only to ignored output/.

The management token is read from an ignored env file. Query responses never
include member records, phone numbers, payment references or secret values.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import urlsplit


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_ENV = ROOT / "apps/rayon_sports/web/.env.local"
DEFAULT_OUTPUT = ROOT / "output/migration/cloudflare-stage0"
SOURCE_EXTENSIONS = {".dart", ".ts", ".tsx", ".js", ".jsx", ".mjs"}
CALL_PATTERNS = {
    "table_or_view": re.compile(r"\.from\(\s*['\"]([^'\"]+)['\"]"),
    "rpc": re.compile(r"\.rpc\(\s*['\"]([^'\"]+)['\"]"),
    "edge_function": re.compile(r"\.functions\.invoke(?:<[^>]+>)?\(\s*['\"]([^'\"]+)['\"]"),
    "storage_bucket": re.compile(r"\.storage\.from\(\s*['\"]([^'\"]+)['\"]"),
    "realtime_channel": re.compile(r"\.channel\(\s*['\"]([^'\"]+)['\"]"),
    "auth_operation": re.compile(r"\.auth\.([A-Za-z][A-Za-z0-9_]*)\s*\("),
}

SQL = {
    "database": """
      select current_setting('server_version') as server_version,
        pg_database_size(current_database()) as database_bytes,
        (select count(*) from auth.users) as auth_users,
        (select count(*) from storage.objects) as storage_objects,
        (select count(*) from supabase_migrations.schema_migrations) as applied_migrations
    """,
    "relations": """
      select n.nspname as schema, c.relname as name, c.relkind as kind,
        c.reltuples::bigint as estimated_rows,
        pg_total_relation_size(c.oid) as total_bytes,
        c.relrowsecurity as row_security,
        c.relforcerowsecurity as force_row_security
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','football','africlub_game','auth','storage')
        and c.relkind in ('r','p','v','m')
      order by n.nspname,c.relname
    """,
    "functions": """
      select n.nspname as schema, p.proname as name,
        pg_get_function_identity_arguments(p.oid) as arguments,
        p.prosecdef as security_definer, p.provolatile as volatility,
        p.prokind as kind
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in ('public','football','africlub_game')
      order by n.nspname,p.proname,arguments
    """,
    "policies": """
      select schemaname as schema, tablename as table_name,
        policyname as name, roles, cmd as command, permissive
      from pg_policies
      where schemaname in ('public','football','africlub_game','auth','storage')
      order by schemaname,tablename,policyname
    """,
    "triggers": """
      select n.nspname as schema, c.relname as table_name,
        t.tgname as name, p.proname as function_name,
        t.tgenabled as enabled
      from pg_trigger t join pg_class c on c.oid=t.tgrelid
        join pg_namespace n on n.oid=c.relnamespace
        join pg_proc p on p.oid=t.tgfoid
      where not t.tgisinternal and n.nspname in ('public','football','africlub_game','auth','storage')
      order by n.nspname,c.relname,t.tgname
    """,
    "indexes": """
      select schemaname as schema, tablename as table_name,
        indexname as name
      from pg_indexes
      where schemaname in ('public','football','africlub_game','auth','storage')
      order by schemaname,tablename,indexname
    """,
    "storage_buckets": """
      select b.id as bucket_id, b.public, b.file_size_limit,
        b.allowed_mime_types, count(o.id) as object_count,
        coalesce(sum(case when o.metadata->>'size' ~ '^[0-9]+$'
          then (o.metadata->>'size')::bigint else 0 end),0) as metadata_bytes
      from storage.buckets b left join storage.objects o on o.bucket_id=b.id
      group by b.id,b.public,b.file_size_limit,b.allowed_mime_types
      order by b.id
    """,
    "cron_jobs": """
      select jobname as name, schedule, active,
        md5(command) as command_md5
      from cron.job order by jobname
    """,
    "extensions": """
      select extname as name, extversion as version
      from pg_extension order by extname
    """,
    "club_rows": """
      select id, club_slug as slug, club_name as name,
        is_onboarded, is_active from public.african_football_clubs
      order by id
    """,
}


def read_env(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def local_inventory() -> dict[str, object]:
    files = subprocess.run(
        ["rg", "--files", "apps", "packages"], cwd=ROOT,
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    calls: list[dict[str, object]] = []
    for name in files:
        path = ROOT / name
        if path.suffix not in SOURCE_EXTENSIONS or "/test/" in f"/{name}" or "/e2e/" in f"/{name}":
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for kind, pattern in CALL_PATTERNS.items():
            for match in pattern.finditer(source):
                line_number = source.count("\n", 0, match.start()) + 1
                calls.append({"kind": kind, "name": match.group(1), "path": name, "line": line_number})
    return {
        "migrations": [p.name for p in sorted((ROOT / "supabase/migrations").glob("*.sql"))],
        "sql_contracts": [p.name for p in sorted((ROOT / "supabase/tests").glob("*.sql"))],
        "edge_functions": [p.parent.name for p in sorted((ROOT / "supabase/functions").glob("*/index.ts"))],
        "literal_calls": calls,
    }


def run_read_only(ref: str, token: str, query: str) -> list[dict[str, object]]:
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        data=json.dumps({"query": query, "read_only": True}).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            rows = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"Read-only management query returned HTTP {error.code}") from None
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise RuntimeError("Unexpected management query response shape")
    return rows


def get_management_list(ref: str, token: str, resource: str) -> list[dict[str, object]]:
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{ref}/{resource}",
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            rows = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"Management {resource} list returned HTTP {error.code}") from None
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise RuntimeError(f"Unexpected management {resource} response shape")
    return rows


def exact_table_counts(ref: str, token: str, relations: list[dict[str, object]]) -> list[dict[str, object]]:
    tables = [r for r in relations if r.get("kind") in ("r", "p")]
    counts: list[dict[str, object]] = []
    for start in range(0, len(tables), 20):
        batch = tables[start:start + 20]
        clauses = []
        for relation in batch:
            schema, name = str(relation["schema"]), str(relation["name"])
            identifier = '"' + schema.replace('"', '""') + '"."' + name.replace('"', '""') + '"'
            label = (schema + "." + name).replace("'", "''")
            clauses.append(f"select '{label}' as relation, count(*) as row_count from {identifier}")
        counts.extend(run_read_only(ref, token, " union all ".join(clauses)))
    return counts


def write_json(path: pathlib.Path, value: object) -> None:
    data = (json.dumps(value, indent=2, sort_keys=True, default=str) + "\n").encode("utf-8")
    path.write_bytes(data)
    path.chmod(0o600)
    path.with_suffix(path.suffix + ".sha256").write_text(
        f"{hashlib.sha256(data).hexdigest()}  {path.name}\n", encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", type=pathlib.Path, default=DEFAULT_ENV)
    parser.add_argument("--output-dir", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--offline", action="store_true", help="Only inventory local source")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if output != DEFAULT_OUTPUT.resolve() and ROOT / "output" not in output.parents:
        parser.error("Output must be inside ignored output/ to protect operational metadata")
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    local = local_inventory()
    write_json(output / "local-inventory.json", local)
    if args.offline:
        print(f"Local inventory: {len(local['literal_calls'])} literal callers; remote not queried")
        return 0
    env = read_env(args.env_file)
    token = env.get("SUPABASE_ACCESS_TOKEN", "")
    source = env.get("NEXT_PUBLIC_SUPABASE_URL", "")
    host = urlsplit(source).hostname or ""
    if not token or not host.endswith(".supabase.co"):
        raise SystemExit("Read-only inventory credentials are unavailable")
    ref = host.split(".")[0]
    remote: dict[str, object] = {
        "project_ref": ref,
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "query_mode": "read_only",
        "queries": {},
    }
    failures: dict[str, str] = {}
    for name, sql in SQL.items():
        try:
            remote["queries"][name] = run_read_only(ref, token, sql)
        except RuntimeError as error:
            failures[name] = str(error)
    relations = remote["queries"].get("relations")
    if isinstance(relations, list):
        try:
            remote["queries"]["exact_table_counts"] = exact_table_counts(ref, token, relations)
        except RuntimeError as error:
            failures["exact_table_counts"] = str(error)
    try:
        deployed = get_management_list(ref, token, "functions")
        remote["queries"]["deployed_edge_functions"] = [
            {key: item.get(key) for key in ("slug", "name", "status", "version", "verify_jwt")}
            for item in deployed
        ]
    except RuntimeError as error:
        failures["deployed_edge_functions"] = str(error)
    try:
        secrets = get_management_list(ref, token, "secrets")
        remote["queries"]["edge_secret_names"] = [
            str(item["name"]) for item in secrets if isinstance(item.get("name"), str)
        ]
    except RuntimeError as error:
        failures["edge_secret_names"] = str(error)
    remote["failures"] = failures
    write_json(output / "remote-inventory.json", remote)
    counts = {name: len(rows) for name, rows in remote["queries"].items()}
    print("Live metadata sections:", json.dumps(counts, sort_keys=True))
    print("Missing sections:", json.dumps(failures, sort_keys=True))
    database = remote["queries"].get("database", [])
    if database:
        print("Database summary:", json.dumps(database[0], sort_keys=True))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
