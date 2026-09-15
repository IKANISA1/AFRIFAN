#!/usr/bin/env python3
"""Install the pinned official bundletool JAR at an explicitly selected path."""
import hashlib
from pathlib import Path
import shutil
import sys
import tempfile
import urllib.request

VERSION = "1.18.1"
SHA256 = "675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c"
URL = f"https://github.com/google/bundletool/releases/download/{VERSION}/bundletool-all-{VERSION}.jar"


def digest(file):
    result = hashlib.sha256()
    with file.open("rb") as stream:
        for chunk in iter(lambda: stream.read(128 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


if len(sys.argv) != 2:
    raise SystemExit("Usage: prepare_bundletool.py <output-jar>")
destination = Path(sys.argv[1]).expanduser().absolute()
if destination.exists():
    if digest(destination) != SHA256:
        raise SystemExit("Existing bundletool file has an unexpected SHA-256; choose a new destination.")
else:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(destination.parent).free < 256 * 1024**2:
        raise SystemExit("At least 256 MiB free space is required to prepare bundletool.")
    temporary = None
    try:
        request = urllib.request.Request(URL, headers={"User-Agent": "AFRICLUB-QA"})
        with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".download", delete=False) as stream:
            temporary = Path(stream.name)
            with urllib.request.urlopen(request, timeout=30) as response:
                shutil.copyfileobj(response, stream, length=128 * 1024)
        if digest(temporary) != SHA256:
            raise SystemExit("Downloaded bundletool SHA-256 did not match the pinned official release.")
        temporary.rename(destination)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()
print(destination)
