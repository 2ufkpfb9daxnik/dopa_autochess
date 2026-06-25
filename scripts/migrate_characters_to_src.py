#!/usr/bin/env python3
"""dump/characters/*.md を src/characters/{4桁ID}/character.md へ移動する。"""

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMP_DIR = ROOT / "dump" / "characters"
SRC_DIR = ROOT / "src" / "characters"


def main() -> None:
    if not DUMP_DIR.is_dir():
        raise SystemExit(f"{DUMP_DIR} が見つかりません")

    SRC_DIR.mkdir(parents=True, exist_ok=True)
    moved = 0

    for path in sorted(DUMP_DIR.glob("*.md")):
        match = re.match(r"^(\d{4})", path.stem)
        if not match:
            print(f"skip: {path.name}")
            continue
        char_id = match.group(1)
        dest_dir = SRC_DIR / char_id
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_path = dest_dir / "character.md"
        shutil.move(str(path), str(dest_path))
        moved += 1

    remaining = list(DUMP_DIR.glob("*.md"))
    if remaining:
        print(f"warning: {len(remaining)} files left in dump/characters")

    print(f"Moved {moved} character sheets to {SRC_DIR}")


if __name__ == "__main__":
    main()
