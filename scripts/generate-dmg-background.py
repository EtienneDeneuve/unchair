#!/usr/bin/env python3
"""Generate the Finder DMG background (drag Unchair → Applications)."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("docs/assets/dmg/background.png"),
    )
    parser.add_argument("--width", type=int, default=660)
    parser.add_argument("--height", type=int, default=400)
    args = parser.parse_args()

    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError as exc:  # pragma: no cover
        raise SystemExit("Pillow required: python3 -m pip install pillow") from exc

    width, height = args.width, args.height
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)

    # Charcoal → deep slate (avoid purple/cream AI defaults).
    top = (30, 34, 38)
    bottom = (14, 16, 18)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (width, y)], fill=color)

    # Empty drop-zone frames where Finder places Unchair.app / Applications.
    zones = ((180, 168), (480, 168))
    half = 72
    for cx, cy in zones:
        draw.rounded_rectangle(
            (cx - half, cy - half, cx + half, cy + half),
            radius=18,
            outline=(62, 70, 78),
            width=2,
        )

    # Teal guide arrow between the zones.
    mint = (43, 181, 160)
    ax1, ax2, ay = 262, 398, 168
    draw.line([(ax1, ay), (ax2 - 14, ay)], fill=mint, width=3)
    draw.polygon(
        [(ax2, ay), (ax2 - 18, ay - 10), (ax2 - 18, ay + 10)],
        fill=mint,
    )

    # Soft shelf under icons.
    draw.rounded_rectangle(
        (48, 268, width - 48, 272),
        radius=2,
        fill=(64, 72, 80),
    )

    try:
        font_title = ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Avenir Next.ttc", 22, index=1
        )
        font_hint = ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Avenir Next.ttc", 13, index=0
        )
    except OSError:
        try:
            font_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
            font_hint = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
        except OSError:
            font_title = ImageFont.load_default()
            font_hint = font_title

    title = "Unchair"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    draw.text(((width - tw) / 2, 36), title, fill=(210, 216, 220), font=font_title)

    hint = "Drag Unchair to Applications to install"
    bbox = draw.textbbox((0, 0), hint, font=font_hint)
    tw = bbox[2] - bbox[0]
    draw.text(((width - tw) / 2, height - 40), hint, fill=(150, 158, 166), font=font_hint)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    img.save(args.output, format="PNG", optimize=True)
    print(args.output)


if __name__ == "__main__":
    main()
