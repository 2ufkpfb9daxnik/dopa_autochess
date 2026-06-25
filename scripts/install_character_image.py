#!/usr/bin/env python3
"""生成済み画像を src/characters/{id}/{id}.png へ配置（正方形・1024px に整形）。"""

import argparse
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PROMPTS_JSON = ROOT / "scripts" / "character_image_prompts.json"
ASSETS_DIR = Path.home() / ".cursor" / "projects" / "c-Users-njjjkr-src-dopa-autochess" / "assets"


def center_crop_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def install_image(char_id: str, source: Path, size: int = 1024) -> Path:
    dest = ROOT / "src" / "characters" / char_id / f"{char_id}.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(source).convert("RGBA")
    img = center_crop_square(img)
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    img.save(dest, "PNG", optimize=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", help="4-digit character id e.g. 0001")
    parser.add_argument("--source", help="path to source image")
    parser.add_argument("--from-assets", action="store_true", help="use assets/{id}.png")
    parser.add_argument("--batch-assets", action="store_true", help="install all assets/*.png by id")
    parser.add_argument("--size", type=int, default=1024)
    args = parser.parse_args()

    if args.batch_assets:
        count = 0
        for png in ASSETS_DIR.glob("*.png"):
            if not re.fullmatch(r"\d{4}", png.stem):
                continue
            install_image(png.stem, png, args.size)
            count += 1
        print(f"Installed {count} images from {ASSETS_DIR}")
        return

    if not args.id:
        raise SystemExit("--id is required unless --batch-assets")

    source = Path(args.source) if args.source else ASSETS_DIR / f"{args.id}.png"
    if not source.is_file():
        raise SystemExit(f"source not found: {source}")

    dest = install_image(args.id, source, args.size)
    print(f"Installed {dest}")


if __name__ == "__main__":
    main()
