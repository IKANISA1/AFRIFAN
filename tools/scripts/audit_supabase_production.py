#!/usr/bin/env python3
"""Read-only, privacy-safe Supabase production control audit.

The access token, database URI, and legacy anonymous key are read from stdin
and are never printed or written. The report contains schema/control metadata
only, never application rows or secret values.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import unquote, urlsplit


API = "https://api.supabase.com"


def request(token: str, method: str, path: str, body: object | None = None):
    payload = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        API + path,
        data=payload,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "supabase-cli/2.113.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8")[:500]
        return error.code, {"error": detail}


AUDIT_SQL = r"""
select jsonb_build_object(
  'server_version', current_setting('server_version'),
  'migration_count', (select count(*) from supabase_migrations.schema_migrations),
  'migrations', (
    select coalesce(jsonb_agg(jsonb_build_object('version', version, 'name', name)
      order by version), '[]'::jsonb)
    from supabase_migrations.schema_migrations
  ),
  'relations', (
    select jsonb_object_agg(schema_name, summary) from (
      select n.nspname schema_name, jsonb_build_object(
        'tables', count(*) filter (where c.relkind in ('r','p')),
        'views', count(*) filter (where c.relkind in ('v','m')),
        'rls_tables', count(*) filter (where c.relkind in ('r','p') and c.relrowsecurity),
        'no_rls_tables', count(*) filter (where c.relkind in ('r','p') and not c.relrowsecurity)
      ) summary
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname in ('public','football','africlub_game','storage')
        and c.relkind in ('r','p','v','m')
      group by n.nspname
    ) relation_summary
  ),
  'rls_no_policy', (
    select coalesce(jsonb_agg(format('%I.%I', n.nspname, c.relname)
      order by n.nspname, c.relname), '[]'::jsonb)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public','football','africlub_game')
      and c.relkind in ('r','p') and c.relrowsecurity
      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
  ),
  'no_rls_exposed', (
    select coalesce(jsonb_agg(format('%I.%I', n.nspname, c.relname)
      order by n.nspname, c.relname), '[]'::jsonb)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public','football')
      and c.relkind in ('r','p') and not c.relrowsecurity
  ),
  'policy_counts', (
    select jsonb_object_agg(schemaname, count) from (
      select schemaname, count(*) count from pg_policies
      where schemaname in ('public','football','africlub_game','storage')
      group by schemaname
    ) policy_summary
  ),
  'function_summary', (
    select jsonb_object_agg(schema_name, summary) from (
      select n.nspname schema_name, jsonb_build_object(
        'functions', count(*),
        'security_definer', count(*) filter (where p.prosecdef),
        'definer_without_path', count(*) filter (
          where p.prosecdef and (p.proconfig is null or not exists (
            select 1 from unnest(p.proconfig) config where config like 'search_path=%'
          ))
        ),
        'definer_anon_exec', count(*) filter (
          where p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE')
        ),
        'definer_auth_exec', count(*) filter (
          where p.prosecdef and has_function_privilege('authenticated', p.oid, 'EXECUTE')
        )
      ) summary
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public','football','africlub_game')
      group by n.nspname
    ) function_summary
  ),
  'publication', (
    select coalesce(jsonb_agg(format('%I.%I', n.nspname, c.relname)
      order by n.nspname, c.relname), '[]'::jsonb)
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
  ),
  'storage_buckets', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'public', public, 'file_size_limit', file_size_limit,
      'allowed_mime_types', allowed_mime_types
    ) order by id), '[]'::jsonb) from storage.buckets
  ),
  'storage_policies', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', tablename, 'policy', policyname, 'command', cmd,
      'roles', roles, 'using', qual, 'check', with_check
    ) order by tablename, policyname), '[]'::jsonb)
    from pg_policies where schemaname = 'storage'
  ),
  'storage_object_summary', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'bucket_id', bucket_id, 'objects', object_count, 'bytes', total_bytes
    ) order by bucket_id), '[]'::jsonb)
    from (
      select bucket_id, count(*) object_count,
        coalesce(sum((metadata ->> 'size')::bigint), 0) total_bytes
      from storage.objects group by bucket_id
    ) object_summary
  ),
  'edge_urls_in_functions', (
    select coalesce(jsonb_agg(distinct matches[1] order by matches[1]), '[]'::jsonb)
    from pg_proc p
    cross join lateral regexp_matches(
      pg_get_functiondef(p.oid), '/functions/v1/([A-Za-z0-9_-]+)', 'g'
    ) matches
    where p.prokind in ('f', 'p')
  ),
  'cron_jobs', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'jobid', jobid, 'jobname', jobname, 'schedule', schedule, 'active', active,
      'edge_function', substring(command from '/functions/v1/([A-Za-z0-9_-]+)'),
      'database_routine', substring(
        command from '(?i)(?:select|call)[[:space:]]+((?:[A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*)'
      ),
      'references_mobility', command ~* '(mobility|trip_requests|trips)',
      'references_biopay', command ~* 'biopay',
      'references_edge_rate_events', command ~* 'edge_function_rate_events'
    ) order by jobid), '[]'::jsonb) from cron.job
  ),
  'cron_job_health', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'jobname', jobname, 'status', status,
      'start_time', start_time, 'end_time', end_time
    ) order by jobname), '[]'::jsonb)
    from (
      select distinct on (j.jobname)
        j.jobname, d.status, d.start_time, d.end_time
      from cron.job j
      left join cron.job_run_details d on d.jobid = j.jobid
      order by j.jobname, d.start_time desc nulls last
    ) latest_cron_runs
  ),
  'extensions', (select jsonb_object_agg(extname, extversion) from pg_extension),
  'governed_vault_secret_names', (
    select coalesce(jsonb_agg(name order by name), '[]'::jsonb)
    from vault.secrets where name in ('africlub_cron_job_secret')
  ),
  'custom_hook', (
    select jsonb_build_object(
      'security_definer', prosecdef,
      'config', proconfig,
      'public_exec', has_function_privilege('public', oid, 'EXECUTE'),
      'anon_exec', has_function_privilege('anon', oid, 'EXECUTE'),
      'auth_exec', has_function_privilege('authenticated', oid, 'EXECUTE'),
      'service_exec', has_function_privilege('service_role', oid, 'EXECUTE'),
      'auth_admin_exec', has_function_privilege('supabase_auth_admin', oid, 'EXECUTE'),
      'reads_user_metadata', prosrc ~* '(event|claims)\\s*->>?\\s*''user_metadata'''
    ) from pg_proc
    where oid = to_regprocedure('public.custom_access_token_hook(jsonb)')
  )
) audit;
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--output")
    parser.add_argument("--psql-container", default="supabase_db_AFRICLUB")
    parser.add_argument("--pooler-region", default="eu-central-1")
    parser.add_argument("--pooler-index", default="1")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    token = sys.stdin.readline().strip()
    database_uri = sys.stdin.readline().strip()
    legacy_anon_key = sys.stdin.readline().strip()
    if not token or not database_uri or not legacy_anon_key:
        raise SystemExit(
            "Three stdin lines are required: access token, database URI, legacy anon key."
        )

    ref = args.project_ref
    report: dict[str, object] = {"project_ref": ref}

    report["project"] = {"id": ref}

    cli_env = os.environ.copy()
    cli_env["SUPABASE_ACCESS_TOKEN"] = token
    function_process = subprocess.run(
        [
            "npx", "--yes", "supabase@2.113.0", "functions", "list",
            "--project-ref", ref, "--output", "json",
        ],
        env=cli_env,
        text=True,
        capture_output=True,
        check=False,
    )
    if function_process.returncode != 0:
        raise SystemExit("Function inventory failed through the Supabase CLI.")
    functions = json.loads(function_process.stdout)
    report["edge_functions"] = [
        {
            key: item.get(key)
            for key in (
                "id", "name", "slug", "status", "version", "verify_jwt",
                "ezbr_sha256", "created_at", "updated_at",
            )
        }
        for item in functions
    ]

    secrets_process = subprocess.run(
        [
            "npx", "--yes", "supabase@2.113.0", "secrets", "list",
            "--project-ref", ref, "--output", "json",
        ],
        env=cli_env,
        text=True,
        capture_output=True,
        check=False,
    )
    if secrets_process.returncode != 0:
        raise SystemExit("Secret-name inventory failed through the Supabase CLI.")
    secrets = json.loads(secrets_process.stdout)
    report["edge_secret_names"] = sorted(
        item.get("name") for item in secrets if isinstance(item.get("name"), str)
    )

    auth_request = urllib.request.Request(
        f"https://{ref}.supabase.co/auth/v1/settings",
        headers={"apikey": legacy_anon_key},
    )
    try:
        with urllib.request.urlopen(auth_request, timeout=30) as auth_response:
            auth = json.loads(auth_response.read().decode("utf-8"))
        safe_auth_fields = (
            "disable_signup", "external", "mailer_autoconfirm",
            "phone_autoconfirm", "sms_provider", "anonymous_users_enabled",
        )
        report["auth_public_settings"] = {
            key: auth.get(key) for key in safe_auth_fields if key in auth
        }
    except urllib.error.HTTPError as error:
        report["auth_public_settings"] = {"http_status": error.code}

    auth_status, auth_config = request(
        token, "GET", f"/v1/projects/{ref}/config/auth"
    )
    if auth_status == 200 and isinstance(auth_config, dict):
        report["auth_hook_configuration"] = {
            "send_sms_enabled": auth_config.get("hook_send_sms_enabled"),
            "send_sms_uri": auth_config.get("hook_send_sms_uri"),
            "send_sms_secret_configured": bool(
                auth_config.get("hook_send_sms_secrets")
            ),
            "custom_access_token_enabled": auth_config.get(
                "hook_custom_access_token_enabled"
            ),
            "custom_access_token_uri": auth_config.get(
                "hook_custom_access_token_uri"
            ),
            "leaked_password_protection_enabled": auth_config.get(
                "password_hibp_enabled"
            ),
        }
    else:
        report["auth_hook_configuration"] = {"http_status": auth_status}

    report["advisor_summary"] = {}
    for advisor_type in ("security", "performance"):
        advisor_status, advisor_result = request(
            token, "GET", f"/v1/projects/{ref}/advisors/{advisor_type}"
        )
        lints = (
            advisor_result.get("lints", [])
            if advisor_status == 200 and isinstance(advisor_result, dict)
            else []
        )
        by_name = collections.Counter(
            item.get("name", "unknown") for item in lints
            if isinstance(item, dict)
        )
        by_level = collections.Counter(
            item.get("level", "unknown") for item in lints
            if isinstance(item, dict)
        )
        report["advisor_summary"][advisor_type] = {
            "http_status": advisor_status,
            "total": len(lints),
            "by_level": dict(sorted(by_level.items())),
            "by_name": dict(sorted(by_name.items())),
        }

    parsed = urlsplit(database_uri)
    if parsed.scheme not in ("postgres", "postgresql") or not parsed.hostname:
        raise SystemExit("Database URI has an unsupported format.")
    database_env = os.environ.copy()
    database_env["PGPASSWORD"] = unquote(parsed.password or "")
    database_env["PGSSLMODE"] = "require"
    database_host = parsed.hostname
    database_port = parsed.port or 5432
    database_user = unquote(parsed.username or "postgres")
    if parsed.hostname == f"db.{ref}.supabase.co":
        # Direct database DNS can be IPv6-only. Supavisor provides the supported
        # IPv4 transaction-pooler route while preserving the same password.
        database_host = (
            f"aws-{args.pooler_index}-{args.pooler_region}.pooler.supabase.com"
        )
        database_port = 6543
        database_user = f"postgres.{ref}"
    psql_process = subprocess.run(
        [
            "docker", "exec", "-e", "PGPASSWORD", "-i", args.psql_container,
            "psql", "-h", database_host, "-p", str(database_port),
            "-U", database_user,
            "-d", unquote((parsed.path or "/postgres").lstrip("/")),
            "-v", "ON_ERROR_STOP=1", "-tA", "-c", AUDIT_SQL,
        ],
        env=database_env,
        text=True,
        capture_output=True,
        check=False,
        timeout=120,
    )
    if psql_process.returncode != 0:
        detail = psql_process.stderr.replace(unquote(parsed.password or ""), "<redacted>")
        raise SystemExit(
            "Read-only production database audit failed: " + detail.strip()[:500]
        )
    database_audit = json.loads(psql_process.stdout.strip())
    if not isinstance(database_audit, dict):
        raise SystemExit("Database audit returned an unexpected response.")
    report["database"] = database_audit

    local_function_names = sorted(
        item.name for item in pathlib.Path("supabase/functions").iterdir()
        if item.is_dir() and item.name != "_shared"
    )
    deployed_function_names = sorted(
        item["slug"] for item in report["edge_functions"] if item.get("slug")
    )
    report["parity"] = {
        "governed_local_functions": local_function_names,
        "governed_missing_in_production": sorted(
            set(local_function_names) - set(deployed_function_names)
        ),
        "deployed_without_governed_source": sorted(
            set(deployed_function_names) - set(local_function_names)
        ),
    }

    expected_cron_jobs = {
        "redact-momo-sms-artifacts-daily",
        "check-momo-sms-migration-safety-daily",
        "purge_edge_function_rate_events",
        "settle-prediction-notifications",
        "daily-fixture-sync",
    }
    expected_rls_no_policy = {
        "africlub_game.display_bootstrap_challenges",
        "public.admin_phone_access",
        "public.request_rate_limits",
    }
    strict_failures: list[str] = []
    if report["parity"]["governed_missing_in_production"]:
        strict_failures.append("governed Edge functions are missing")
    if report["parity"]["deployed_without_governed_source"]:
        strict_failures.append("ungoverned Edge functions remain deployed")
    if any(
        item.get("status") != "ACTIVE" or item.get("verify_jwt") is not False
        for item in report["edge_functions"]
    ):
        strict_failures.append("Edge function status or gateway auth drift")
    hooks = report.get("auth_hook_configuration", {})
    if not (
        hooks.get("send_sms_enabled")
        and hooks.get("send_sms_secret_configured")
        and hooks.get("custom_access_token_enabled")
    ):
        strict_failures.append("Auth hook configuration is incomplete")
    database = report["database"]
    if database.get("no_rls_exposed"):
        strict_failures.append("an exposed table is missing RLS")
    if set(database.get("rls_no_policy", [])) != expected_rls_no_policy:
        strict_failures.append("deny-by-default RLS inventory drift")
    if any(
        summary.get("definer_without_path")
        for summary in database.get("function_summary", {}).values()
    ):
        strict_failures.append("a SECURITY DEFINER function lacks search_path")
    if {
        item.get("jobname") for item in database.get("cron_jobs", [])
    } != expected_cron_jobs:
        strict_failures.append("governed cron inventory drift")
    if "africlub_cron_job_secret" not in database.get(
        "governed_vault_secret_names", []
    ):
        strict_failures.append("cron Vault secret is missing")
    if {"OTP_TEST_CODE", "OTP_TEST_PHONE"} & set(report["edge_secret_names"]):
        strict_failures.append("obsolete OTP test secrets remain")
    report["strict_control_failures"] = strict_failures

    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        pathlib.Path(args.output).write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)
    return 1 if args.strict and strict_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
