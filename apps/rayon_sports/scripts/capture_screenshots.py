#!/usr/bin/env python3
"""Capture or validate Rayon Sports Android store screenshots.

The release checklist requires Play Store screenshots to match the current
mobile app. This script keeps the workflow auditable by writing a JSON manifest
for every capture or validation run.

Examples:
  python3 scripts/capture_screenshots.py --validate-existing
  python3 scripts/capture_screenshots.py --mode interactive
  python3 scripts/capture_screenshots.py --mode rapid --copy-fastlane
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


APP_DIR = Path(__file__).resolve().parents[1]
DEFAULT_APP_ID = "rw.gikundiro.app"
DEFAULT_CAPTURE_DIR = APP_DIR / "store_metadata" / "play_store" / "screenshots"
DEFAULT_FASTLANE_DIR = (
    APP_DIR
    / "android"
    / "fastlane"
    / "metadata"
    / "android"
    / "en-US"
    / "images"
    / "phoneScreenshots"
)
DEFAULT_MANIFEST = APP_DIR / "store_metadata" / "play_store" / "screenshots_manifest.json"


@dataclass(frozen=True)
class ScreenPrompt:
    filename: str
    title: str
    instructions: str


SCREENS = (
    ScreenPrompt(
        "01_home_dashboard",
        "Home Dashboard",
        "Open the Home tab with current club content visible.",
    ),
    ScreenPrompt(
        "02_fanzone",
        "Fan Zone",
        "Open the Fan Zone tab with current prediction and wallet modules visible.",
    ),
    ScreenPrompt(
        "03_membership",
        "Membership",
        "Open Membership or the fan profile card surface.",
    ),
    ScreenPrompt(
        "04_ticketing",
        "Ticketing",
        "Open Ticketing with real available or unavailable ticket state.",
    ),
    ScreenPrompt(
        "05_shop",
        "Shop",
        "Open Shop with current merchandise or the deliberate empty state.",
    ),
    ScreenPrompt(
        "06_contributions",
        "Contributions",
        "Open Contributions with current projects, groups, or deliberate empty state.",
    ),
    ScreenPrompt(
        "07_settings",
        "Settings",
        "Open Settings with account, privacy, and notification controls visible.",
    ),
)


def run_command(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, check=check, text=True)


def adb_args(device: str | None, args: Iterable[str]) -> list[str]:
    command = ["adb"]
    if device:
        command.extend(["-s", device])
    command.extend(args)
    return command


def find_device(explicit_device: str | None) -> tuple[str, dict[str, str]]:
    if explicit_device:
        device = explicit_device
    else:
        result = run_command(["adb", "devices"])
        lines = result.stdout.strip().splitlines()[1:]
        devices = [line.split("\t", 1)[0] for line in lines if "\tdevice" in line]
        if not devices:
            raise RuntimeError("No connected Android device found via `adb devices`.")
        device = devices[0]

    model = run_command(adb_args(device, ["shell", "getprop", "ro.product.model"]))
    android_version = run_command(adb_args(device, ["shell", "getprop", "ro.build.version.release"]))
    size = run_command(adb_args(device, ["shell", "wm", "size"]))
    density = run_command(adb_args(device, ["shell", "wm", "density"]))
    return device, {
        "serial": device,
        "model": model.stdout.strip(),
        "android_version": android_version.stdout.strip(),
        "screen_size": size.stdout.strip(),
        "density": density.stdout.strip(),
    }


def app_is_running(device: str, app_id: str) -> bool:
    result = run_command(adb_args(device, ["shell", "pidof", app_id]), check=False)
    return result.returncode == 0 and bool(result.stdout.strip())


def launch_app(device: str, app_id: str) -> None:
    run_command(
        adb_args(
            device,
            [
                "shell",
                "monkey",
                "-p",
                app_id,
                "-c",
                "android.intent.category.LAUNCHER",
                "1",
            ],
        )
    )


def capture_screenshot(device: str, filename: str, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    remote_path = f"/sdcard/{filename}.png"
    local_path = output_dir / f"{filename}.png"

    run_command(adb_args(device, ["shell", "screencap", "-p", remote_path]))
    run_command(adb_args(device, ["pull", remote_path, str(local_path)]))
    run_command(adb_args(device, ["shell", "rm", remote_path]), check=False)
    return local_path


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as file:
        header = file.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG file.")
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def validate_png(path: Path, min_width: int, min_height: int, min_bytes: int) -> dict[str, object]:
    width, height = png_dimensions(path)
    size_bytes = path.stat().st_size
    issues: list[str] = []
    if width < min_width:
        issues.append(f"width {width} is below minimum {min_width}")
    if height < min_height:
        issues.append(f"height {height} is below minimum {min_height}")
    if size_bytes < min_bytes:
        issues.append(f"file size {size_bytes} is below minimum {min_bytes}")
    return {
        "path": repository_path(path),
        "width": width,
        "height": height,
        "size_bytes": size_bytes,
        "valid": not issues,
        "issues": issues,
    }


def repository_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(APP_DIR))
    except ValueError:
        return str(resolved)


def collect_existing_screenshots(directory: Path) -> list[Path]:
    if not directory.exists():
        return []
    return sorted(path for path in directory.iterdir() if path.suffix.lower() == ".png")


def copy_to_fastlane(screenshots: list[Path], fastlane_dir: Path) -> list[Path]:
    fastlane_dir.mkdir(parents=True, exist_ok=True)
    copied: list[Path] = []
    for index, source in enumerate(screenshots, start=1):
        destination = fastlane_dir / f"{index}_{source.stem}.png"
        shutil.copy2(source, destination)
        copied.append(destination)
    return copied


def write_manifest(manifest_path: Path, payload: dict[str, object]) -> None:
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def run_interactive_capture(device: str, output_dir: Path) -> list[Path]:
    captured: list[Path] = []
    print(f"Capturing {len(SCREENS)} guided screenshots.")
    for index, screen in enumerate(SCREENS, start=1):
        print()
        print(f"{index}/{len(SCREENS)} {screen.title}")
        print(screen.instructions)
        response = input("Position the app, then press Enter. Type 's' to skip: ").strip().lower()
        if response == "s":
            continue
        time.sleep(0.5)
        path = capture_screenshot(device, screen.filename, output_dir)
        captured.append(path)
        print(f"Saved {path}")
    return captured


def run_rapid_capture(device: str, output_dir: Path) -> list[Path]:
    captured: list[Path] = []
    index = 1
    print("Rapid capture mode. Press Enter for each screenshot, or type 'done'.")
    while True:
        response = input(f"Screenshot {index}: ").strip().lower()
        if response == "done":
            break
        path = capture_screenshot(device, f"screenshot_{index:02d}", output_dir)
        captured.append(path)
        print(f"Saved {path}")
        index += 1
    return captured


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture or validate Rayon Sports Android store screenshots.",
    )
    parser.add_argument(
        "--mode",
        choices=("interactive", "rapid"),
        default="interactive",
        help="Capture mode when not using --validate-existing.",
    )
    parser.add_argument("--device", help="ADB device serial. Defaults to first connected device.")
    parser.add_argument("--app-id", default=DEFAULT_APP_ID, help="Android application id.")
    parser.add_argument("--capture-dir", type=Path, default=DEFAULT_CAPTURE_DIR)
    parser.add_argument("--fastlane-dir", type=Path, default=DEFAULT_FASTLANE_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--copy-fastlane", action="store_true", help="Copy new captures to Fastlane metadata.")
    parser.add_argument(
        "--capture-current",
        metavar="FILENAME",
        help="Capture the current foreground screen without interactive prompts.",
    )
    parser.add_argument("--launch", action="store_true", help="Launch the app before capturing.")
    parser.add_argument(
        "--validate-existing",
        action="store_true",
        help="Validate existing Fastlane screenshots without requiring ADB.",
    )
    parser.add_argument("--min-count", type=int, default=2)
    parser.add_argument("--min-width", type=int, default=320)
    parser.add_argument("--min-height", type=int, default=320)
    parser.add_argument("--min-bytes", type=int, default=10_000)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    started_at = datetime.now(timezone.utc).isoformat()
    device_metadata: dict[str, str] | None = None

    if args.validate_existing:
        screenshots = collect_existing_screenshots(args.fastlane_dir)
        mode = "validate_existing"
    else:
        try:
            device, device_metadata = find_device(args.device)
        except (RuntimeError, subprocess.CalledProcessError) as error:
            print(f"Device discovery failed: {error}", file=sys.stderr)
            return 2

        if args.launch:
            launch_app(device, args.app_id)
            time.sleep(3)

        if not app_is_running(device, args.app_id):
            print(
                f"App {args.app_id} is not running. Start it before capture.",
                file=sys.stderr,
            )
            return 2

        if args.capture_current:
            screenshots = [capture_screenshot(device, args.capture_current, args.capture_dir)]
            mode = "capture_current"
        else:
            screenshots = (
                run_rapid_capture(device, args.capture_dir)
                if args.mode == "rapid"
                else run_interactive_capture(device, args.capture_dir)
            )
            mode = args.mode
        if args.copy_fastlane and screenshots:
            screenshots = copy_to_fastlane(screenshots, args.fastlane_dir)

    validations = [
        validate_png(path, args.min_width, args.min_height, args.min_bytes)
        for path in screenshots
    ]
    valid_count = sum(1 for item in validations if item["valid"])
    success = valid_count >= args.min_count and valid_count == len(validations)

    manifest = {
        "app_id": args.app_id,
        "device": device_metadata,
        "fastlane_dir": repository_path(args.fastlane_dir),
        "generated_at": started_at,
        "mode": mode,
        "min_count": args.min_count,
        "screenshot_count": len(screenshots),
        "screenshots": validations,
        "success": success,
    }
    write_manifest(args.manifest, manifest)

    print(json.dumps(manifest, indent=2, sort_keys=True))
    if not success:
        print(
            f"Screenshot evidence failed: {valid_count} valid screenshot(s), "
            f"minimum required is {args.min_count}.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
