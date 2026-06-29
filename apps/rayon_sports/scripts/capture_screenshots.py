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
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree


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
ACCESSIBILITY_SHORTCUT_SETTINGS = (
    "accessibility_button_targets",
    "accessibility_button_mode",
)


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


def read_secure_setting(device: str, key: str) -> str | None:
    result = run_command(adb_args(device, ["shell", "settings", "get", "secure", key]))
    value = result.stdout.strip()
    return None if value == "null" else value


def write_secure_setting(device: str, key: str, value: str | None) -> None:
    if value is None:
        run_command(adb_args(device, ["shell", "settings", "delete", "secure", key]), check=False)
    else:
        run_command(adb_args(device, ["shell", "settings", "put", "secure", key, value]))


def snapshot_accessibility_shortcut_settings(device: str) -> dict[str, str | None]:
    return {
        key: read_secure_setting(device, key)
        for key in ACCESSIBILITY_SHORTCUT_SETTINGS
    }


def hide_accessibility_shortcut(device: str) -> dict[str, str | None]:
    previous = snapshot_accessibility_shortcut_settings(device)
    write_secure_setting(device, "accessibility_button_targets", None)
    return previous


def restore_accessibility_shortcut(
    device: str,
    previous: dict[str, str | None],
) -> None:
    for key, value in previous.items():
        write_secure_setting(device, key, value)


def dump_ui(device: str) -> ElementTree.Element:
    remote_path = "/sdcard/window_dump.xml"
    run_command(adb_args(device, ["shell", "uiautomator", "dump", remote_path]))
    result = run_command(adb_args(device, ["exec-out", "cat", remote_path]))
    run_command(adb_args(device, ["shell", "rm", remote_path]), check=False)
    xml = result.stdout.strip()
    if not xml.startswith("<"):
        raise ValueError(f"Android UI dump did not return XML: {xml[:80]}")
    return ElementTree.fromstring(xml)


def ui_contains_package(root: ElementTree.Element, app_id: str) -> bool:
    return any(node.attrib.get("package") == app_id for node in root.iter("node"))


