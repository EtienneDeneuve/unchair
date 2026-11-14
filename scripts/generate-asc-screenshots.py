#!/usr/bin/env python3
"""Compose Mac App Store screenshots at Apple's 16:10 sizes from real Unchair UI crops.

ASC Mac sizes: 1280x800, 1440x900, 2560x1600, 2880x1800.
Default output: 2880x1800 (+ 1440x900 half-res copies).

Source crops live under docs/assets/ — they are shipping UI, not mocks.
Live fullscreen capture is preferred when Screen Recording is available to the
operator; this script is the reproducible packaging path for #141.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Shot:
    stem: str
    source: Path
    caption_en: str
    max_fraction: float = 0.72  # max height/width of canvas for the UI crop


SHOTS: tuple[Shot, ...] = (
    Shot(
        "01-menubar",
        Path("docs/assets/screenshots/01-menubar-menu.png"),
        "Break reminders from the menu bar — local, no account.",
        0.55,
    ),
    Shot(
        "02-today",
        Path("docs/assets/today-ui/today-dark.png"),
        "Today: local break history and camera recovery on this Mac.",
        0.78,
    ),
    Shot(
        "03-settings",
        Path("docs/assets/screenshots/02-settings-schedule-posture.png"),
        "Schedule and optional on-device movement verification.",
        0.82,
    ),
    Shot(
        "04-overlay",
        Path("docs/assets/screenshots/05-overlay-break-due.png"),
        "When a break is due, Unchair can wait for you to stand up.",
        0.70,
    ),
    Shot(
        "05-human-runtime",
        Path("docs/assets/today-ui/human-runtime-week-card.png"),
        "Human Runtime weekly card — privacy-safe scalars only.",
        0.70,
    ),
)


def _gradient(size: tuple[int, int]) -> "Image.Image":
    from PIL import Image, ImageDraw

    width, height = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    top = (28, 32, 36)
    bottom = (12, 14, 16)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (width, y)], fill=color)
    # Soft teal wash (brand accent, not purple).
    wash = Image.new("RGBA", size, (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(wash)
    for i in range(8):
        alpha = 18 - i * 2
        pad = 80 + i * 40
        wdraw.ellipse(
            (width // 2 - 900 - pad, -200 - pad, width // 2 + 900 + pad, 700 + pad),
            fill=(43, 181, 160, max(alpha, 0)),
        )
    img = Image.alpha_composite(img.convert("RGBA"), wash).convert("RGB")
    return img


def _font(size: int):
    from PIL import ImageFont

    candidates = [
        ("/System/Library/Fonts/Supplemental/Avenir Next.ttc", 1),
        ("/System/Library/Fonts/Supplemental/Avenir Next.ttc", 0),
        ("/System/Library/Fonts/Helvetica.ttc", 0),
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def _fit(im: "Image.Image", max_w: int, max_h: int) -> "Image.Image":
    from PIL import Image

    scale = min(max_w / im.width, max_h / im.height, 1.0)
    # Allow upscale for small crops so they read on a 2880 canvas.
    if scale < 1.0 or (im.width < max_w * 0.45 and im.height < max_h * 0.45):
        scale = min(max_w / im.width, max_h / im.height)
    new = (max(1, int(im.width * scale)), max(1, int(im.height * scale)))
    return im.resize(new, Image.Resampling.LANCZOS)


def _shadow(base: "Image.Image", ui: "Image.Image", xy: tuple[int, int]) -> "Image.Image":
    from PIL import Image, ImageFilter

    canvas = base.convert("RGBA")
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    blob = Image.new("RGBA", ui.size, (0, 0, 0, 160))
    shadow.paste(blob, xy)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=36))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(ui.convert("RGBA"), xy, ui.convert("RGBA"))
    return canvas.convert("RGB")


def compose(shot: Shot, size: tuple[int, int], repo: Path) -> "Image.Image":
    from PIL import ImageDraw

    width, height = size
    canvas = _gradient(size)
    src = Image_open(repo / shot.source)
    max_w = int(width * shot.max_fraction)
    max_h = int(height * 0.68)
    ui = _fit(src, max_w, max_h)
    x = (width - ui.width) // 2
    y = int(height * 0.10)
    framed = _shadow(canvas, ui, (x, y))

    draw = ImageDraw.Draw(framed)
    font = _font(max(28, width // 55))
    caption = shot.caption_en
    bbox = draw.textbbox((0, 0), caption, font=font)
    tw = bbox[2] - bbox[0]
    tx = (width - tw) // 2
    ty = int(height * 0.88)
    # Subtle caption plate.
    pad_x, pad_y = 28, 16
    draw.rounded_rectangle(
        (tx - pad_x, ty - pad_y, tx + tw + pad_x, ty + (bbox[3] - bbox[1]) + pad_y),
        radius=14,
        fill=(18, 20, 22, 220) if framed.mode == "RGBA" else (18, 20, 22),
    )
    draw.text((tx, ty), caption, font=font, fill=(230, 234, 238))
    return framed


def Image_open(path: Path):
    from PIL import Image

    if not path.is_file():
        raise SystemExit(f"missing source: {path}")
    return Image.open(path).convert("RGBA")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output directory (default: docs/assets/app-store/screenshots)",
    )
    parser.add_argument(
        "--sizes",
        default="2880x1800,1440x900",
        help="Comma-separated WxH ASC sizes",
    )
    args = parser.parse_args()

    try:
        from PIL import Image  # noqa: F401
    except ImportError as exc:  # pragma: no cover
        raise SystemExit("Pillow required: python3 -m pip install pillow") from exc

    out = args.output or (args.repo / "docs/assets/app-store/screenshots")
    out.mkdir(parents=True, exist_ok=True)

    sizes: list[tuple[int, int]] = []
    for part in args.sizes.split(","):
        w, h = part.lower().strip().split("x")
        sizes.append((int(w), int(h)))

    written: list[Path] = []
    for shot in SHOTS:
        for w, h in sizes:
            img = compose(shot, (w, h), args.repo)
            path = out / f"{shot.stem}-{w}x{h}.png"
            img.save(path, format="PNG", optimize=True)
            written.append(path)
            print(f"wrote {path.relative_to(args.repo)} ({w}x{h})")

    manifest = out / "MANIFEST.txt"
    manifest.write_text(
        "\n".join(
            [
                "Unchair Mac App Store screenshots (#141)",
                "Composed from shipping docs/assets UI crops onto ASC 16:10 canvases.",
                "Upload the 2880x1800 set (or 1440x900) in App Store Connect → Mac.",
                "",
                *[str(p.relative_to(args.repo)) for p in written],
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(f"wrote {manifest.relative_to(args.repo)}")


if __name__ == "__main__":
    main()
