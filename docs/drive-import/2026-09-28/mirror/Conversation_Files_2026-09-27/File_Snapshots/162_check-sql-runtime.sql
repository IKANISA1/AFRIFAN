-- Read-only capability probe. Does not apply schema, import rows or enable a writer.
-- Expected: nonnull milliseconds, leap_day='2025-02-28', shape_ok=1.
SELECT sqlite_version() AS sqlite_version,
       CAST(unixepoch('subsec') * 1000 AS INTEGER) AS current_time_ms,
       date('2024-02-29','+1 year','floor') AS leap_day,
       json_valid(json_object('schemaVersion',1,'enabled',json('false'))) AS shape_ok;
