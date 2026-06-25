#!/usr/bin/env python3
"""dump/characters/*.md を 0001{name}.md 形式で characters.md 一覧から生成する。"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "dump" / "characters"
CHARACTERS_LIST = ROOT / "dump" / "characters.md"

SECTIONS_TAIL = """
## 簡単な説明文



## 詳細な説明文



## シナジー



## 攻撃属性



## 特異属性 3つ



## 苦手属性 3つ



## 性能



##  各種ステータス（このキャラが使う項目のみ）



## 合成


"""


def load_names_from_characters_md() -> tuple[list[str], list[str]]:
    names: list[str] = []
    started = False
    for line in CHARACTERS_LIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("合計"):
            started = True
            continue
        if not started:
            continue
        if not line.startswith("- "):
            continue
        names.append(line[2:].strip())
    special = [n for n in names if n == "nksy"]
    regular = sorted([n for n in names if n != "nksy"])
    return regular, special


def make_content(id_str: str, name: str) -> str:
    cost = "7" if name == "nksy" else ""
    return (
        f"# {id_str} {name}\n\n"
        f"ID: {id_str}\n"
        f"名前: {name}\n"
        f"コスト: {cost}\n"
        f"{SECTIONS_TAIL}"
    )


def main() -> None:
    regular, special = load_names_from_characters_md()
    if not regular and not special:
        raise SystemExit("characters.md に名前がありません")

    for old_path in CHAR_DIR.glob("*.md"):
        old_path.unlink()

    created = 0
    for idx, name in enumerate(regular, start=1):
        id_str = f"{idx:04d}"
        path = CHAR_DIR / f"{id_str}{name}.md"
        path.write_text(make_content(id_str, name), encoding="utf-8")
        created += 1

    for name in special:
        id_str = f"{len(regular) + len(special):04d}"
        path = CHAR_DIR / f"{id_str}{name}.md"
        path.write_text(make_content(id_str, name), encoding="utf-8")
        created += 1

    print(f"Created {created} files in {CHAR_DIR}")


if __name__ == "__main__":
    main()
