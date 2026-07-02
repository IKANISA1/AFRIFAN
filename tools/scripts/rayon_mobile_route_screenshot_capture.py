#!/usr/bin/env python3
"""Capture Rayon mobile route screenshots on an Android device.

Reads a route manifest such as the prior 53-screen audit manifest, opens each
HTTPS app link on a connected device, captures a PNG, and writes a fresh
manifest plus a simple HTML gallery for visual review.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import struct
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree


DEFAULT_APP_ID = "rw.gikundiro.app"
DEFAULT_SOURCE_MANIFEST = Path(
    "output/product_design_screen_report/20260701T051146Z/"
    "screenshots_53_device_actual/manifest_combined.json",
)
ROUTE_ERROR_MARKERS = (
    "Page not found",
    "Route not found",
    "GoRouter",
    "No route",
    "Unhandled exception",
)


@dataclass(frozen=True)
class RouteScreen:
    filename: str
    title: str
    route: str
    uri: str


def run_command(
    args: list[str],
    *,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess[str] | subprocess.CompletedProcess[bytes]:
    return subprocess.run(args, capture_output=True, check=check, text=text)


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
        lines = str(result.stdout).strip().splitlines()[1:]
        devices = [line.split("\t", 1)[0] for line in lines if "\tdevice" in line]
        if not devices:
            raise RuntimeError("No connected Android device found via `adb devices`.")
        device = devices[0]

    def prop(name: str) -> str:
        return str(run_command(adb_args(device, ["shell", "getprop", name])).stdout).strip()

    return device, {
        "serial": device,
        "model": prop("ro.product.model"),
        "android_version": prop("ro.build.version.release"),
        "screen_size": str(
            run_command(adb_args(device, ["shell", "wm", "size"])).stdout,
        ).strip(),
        "density": str(
            run_command(adb_args(device, ["shell", "wm", "density"])).stdout,
        ).strip(),
    }


def load_route_screens(path: Path) -> list[RouteScreen]:
    payload = json.loads(path.read_text())
    screens: list[RouteScreen] = []
    for item in payload["screens"]:
        filename = str(item["filename"])
        if filename.endswith(".png"):
            filename = filename[:-4]
        screens.append(
            RouteScreen(
                filename=filename,
                title=str(item["title"]),
                route=str(item["route"]),
                uri=str(item["uri"]),
            ),
        )
    return screens


def prepare_device(device: str) -> None:
    run_command(adb_args(device, ["shell", "input", "keyevent", "WAKEUP"]), check=False)
    run_command(adb_args(device, ["shell", "wm", "dismiss-keyguard"]), check=False)
    run_command(adb_args(device, ["shell", "svc", "power", "stayon", "true"]), check=False)


def open_uri(device: str, app_id: str, uri: str, component: str | None = None) -> str:
    command = [
        "shell",
        "am",
        "start",
        "-W",
        "-a",
        "android.intent.action.VIEW",
        "-d",
        uri,
    ]
    if component:
        command.extend(["-n", component])
    else:
        command.append(app_id)
    result = run_command(
        adb_args(device, command),
        check=False,
    )
    return f"{result.stdout}{result.stderr}"


def dump_ui(device: str) -> ElementTree.Element | None:
    remote_path = "/sdcard/rayon_route_capture_window.xml"
    result = run_command(
        adb_args(device, ["shell", "uiautomator", "dump", remote_path]),
        check=False,
    )
    if result.returncode != 0:
        return None
    xml_result = run_command(
        adb_args(device, ["exec-out", "cat", remote_path]),
        check=False,
    )
    run_command(adb_args(device, ["shell", "rm", remote_path]), check=False)
    xml = str(xml_result.stdout).strip()
    if not xml.startswith("<"):
        return None
    try:
        return ElementTree.fromstring(xml)
    except ElementTree.ParseError:
        return None


def collect_labels(root: ElementTree.Element | None) -> list[str]:
    if root is None:
        return []
    labels: list[str] = []
    for node in root.iter("node"):
        for key in ("text", "content-desc"):
            value = node.attrib.get(key, "").strip()
            if value and value not in labels:
                labels.append(value)
    return labels[:80]


def foreground_packages(root: ElementTree.Element | None) -> list[str]:
    if root is None:
        return []
    packages: list[str] = []
    for node in root.iter("node"):
        package = node.attrib.get("package", "").strip()
        if package and package not in packages:
            packages.append(package)
    return packages


def capture_png(device: str, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result = run_command(
        adb_args(device, ["exec-out", "screencap", "-p"]),
        text=False,
    )
    png = bytes(result.stdout)
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"ADB screencap did not return PNG bytes for {output_path.name}.")
    output_path.write_bytes(png)


def png_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG file.")
    return struct.unpack(">II", header[16:24])


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def has_route_error(labels: list[str]) -> bool:
    joined = "\n".join(labels)
    return any(marker in joined for marker in ROUTE_ERROR_MARKERS)


def is_expected_low_label_route(route_screen: RouteScreen) -> bool:
    return route_screen.route.startswith("/auth/") or route_screen.route in {
        "/splash",
        "/onboarding",
    }


def wait_for_route_labels(
    device: str,
    route_screen: RouteScreen,
    *,
    initial_wait_seconds: float,
    max_wait_seconds: float,
) -> tuple[ElementTree.Element | None, list[str], float]:
    time.sleep(initial_wait_seconds)
    elapsed = initial_wait_seconds
    root = dump_ui(device)
    labels = collect_labels(root)
    if is_expected_low_label_route(route_screen):
        return root, labels, elapsed

    while len(labels) <= 2 and elapsed < max_wait_seconds:
        time.sleep(2)
        elapsed += 2
        root = dump_ui(device)
        labels = collect_labels(root)
    return root, labels, elapsed


def write_gallery(output_dir: Path, screens: list[dict[str, object]]) -> None:
    cards = []
    for screen in screens:
        filename = html.escape(str(screen["filename"]))
        title = html.escape(str(screen["title"]))
        route = html.escape(str(screen["route"]))
        cards.append(
            f"<article><img src=\"{filename}\" alt=\"{title}\">"
            f"<h2>{title}</h2><p><code>{route}</code></p></article>"
        )
    html_text = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Rayon Mobile Route Screenshots</title>
  <style>
    body { margin: 24px; background: #08080d; color: #f7f7fb; font-family: system-ui, sans-serif; }
    main { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 18px; }
    article { background: #171721; border: 1px solid #333440; border-radius: 8px; padding: 10px; }
    img { width: 100%; display: block; border-radius: 6px; background: #000; }
    h2 { font-size: 15px; margin: 10px 0 4px; }
    p { margin: 0; color: #bbc0d4; font-size: 12px; overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <h1>Rayon Mobile Route Screenshots</h1>
  <main>
""" + "\n".join(cards) + """
  </main>
</body>
</html>
"""
    (output_dir / "gallery.html").write_text(html_text)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device")
    parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    parser.add_argument(
        "--component",
        help="Optional explicit Android component, e.g. rw.gikundiro.app/.MainActivity.",
    )
    parser.add_argument("--source-manifest", type=Path, default=DEFAULT_SOURCE_MANIFEST)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--wait-seconds", type=float, default=2.5)
    parser.add_argument("--max-wait-seconds", type=float, default=28)
    parser.add_argument("--min-count", type=int, default=50)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    device, device_meta = find_device(args.device)
    route_screens = load_route_screens(args.source_manifest)
    prepare_device(device)

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    captured: list[dict[str, object]] = []
    bad_route_error_screens: list[str] = []
    for index, route_screen in enumerate(route_screens, start=1):
        print(f"{index:02d}/{len(route_screens)} {route_screen.title} {route_screen.route}")
        start_output = open_uri(
            device,
            args.app_id,
            route_screen.uri,
            component=args.component,
        )
        root, labels, waited_seconds = wait_for_route_labels(
            device,
            route_screen,
            initial_wait_seconds=args.wait_seconds,
            max_wait_seconds=args.max_wait_seconds,
        )
        packages = foreground_packages(root)
        filename = f"{route_screen.filename}.png"
        path = output_dir / filename
        capture_png(device, path)
        width, height = png_dimensions(path)
        route_error = has_route_error(labels)
        if route_error:
            bad_route_error_screens.append(filename)
        captured.append(
            {
                "filename": filename,
                "title": route_screen.title,
                "route": route_screen.route,
                "uri": route_screen.uri,
                "width": width,
                "height": height,
                "size_bytes": path.stat().st_size,
                "sha256": sha256_file(path),
                "labels": labels,
                "waited_seconds": waited_seconds,
                "foreground_packages": packages,
                "route_error_detected": route_error,
                "am_start": start_output.strip().splitlines()[-8:],
            },
        )

    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "capture_method": "Android HTTPS app links via adb am start; adb exec-out screencap -p",
        "app_id": args.app_id,
        "component": args.component,
        "device": device_meta,
        "source_manifest": str(args.source_manifest),
        "count": len(captured),
        "min_count": args.min_count,
        "success": len(captured) >= args.min_count and not bad_route_error_screens,
        "bad_route_error_screens": bad_route_error_screens,
        "screens": captured,
    }
    (output_dir / "manifest_combined.json").write_text(json.dumps(manifest, indent=2) + "\n")
    write_gallery(output_dir, captured)
    print(json.dumps({
        "output_dir": str(output_dir),
        "count": len(captured),
        "success": manifest["success"],
        "bad_route_error_screens": bad_route_error_screens,
    }, indent=2))
    return 0 if manifest["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