def _bounds_center(bounds: str) -> tuple[int, int]:
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if not match:
        raise ValueError(f"Unexpected Android bounds value: {bounds}")
    left, top, right, bottom = (int(value) for value in match.groups())
    x = (left + right) // 2
    y = (top + bottom) // 2
    if y > 2000:
        y = top + max(12, min(28, (bottom - top) // 3))
    return x, y


def find_node_by_label(
    root: ElementTree.Element,
    label: str,
    *,
    app_id: str | None = None,
) -> ElementTree.Element | None:
    def matches(value: str | None) -> bool:
        if not value:
            return False
        normalized = value.strip()
        if normalized == label:
            return True
        return label in [line.strip() for line in normalized.splitlines()]

    for node in root.iter("node"):
        if app_id is not None and node.attrib.get("package") != app_id:
            continue
        if matches(node.attrib.get("text")) or matches(node.attrib.get("content-desc")):
            return node
    return None


def tap_node(device: str, node: ElementTree.Element) -> None:
    x, y = _bounds_center(node.attrib["bounds"])
    run_command(adb_args(device, ["shell", "input", "tap", str(x), str(y)]))


def tap_label(device: str, root: ElementTree.Element, label: str, app_id: str) -> bool:
    node = find_node_by_label(root, label, app_id=app_id)
    if node is None:
        return False
    tap_node(device, node)
    return True


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


def build_artifact_metadata(path: Path | None) -> dict[str, object] | None:
    if path is None:
        return None
    resolved = path.resolve()
    if not resolved.exists():
        return {
            "path": repository_path(resolved),
            "exists": False,
        }
    digest = hashlib.sha256()
    with resolved.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "path": repository_path(resolved),
        "exists": True,
        "size_bytes": resolved.stat().st_size,
        "sha256": digest.hexdigest(),
    }


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


def wait_for_app_ui(device: str, app_id: str, *, timeout_seconds: int = 15) -> ElementTree.Element:
    deadline = time.time() + timeout_seconds
    last_root: ElementTree.Element | None = None
    while time.time() < deadline:
        try:
            root = dump_ui(device)
        except (ValueError, ElementTree.ParseError, subprocess.CalledProcessError):
            time.sleep(0.75)
            continue
        last_root = root
        if ui_contains_package(root, app_id):
            return root
        time.sleep(0.75)
    if last_root is None:
        raise RuntimeError("Could not read Android UI hierarchy.")
    raise RuntimeError(f"{app_id} did not become the foreground UI.")


def advance_onboarding_if_needed(device: str, app_id: str) -> None:
    for _ in range(8):
        root = wait_for_app_ui(device, app_id)
        if find_node_by_label(
            root,
            "Home",
            app_id=app_id,
        ) is not None and find_node_by_label(
            root,
            "Fan Zone",
            app_id=app_id,
        ) is not None:
            return
        if tap_label(device, root, "Get started", app_id):
            time.sleep(4)
            continue
        if tap_label(device, root, "Continue without sign-in", app_id):
            time.sleep(4)
            continue
        if tap_label(device, root, "Next", app_id):
            time.sleep(0.7)
            continue
        time.sleep(0.75)

    root = wait_for_app_ui(device, app_id)
    if not (
        find_node_by_label(root, "Home", app_id=app_id) is not None
        and find_node_by_label(root, "Fan Zone", app_id=app_id) is not None
    ):
        raise RuntimeError("Automated onboarding did not reach the authenticated shell.")


def return_to_home(device: str, app_id: str) -> None:
    for _ in range(5):
        root = wait_for_app_ui(device, app_id)
        has_shell = find_node_by_label(
            root,
            "Home",
            app_id=app_id,
        ) is not None and find_node_by_label(
            root,
            "Fan Zone",
            app_id=app_id,
        ) is not None
        if has_shell:
            tap_label(device, root, "Home", app_id)
            time.sleep(1.2)
            return
        run_command(adb_args(device, ["shell", "input", "keyevent", "BACK"]))
        time.sleep(1.2)
    raise RuntimeError("Could not return to the Home tab.")


def tap_visible_label_after_home(
    device: str,
    app_id: str,
    label: str,
    *,
    timeout_seconds: float = 8,
) -> None:
    return_to_home(device, app_id)
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        root = wait_for_app_ui(device, app_id)
        if tap_label(device, root, label, app_id):
            time.sleep(1.5)
            return
        time.sleep(0.5)
    raise RuntimeError(f"Could not find Home quick action: {label}")


def run_automated_capture(device: str, app_id: str, output_dir: Path) -> list[Path]:
    run_command(adb_args(device, ["shell", "am", "force-stop", app_id]), check=False)
    time.sleep(1)
    launch_app(device, app_id)
    time.sleep(3)
    advance_onboarding_if_needed(device, app_id)
    time.sleep(2)

    captured: list[Path] = [capture_screenshot(device, "01_home_dashboard", output_dir)]
    root = wait_for_app_ui(device, app_id)
    if not tap_label(device, root, "Fan Zone", app_id):
        raise RuntimeError("Could not find bottom navigation item: Fan Zone")
    time.sleep(1.5)
    captured.append(capture_screenshot(device, "02_fanzone", output_dir))

    quick_action_captures = (
        ("Members", "03_membership"),
        ("Tickets", "04_ticketing"),
        ("Shop", "05_shop"),
        ("Groups", "06_contributions"),
    )
    for label, filename in quick_action_captures:
        tap_visible_label_after_home(device, app_id, label)
        captured.append(capture_screenshot(device, filename, output_dir))

    return_to_home(device, app_id)
    root = wait_for_app_ui(device, app_id)
    if not tap_label(device, root, "Settings", app_id):
        raise RuntimeError("Could not find bottom navigation item: Settings")
    time.sleep(1.5)
    captured.append(capture_screenshot(device, "07_settings", output_dir))
    return captured


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture or validate Rayon Sports Android store screenshots.",
    )
    parser.add_argument(
        "--mode",
        choices=("interactive", "rapid", "automated"),
        default="interactive",
        help="Capture mode when not using --validate-existing.",
    )
    parser.add_argument("--device", help="ADB device serial. Defaults to first connected device.")
    parser.add_argument("--app-id", default=DEFAULT_APP_ID, help="Android application id.")
    parser.add_argument("--capture-dir", type=Path, default=DEFAULT_CAPTURE_DIR)
    parser.add_argument("--fastlane-dir", type=Path, default=DEFAULT_FASTLANE_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument(
        "--build-mode",
        choices=("debug", "profile", "release", "unknown"),
        default="unknown",
        help="Build mode of the installed APK being captured.",
    )
    parser.add_argument(
        "--artifact",
        type=Path,
        help="Optional APK/AAB artifact path to fingerprint in the manifest.",
    )
    parser.add_argument("--copy-fastlane", action="store_true", help="Copy new captures to Fastlane metadata.")
    parser.add_argument(
        "--capture-current",
        metavar="FILENAME",
        help="Capture the current foreground screen without interactive prompts.",
    )
    parser.add_argument("--launch", action="store_true", help="Launch the app before capturing.")
    parser.add_argument(
        "--keep-accessibility-shortcut",
        action="store_true",
        help=(
            "Do not temporarily hide Android's floating accessibility shortcut "
            "during capture. Automated mode hides it by default for clean screenshots."
        ),
    )
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
    accessibility_shortcut_hidden = False
    accessibility_shortcut_restored = False
    accessibility_shortcut_previous: dict[str, str | None] | None = None

    if args.validate_existing:
        screenshots = collect_existing_screenshots(args.fastlane_dir)
        mode = "validate_existing"
    else:
        try:
            device, device_metadata = find_device(args.device)
        except (RuntimeError, subprocess.CalledProcessError) as error:
            print(f"Device discovery failed: {error}", file=sys.stderr)
            return 2

        should_hide_shortcut = args.mode == "automated" and not args.keep_accessibility_shortcut
        try:
            if should_hide_shortcut:
                accessibility_shortcut_previous = hide_accessibility_shortcut(device)
                accessibility_shortcut_hidden = True
                time.sleep(0.5)

            if args.launch:
                launch_app(device, args.app_id)
                time.sleep(3)

            if args.mode != "automated" and not app_is_running(device, args.app_id):
                print(
                    f"App {args.app_id} is not running. Start it before capture.",
                    file=sys.stderr,
                )
                return 2

            if args.capture_current:
                screenshots = [capture_screenshot(device, args.capture_current, args.capture_dir)]
                mode = "capture_current"
            elif args.mode == "automated":
                screenshots = run_automated_capture(device, args.app_id, args.capture_dir)
                mode = args.mode
            else:
                screenshots = (
                    run_rapid_capture(device, args.capture_dir)
                    if args.mode == "rapid"
                    else run_interactive_capture(device, args.capture_dir)
                )
                mode = args.mode
        finally:
            if accessibility_shortcut_previous is not None:
                restore_accessibility_shortcut(device, accessibility_shortcut_previous)
                accessibility_shortcut_restored = True
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
        "build_mode": args.build_mode,
        "artifact": build_artifact_metadata(args.artifact),
        "min_count": args.min_count,
        "screenshot_count": len(screenshots),
        "screenshots": validations,
        "accessibility_shortcut_hidden": accessibility_shortcut_hidden,
        "accessibility_shortcut_restored": accessibility_shortcut_restored,
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
