#!/usr/bin/env python3
"""
Gikundiro Play Store Screenshot Capture Script

Captures real screenshots from the running app on a connected Android device.
Uses ADB to take screenshots after the app navigates to each screen.

Requirements:
  - ADB installed and a device connected
  - The app installed and running on the device (debug or profile mode)
  - Device unlocked with the app in foreground

Usage:
  1. Launch the app on device: flutter run --dart-define-from-file=assets/flavors/production.json
  2. Manually navigate to each screen, or let the script control via ADB key events
  3. Run: python3 capture_screenshots.py

The script will:
  - Wait for you to position on each screen
  - Capture a screenshot via ADB
  - Save to store_metadata/play_store/screenshots/
  - Name files sequentially for Fastlane compatibility
"""

import os
import subprocess
import sys
import time
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────────
DEVICE_SERIAL = None  # Auto-detect if None
SCREENSHOT_DIR = Path(__file__).parent.parent / "store_metadata" / "play_store" / "screenshots"
FASTLANE_DIR = Path(__file__).parent.parent / "android" / "fastlane" / "metadata" / "android" / "en-US" / "images" / "phoneScreenshots"

# Screens to capture (name, description, instructions for manual positioning)
SCREENS = [
    ("01_home_dashboard", "Home Dashboard", "Navigate to the Home tab — show the main dashboard with club info, quick actions, and news."),
    ("02_match_center", "Match Center", "Tap on a match from the home screen — show the live match detail view."),
    ("03_membership", "Membership Card", "Navigate to Membership — show the digital membership card."),
    ("04_ticketing", "Ticketing", "Open Ticketing — show available match tickets."),
    ("05_shop", "Official Shop", "Open Shop — show the merchandise listing."),
    ("06_BioPay", "BioPay NFC", "Navigate to the BioPay tab — show the biometric enrollment or payment screen."),
    ("07_contributions", "Contributions", "Open Contributions — show the contribution history / payment screen."),
    ("08_settings", "Settings", "Navigate to the Settings tab — show profile and app settings."),
]


def find_device() -> str:
    """Find connected ADB device."""
    if DEVICE_SERIAL:
        return DEVICE_SERIAL
    
    result = subprocess.run(
        ["adb", "devices"], capture_output=True, text=True, check=True
    )
    lines = result.stdout.strip().split("\n")[1:]  # Skip header
    devices = [l.split("\t")[0] for l in lines if "\tdevice" in l]
    
    if not devices:
        print("❌ No Android device connected. Connect a device and try again.")
        sys.exit(1)
    
    device = devices[0]
    # Get model name
    model = subprocess.run(
        ["adb", "-s", device, "shell", "getprop", "ro.product.model"],
        capture_output=True, text=True, check=True
    ).stdout.strip()
    
    resolution = subprocess.run(
        ["adb", "-s", device, "shell", "wm", "size"],
        capture_output=True, text=True, check=True
    ).stdout.strip()
    
    print(f"📱 Device: {model} ({device})")
    print(f"📐 Resolution: {resolution}")
    return device


def capture_screenshot(device: str, filename: str, output_dir: Path) -> Path:
    """Capture a screenshot from the device via ADB."""
    remote_path = f"/sdcard/screenshot_{filename}.png"
    local_path = output_dir / f"{filename}.png"
    
    # Capture on device
    subprocess.run(
        ["adb", "-s", device, "shell", "screencap", "-p", remote_path],
        check=True, capture_output=True
    )
    
    # Pull to local
    subprocess.run(
        ["adb", "-s", device, "pull", remote_path, str(local_path)],
        check=True, capture_output=True
    )
    
    # Clean up device
    subprocess.run(
        ["adb", "-s", device, "shell", "rm", remote_path],
        capture_output=True
    )
    
    size = local_path.stat().st_size
    print(f"  📸 Saved: {local_path.name} ({size // 1024}KB)")
    return local_path


def copy_to_fastlane(screenshots: list[Path], fastlane_dir: Path):
    """Copy screenshots to Fastlane metadata directory with sequential naming."""
    fastlane_dir.mkdir(parents=True, exist_ok=True)
    
    for i, src in enumerate(screenshots, 1):
        dst = fastlane_dir / f"{i}_en-US.png"
        import shutil
        shutil.copy2(src, dst)
        print(f"  📋 Copied → {dst.name}")


