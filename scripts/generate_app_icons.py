#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
CLIENT_ROOT = ROOT / "apps" / "client_flutter"
BRANDING_DIR = CLIENT_ROOT / "assets" / "branding"

IOS_ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_ICON_SIZES = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}

WEB_ICON_SIZES = {
    "favicon.png": 32,
    "icons/Icon-192.png": 192,
    "icons/Icon-512.png": 512,
    "icons/Icon-maskable-192.png": 192,
    "icons/Icon-maskable-512.png": 512,
}

LAUNCH_IMAGE_SIZES = {
    "LaunchImage.png": 200,
    "LaunchImage@2x.png": 400,
    "LaunchImage@3x.png": 600,
}


def _average_corner_color(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    sample_points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
    ]
    channels = [0, 0, 0]
    for x, y in sample_points:
        r, g, b, _ = rgba.getpixel((x, y))
        channels[0] += r
        channels[1] += g
        channels[2] += b
    return tuple(channel // len(sample_points) for channel in channels)


def _build_master_icon(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    master_size = 1024
    background_scale = max(master_size / source.width, master_size / source.height)
    background_width = round(source.width * background_scale)
    background_height = round(source.height * background_scale)
    background = source.resize(
        (background_width, background_height),
        Image.Resampling.LANCZOS,
    )
    background = background.filter(ImageFilter.GaussianBlur(radius=18))
    background = ImageEnhance.Brightness(background).enhance(0.92)
    canvas = Image.new(
        "RGBA",
        (master_size, master_size),
        _average_corner_color(source) + (255,),
    )
    background_offset = (
        (master_size - background_width) // 2,
        (master_size - background_height) // 2,
    )
    canvas.alpha_composite(background, background_offset)

    scale = min((master_size * 0.9) / source.width, (master_size * 0.9) / source.height)
    resized_width = round(source.width * scale)
    resized_height = round(source.height * scale)
    resized = source.resize(
        (resized_width, resized_height),
        Image.Resampling.LANCZOS,
    )

    offset = (
        (master_size - resized_width) // 2,
        (master_size - resized_height) // 2,
    )
    canvas.alpha_composite(resized, offset)
    return canvas.convert("RGB")


def _write_icon(image: Image.Image, output_path: Path, size: int) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(output_path, format="PNG")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: generate_app_icons.py <source-icon-path>", file=sys.stderr)
        return 1

    source_path = Path(sys.argv[1]).expanduser().resolve()
    if not source_path.is_file():
        print(f"Source icon not found: {source_path}", file=sys.stderr)
        return 1

    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    source_copy_path = BRANDING_DIR / "the_bit_and_bond_icon_source.png"
    source_copy_path.write_bytes(source_path.read_bytes())

    master_icon = _build_master_icon(source_path)
    master_path = BRANDING_DIR / "the_bit_and_bond_icon_master.png"
    master_icon.save(master_path, format="PNG")

    ios_icon_dir = CLIENT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    launch_image_dir = CLIENT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    android_res_dir = CLIENT_ROOT / "android" / "app" / "src" / "main" / "res"
    web_dir = CLIENT_ROOT / "web"

    for filename, size in IOS_ICON_SIZES.items():
        _write_icon(master_icon, ios_icon_dir / filename, size)

    for relative_path, size in ANDROID_ICON_SIZES.items():
        _write_icon(master_icon, android_res_dir / relative_path, size)

    for relative_path, size in WEB_ICON_SIZES.items():
        _write_icon(master_icon, web_dir / relative_path, size)

    for filename, size in LAUNCH_IMAGE_SIZES.items():
        _write_icon(master_icon, launch_image_dir / filename, size)

    print(f"Generated launcher icons from {source_path}")
    print(f"Master icon: {master_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
