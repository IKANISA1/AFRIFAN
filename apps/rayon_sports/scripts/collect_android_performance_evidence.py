#!/usr/bin/env python3
"""Collect Android startup and frame evidence for Rayon Sports.

This script is intentionally lightweight: it uses ADB-only signals available on
developer devices and CI-attached Android targets. It does not claim full
profile/perf signoff, but it creates repeatable evidence for startup timing,
window readiness, frame stats, and relevant runtime logs.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


APP_DIR = Path(__file__).resolve().parents[1]
DEFAULT_APP_ID = "rw.gikundiro.app"
DEFAULT_ACTIVITY = "rw.gikundiro.app.MainActivity"
DEFAULT_OUTPUT = APP_DIR / "store_metadata" / "play_store" / "android_performance_manifest.json"
DEFAULT_TRACE_DIR = APP_DIR / "store_metadata" / "play_store" / "performance_traces"


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

    return device, {
        "serial": device,
        "model": adb_shell(device, "getprop", "ro.product.model").strip(),
        "android_version": adb_shell(device, "getprop", "ro.build.version.release").strip(),
        "screen_size": adb_shell(device, "wm", "size").strip(),
        "density": adb_shell(device, "wm", "density").strip(),
    }


def adb_shell(device: str, *args: str, check: bool = True) -> str:
    return run_command(adb_args(device, ["shell", *args]), check=check).stdout


def wait_for_process_exit(device: str, app_id: str, *, timeout_seconds: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        result = run_command(adb_args(device, ["shell", "pidof", app_id]), check=False)
        if result.returncode != 0 or not result.stdout.strip():
            return True
        time.sleep(0.25)
    return False


def repository_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(APP_DIR))
    except ValueError:
        return str(resolved)


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def parse_am_start(output: str) -> dict[str, object]:
    parsed: dict[str, object] = {"raw": output.strip().splitlines()}
    for line in output.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        normalized_key = key.strip().lower().replace(" ", "_")
        value = value.strip()
        if normalized_key in {"thistime", "totaltime", "waittime"}:
            try:
                parsed[f"{normalized_key}_ms"] = int(value)
            except ValueError:
                parsed[normalized_key] = value
        else:
            parsed[normalized_key] = value
    return parsed


def parse_window_state(output: str, app_id: str) -> dict[str, object]:
    lines = [
        line.strip()
        for line in output.splitlines()
        if app_id in line
        or "mCurrentFocus=" in line
        or "mFocusedApp=" in line
        or "mTopFullscreenOpaqueWindowState=" in line
    ]
    return {
        "raw": lines,
        "current_focus_is_app": any("mCurrentFocus=" in line and app_id in line for line in lines),
        "top_window_is_app": any(
            "mTopFullscreenOpaqueWindowState=" in line and app_id in line
            for line in lines
        ),
        "splash_top_window": any(
            "mTopFullscreenOpaqueWindowState=" in line and "Splash Screen" in line
            for line in lines
        ),
    }


def parse_gfxinfo(output: str) -> dict[str, object]:
    summary: dict[str, object] = {"raw_excerpt": output.splitlines()[:80]}
    patterns = {
        "total_frames": r"Total frames rendered:\s+(\d+)",
        "janky_frames": r"Janky frames:\s+(\d+)\s+\(([^)]+)\)",
        "p50_ms": r"50th percentile:\s+(\d+)ms",
        "p90_ms": r"90th percentile:\s+(\d+)ms",
        "p95_ms": r"95th percentile:\s+(\d+)ms",
        "p99_ms": r"99th percentile:\s+(\d+)ms",
        "missed_vsync": r"Number Missed Vsync:\s+(\d+)",
        "slow_ui_thread": r"Number Slow UI thread:\s+(\d+)",
        "slow_bitmap_uploads": r"Number Slow bitmap uploads:\s+(\d+)",
        "slow_draw_commands": r"Number Slow issue draw commands:\s+(\d+)",
        "deadline_missed": r"Number Frame deadline missed:\s+(\d+)",
    }
    for key, pattern in patterns.items():
        match = re.search(pattern, output)
        if not match:
            continue
        if key == "janky_frames":
            summary[key] = int(match.group(1))
            summary["janky_percent"] = match.group(2)
        else:
            summary[key] = int(match.group(1))
    total_frames = int(summary.get("total_frames", 0))
    summary["frame_stats_available"] = total_frames > 0
    if total_frames == 0:
        for percentile_key in ("p50_ms", "p90_ms", "p95_ms", "p99_ms"):
            if percentile_key in summary:
                summary[percentile_key] = None
    return summary


def parse_percent(value: object) -> float | None:
    if not isinstance(value, str):
        return None
    try:
        return float(value.strip().rstrip("%"))
    except ValueError:
        return None


def redact_log_line(line: str) -> str:
    redacted = re.sub(r"api_key:[A-Za-z0-9_-]+", "api_key:[REDACTED]", line)
    return re.sub(r"AIza[0-9A-Za-z_-]+", "[REDACTED_FIREBASE_API_KEY]", redacted)


def parse_screen_size(value: str) -> tuple[int, int] | None:
    match = re.search(r"(\d+)x(\d+)", value)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def run_swipe_exercise(
    device: str,
    *,
    screen_size: str,
    swipes: int,
    swipe_duration_ms: int,
    pause_seconds: float,
) -> list[dict[str, object]]:
    dimensions = parse_screen_size(screen_size)
    if dimensions is None:
        raise RuntimeError(f"Could not parse device screen size: {screen_size}")

    width, height = dimensions
    y = int(height * 0.54)
    left = int(width * 0.18)
    right = int(width * 0.82)
    events: list[dict[str, object]] = []

    for index in range(swipes):
        if index % 2 == 0:
            start_x, end_x, direction = right, left, "left"
        else:
            start_x, end_x, direction = left, right, "right"

        adb_shell(
            device,
            "input",
            "swipe",
            str(start_x),
            str(y),
            str(end_x),
            str(y),
            str(swipe_duration_ms),
        )
        events.append(
            {
                "direction": direction,
                "duration_ms": swipe_duration_ms,
                "end": [end_x, y],
                "index": index + 1,
                "start": [start_x, y],
            }
        )
        time.sleep(pause_seconds)

    return events


def build_assessment(
    *,
    collection_success: bool,
    gfxinfo: dict[str, object],
    start_timing: dict[str, object],
    startup_target_ms: int,
    max_janky_percent: float,
    minimum_frame_sample: int,
) -> dict[str, object]:
    total_time = start_timing.get("totaltime_ms")
    total_frames = int(gfxinfo.get("total_frames", 0))
    janky_percent = parse_percent(gfxinfo.get("janky_percent"))
    issues: list[str] = []

    startup_target_met = isinstance(total_time, int) and total_time <= startup_target_ms
    if not isinstance(total_time, int):
        issues.append("Cold start total time was unavailable.")
    elif not startup_target_met:
        issues.append(
            f"Cold start total time {total_time}ms exceeds target {startup_target_ms}ms."
        )

    frame_sample_large_enough = total_frames >= minimum_frame_sample
    if not frame_sample_large_enough:
        issues.append(
            f"Frame sample has {total_frames} frame(s); minimum useful sample is {minimum_frame_sample}."
        )

    jank_target_met = (
        janky_percent is not None
        and frame_sample_large_enough
        and janky_percent <= max_janky_percent
    )
    if janky_percent is None:
        issues.append("Janky-frame percentage was unavailable.")
    elif frame_sample_large_enough and not jank_target_met:
        issues.append(
            f"Janky-frame percentage {janky_percent:.2f}% exceeds target {max_janky_percent:.2f}%."
        )

    return {
        "collection_success": collection_success,
        "frame_sample_large_enough": frame_sample_large_enough,
        "issues": issues,
        "jank_target_met": jank_target_met,
        "janky_percent": janky_percent,
        "max_janky_percent": max_janky_percent,
        "minimum_frame_sample": minimum_frame_sample,
        "performance_signoff_ready": collection_success
        and startup_target_met
        and frame_sample_large_enough
        and jank_target_met,
        "startup_target_met": startup_target_met,
        "startup_target_ms": startup_target_ms,
    }


def collect_log_excerpt(
    device: str,
    app_id: str,
    lines: int,
    *,
    app_pid: str | None,
) -> list[str]:
    output = run_command(adb_args(device, ["logcat", "-d", "-v", "time"]), check=False).stdout
    pid_pattern = re.compile(rf"\(\s*{re.escape(app_pid)}\)") if app_pid else None
    keywords = (
        "flutter",
        "firebase",
        "supabase",
        "bootstrap",
        "exception",
        "error",
        "skipped",
    )
    interesting = [
        line
        for line in output.splitlines()
        if app_id in line
        or (
            pid_pattern is not None
            and pid_pattern.search(line)
            and any(keyword in line.lower() for keyword in keywords)
        )
    ]
    return [redact_log_line(line) for line in interesting[-lines:]]


def wait_for_remote_file_stable(
    device: str,
    remote_path: str,
    *,
    timeout_seconds: float,
) -> int | None:
    deadline = time.monotonic() + timeout_seconds
    last_size: int | None = None
    stable_count = 0
    quoted_path = shell_quote(remote_path)

    while time.monotonic() < deadline:
        output = adb_shell(
            device,
            "sh",
            "-c",
            f"if [ -f {quoted_path} ]; then stat -c %s {quoted_path}; fi",
            check=False,
        ).strip()
        try:
            size = int(output.splitlines()[-1]) if output else None
        except ValueError:
            size = None

        if size and size > 0 and size == last_size:
            stable_count += 1
            if stable_count >= 2:
                return size
        else:
            stable_count = 0
        last_size = size
        time.sleep(1)

    return last_size


def start_perfetto_trace(
    device: str,
    *,
    app_id: str,
    duration_seconds: int,
    generated_at: str,
) -> dict[str, object]:
    safe_timestamp = re.sub(r"[^0-9A-Za-z_-]+", "-", generated_at).strip("-")
    basename = f"rayon-profile-flow-{safe_timestamp}.pftrace"
    remote_path = f"/data/misc/perfetto-traces/{basename}"

    adb_shell(device, "rm", "-f", remote_path, check=False)
    command = adb_args(
        device,
        [
            "shell",
            "perfetto",
            "--background-wait",
            "-o",
            remote_path,
            "-t",
            f"{duration_seconds}s",
            "--app",
            app_id,
            "sched",
            "freq",
            "idle",
            "am",
            "wm",
            "gfx",
            "view",
            "binder_driver",
            "hal",
            "dalvik",
        ],
    )
    result = run_command(command, check=False)
    pid = (result.stdout + result.stderr).strip().splitlines()[-1:]
    return {
        "basename": basename,
        "duration_seconds": duration_seconds,
        "remote_path": remote_path,
        "start_returncode": result.returncode,
        "start_stdout": result.stdout.strip(),
        "start_stderr": result.stderr.strip(),
        "pid": pid[0] if pid else None,
        "started": result.returncode == 0,
    }


def finish_perfetto_trace(
    device: str,
    trace: dict[str, object],
    *,
    output_dir: Path,
    timeout_seconds: float,
) -> dict[str, object]:
    if not trace.get("started"):
        return trace | {"success": False, "issue": "Perfetto did not start."}

    output_dir.mkdir(parents=True, exist_ok=True)
    remote_path = str(trace["remote_path"])
    stable_size = wait_for_remote_file_stable(
        device,
        remote_path,
        timeout_seconds=timeout_seconds,
    )
    local_path = output_dir / str(trace["basename"])
    pull_result = run_command(
        adb_args(device, ["pull", remote_path, str(local_path)]),
        check=False,
    )
    adb_shell(device, "rm", "-f", remote_path, check=False)

    local_exists = local_path.exists()
    local_size = local_path.stat().st_size if local_exists else 0
    return trace | {
        "local_path": repository_path(local_path),
        "local_size_bytes": local_size,
        "pull_returncode": pull_result.returncode,
        "pull_stderr": pull_result.stderr.strip(),
        "pull_stdout": pull_result.stdout.strip(),
        "remote_stable_size_bytes": stable_size,
        "success": pull_result.returncode == 0 and local_exists and local_size > 0,
    }


def write_manifest(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Collect Android startup and frame evidence for Rayon Sports.",
    )
    parser.add_argument("--device", help="ADB device serial. Defaults to first connected device.")
    parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    parser.add_argument("--activity", default=DEFAULT_ACTIVITY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--settle-seconds", type=float, default=10.0)
    parser.add_argument("--log-lines", type=int, default=120)
    parser.add_argument("--startup-target-ms", type=int, default=3000)
    parser.add_argument("--max-janky-percent", type=float, default=5.0)
    parser.add_argument("--minimum-frame-sample", type=int, default=60)
    parser.add_argument(
        "--exercise-swipes",
        type=int,
        default=0,
        help="After startup settles, reset gfxinfo and perform this many horizontal swipes.",
    )
    parser.add_argument("--swipe-duration-ms", type=int, default=550)
    parser.add_argument("--swipe-pause-seconds", type=float, default=0.2)
    parser.add_argument(
        "--perfetto-duration-seconds",
        type=int,
        default=0,
        help="When >0, capture a Perfetto trace around startup and the exercised flow.",
    )
    parser.add_argument("--perfetto-output-dir", type=Path, default=DEFAULT_TRACE_DIR)
    parser.add_argument(
        "--build-mode",
        default="unknown",
        help="Metadata label for the installed APK under test, e.g. debug/profile/release.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    generated_at = datetime.now(timezone.utc).isoformat()

    try:
        device, metadata = find_device(args.device)
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Device discovery failed: {error}", file=sys.stderr)
        return 2

    component = f"{args.app_id}/{args.activity}"
    adb_shell(device, "am", "force-stop", args.app_id, check=False)
    process_stopped_before_launch = wait_for_process_exit(device, args.app_id)
    run_command(adb_args(device, ["logcat", "-c"]), check=False)
    adb_shell(device, "dumpsys", "gfxinfo", args.app_id, "reset", check=False)
    perfetto_trace: dict[str, object] | None = None
    if args.perfetto_duration_seconds > 0:
        perfetto_trace = start_perfetto_trace(
            device,
            app_id=args.app_id,
            duration_seconds=args.perfetto_duration_seconds,
            generated_at=generated_at,
        )

    started_at_monotonic = time.monotonic()
    start_result = run_command(
        adb_args(device, ["shell", "am", "start", "-W", "-n", component]),
        check=False,
    )
    time.sleep(args.settle_seconds)
    interaction_events: list[dict[str, object]] = []
    gfxinfo_scope = "startup"
    if args.exercise_swipes > 0:
        adb_shell(device, "dumpsys", "gfxinfo", args.app_id, "reset", check=False)
        interaction_events = run_swipe_exercise(
            device,
            screen_size=metadata["screen_size"],
            swipes=args.exercise_swipes,
            swipe_duration_ms=args.swipe_duration_ms,
            pause_seconds=args.swipe_pause_seconds,
        )
        time.sleep(1)
        gfxinfo_scope = "post_start_swipe_exercise"
    elapsed_seconds = round(time.monotonic() - started_at_monotonic, 3)
    if perfetto_trace is not None:
        perfetto_trace = finish_perfetto_trace(
            device,
            perfetto_trace,
            output_dir=args.perfetto_output_dir,
            timeout_seconds=max(args.perfetto_duration_seconds + 20, 30),
        )

    app_pid = adb_shell(device, "pidof", args.app_id, check=False).strip() or None
    window_state = parse_window_state(
        adb_shell(device, "dumpsys", "window", check=False),
        args.app_id,
    )
    gfxinfo_raw = adb_shell(device, "dumpsys", "gfxinfo", args.app_id, "framestats", check=False)
    gfxinfo = parse_gfxinfo(gfxinfo_raw)
    logs = collect_log_excerpt(device, args.app_id, args.log_lines, app_pid=app_pid)

    start_timing = parse_am_start(start_result.stdout + start_result.stderr)
    collection_success = (
        start_result.returncode == 0
        and window_state["current_focus_is_app"]
        and window_state["top_window_is_app"]
        and not window_state["splash_top_window"]
    )
    assessment = build_assessment(
        collection_success=collection_success,
        gfxinfo=gfxinfo,
        start_timing=start_timing,
        startup_target_ms=args.startup_target_ms,
        max_janky_percent=args.max_janky_percent,
        minimum_frame_sample=args.minimum_frame_sample,
    )

    manifest = {
        "app_id": args.app_id,
        "activity": args.activity,
        "assessment": assessment,
        "build_mode": args.build_mode,
        "device": metadata,
        "elapsed_seconds": elapsed_seconds,
        "generated_at": generated_at,
        "gfxinfo": gfxinfo,
        "gfxinfo_scope": gfxinfo_scope,
        "interaction_events": interaction_events,
        "pid": app_pid,
        "log_excerpt": logs,
        "output": repository_path(args.output),
        "perfetto_trace": perfetto_trace,
        "process_stopped_before_launch": process_stopped_before_launch,
        "settle_seconds": args.settle_seconds,
        "start_command_returncode": start_result.returncode,
        "start_timing": start_timing,
        "success": collection_success,
        "window_state": window_state,
    }
    write_manifest(args.output, manifest)
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0 if collection_success else 1


if __name__ == "__main__":
    raise SystemExit(main())