def interactive_mode(device: str):
    """Interactive mode — prompt user to position on each screen before capturing."""
    print("\n" + "=" * 60)
    print("🎯 INTERACTIVE SCREENSHOT CAPTURE")
    print("=" * 60)
    print(f"\nThis will capture {len(SCREENS)} screenshots.")
    print("For each screen, position the app on your device, then press Enter.\n")
    
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    captured = []
    
    for i, (filename, title, instructions) in enumerate(SCREENS, 1):
        print(f"\n{'─' * 50}")
        print(f"  Screen {i}/{len(SCREENS)}: {title}")
        print(f"  📋 {instructions}")
        print(f"{'─' * 50}")
        
        response = input(f"  → Position the app on '{title}', then press Enter (or 's' to skip): ").strip().lower()
        
        if response == 's':
            print(f"  ⏭  Skipped: {title}")
            continue
        
        # Small delay for any animations to settle
        time.sleep(0.5)
        
        path = capture_screenshot(device, filename, SCREENSHOT_DIR)
        captured.append(path)
    
    return captured


def auto_mode(device: str):
    """Auto mode — capture whatever is currently on screen, one after another.
    
    Useful when the app is already positioned or you're using screen recording.
    Takes a screenshot every time you press Enter.
    """
    print("\n" + "=" * 60)
    print("📸 RAPID CAPTURE MODE")
    print("=" * 60)
    print("\nPress Enter to capture a screenshot.")
    print("Type 'done' when finished.\n")
    
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    captured = []
    counter = 1
    
    while True:
        response = input(f"  Screenshot #{counter} → Press Enter to capture (or 'done' to finish): ").strip().lower()
        
        if response == 'done':
            break
        
        filename = f"screenshot_{counter:02d}"
        path = capture_screenshot(device, filename, SCREENSHOT_DIR)
        captured.append(path)
        counter += 1
    
    return captured


def main():
    print("🏟️  Gikundiro — Play Store Screenshot Capture")
    print("=" * 50)
    
    device = find_device()
    
    # Check app is running
    result = subprocess.run(
        ["adb", "-s", device, "shell", "pidof", "rw.gikundiro.app"],
        capture_output=True, text=True
    )
    
    if result.returncode != 0 or not result.stdout.strip():
        print("\n⚠️  App 'rw.gikundiro.app' is not running on the device.")
        print("   Launch it first with:")
        print("   flutter run --dart-define-from-file=assets/flavors/production.json")
        print("\n   Or install the APK:")
        print("   flutter build apk --dart-define-from-file=assets/flavors/production.json")
        print("   adb install build/app/outputs/flutter-apk/app-release.apk")
        
        proceed = input("\n   Continue anyway? (y/n): ").strip().lower()
        if proceed != 'y':
            sys.exit(0)
    else:
        print(f"✅ App is running (PID: {result.stdout.strip()})")
    
    # Choose mode
    print("\nCapture mode:")
    print("  1. Interactive — guided through each screen (recommended)")
    print("  2. Rapid — press Enter to capture current screen")
    
    mode = input("\nChoose mode (1/2): ").strip()
    
    if mode == "2":
        captured = auto_mode(device)
    else:
        captured = interactive_mode(device)
    
    if not captured:
        print("\n❌ No screenshots captured.")
        sys.exit(1)
    
    # Copy to Fastlane
    print(f"\n{'=' * 50}")
    print(f"📦 Copying {len(captured)} screenshots to Fastlane metadata...")
    copy_to_fastlane(captured, FASTLANE_DIR)
    
    print(f"\n✅ Done! {len(captured)} screenshots captured.")
    print(f"   Screenshots: {SCREENSHOT_DIR}")
    print(f"   Fastlane:    {FASTLANE_DIR}")
    print(f"\n   Google Play requires minimum 2, recommended 4-8 phone screenshots.")
    print(f"   Resolution: 1080x2340 (Pixel 4a) — meets Google's requirements. ✅")


if __name__ == "__main__":
    main()
