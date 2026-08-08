#!/usr/bin/env python3
"""Raise Flutter's generated iOS SwiftPM package to the project minimum."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


IOS_PLATFORM_PATTERN = re.compile(r'(\.iOS\(")([0-9]+(?:\.[0-9]+){1,2})("\))')


def version_tuple(value: str) -> tuple[int, ...]:
    parts = tuple(int(part) for part in value.split("."))
    if len(parts) not in (2, 3):
        raise ValueError(f"invalid iOS version: {value}")
    return parts


def synchronize_manifest(
    manifest_path: pathlib.Path,
    minimum: str,
    *,
    check_only: bool = False,
) -> tuple[str, bool]:
    required = version_tuple(minimum)
    try:
        source = manifest_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ValueError(f"generated SwiftPM manifest is missing: {manifest_path}") from exc

    matches = list(IOS_PLATFORM_PATTERN.finditer(source))
    if len(matches) != 1:
        raise ValueError(
            "generated SwiftPM manifest must contain exactly one explicit iOS platform; "
            f"found {len(matches)} in {manifest_path}"
        )

    current = matches[0].group(2)
    if version_tuple(current) >= required:
        return current, False
    if check_only:
        raise ValueError(
            f"generated SwiftPM deployment target {current} is below required {minimum}"
        )

    updated = IOS_PLATFORM_PATTERN.sub(
        lambda match: f"{match.group(1)}{minimum}{match.group(3)}",
        source,
        count=1,
    )
    manifest_path.write_text(updated, encoding="utf-8")
    return minimum, True


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--minimum", required=True)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        version, changed = synchronize_manifest(
            args.manifest,
            args.minimum,
            check_only=args.check,
        )
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    action = "raised" if changed else "verified"
    print(f"Generated iOS SwiftPM deployment target {action} at {version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
