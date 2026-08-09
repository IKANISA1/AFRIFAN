#!/usr/bin/env python3
"""Generate deterministic, generic Android TV launcher artwork.

The artwork intentionally uses only the existing app name and the blue from the
previous banner resource. It does not embed a club crest, player photograph, or
third-party mark. Human brand/rights approval remains a separate release gate.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BLUE = "#0038A8"
DEEP_BLUE = "#001C55"
WHITE = "#FFFFFF"
ACCENT = "#6EC6FF"
FONT_CANDIDATES = (
    Path("/System/Library/Fonts/SFNS.ttf"),
    Path("/System/Library/Fonts/Helvetica.ttc"),
    Path("/Library/Fonts/Arial.ttf"),
)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in FONT_CANDIDATES:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default(size=size)


def _gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, BLUE)
    pixels = image.load()
    start = ImageColor.getrgb(DEEP_BLUE)
    end = ImageColor.getrgb(BLUE)
    for x in range(width):
        ratio = x / max(width - 1, 1)
        color = tuple(round(a + (b - a) * ratio) for a, b in zip(start, end))
        for y in range(height):
            pixels[x, y] = color
    return image


# Pillow keeps ImageColor in a separate module; importing it below makes the
# color conversion explicit while keeping the public constants easy to audit.
from PIL import ImageColor  # noqa: E402  (intentional after constants)


def _centered_text(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    fill: str,
) -> None:
    left, top, right, bottom = box
    text_box = draw.textbbox((0, 0), text, font=font)
    width = text_box[2] - text_box[0]
    height = text_box[3] - text_box[1]
    x = left + ((right - left) - width) / 2
    y = top + ((bottom - top) - height) / 2 - text_box[1]
    draw.text((x, y), text, font=font, fill=fill)


def build_banner(path: Path) -> None:
    image = _gradient((320, 180))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((18, 18, 302, 162), radius=22, outline=ACCENT, width=3)
    _centered_text(draw, (28, 38, 292, 104), "GIKUNDIRO", _font(40), WHITE)
    _centered_text(draw, (28, 103, 292, 149), "TV", _font(30), ACCENT)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def build_icon(path: Path) -> None:
    image = _gradient((160, 160))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((13, 13, 147, 147), radius=32, outline=ACCENT, width=4)
    _centered_text(draw, (20, 22, 140, 103), "G", _font(76), WHITE)
    _centered_text(draw, (20, 99, 140, 139), "TV", _font(24), ACCENT)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()
    res = args.project_root / "android" / "app" / "src" / "main" / "res"
    build_banner(res / "drawable-xhdpi" / "tv_banner.png")
    build_icon(res / "mipmap-xhdpi" / "ic_launcher.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
