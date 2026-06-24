#!/usr/bin/env python3
"""dump/characters/*.md を 0001nksy.md 形式に統一する。"""

import re
from pathlib import Path

CHAR_DIR = Path(__file__).resolve().parent.parent / "dump" / "characters"

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


def name_from_stem(stem: str) -> str:
    m = re.match(r"^\d{4}(.+)$", stem)
    return m.group(1) if m else stem


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
    files = sorted(CHAR_DIR.glob("*.md"), key=lambda p: name_from_stem(p.stem))
    entries: list[tuple[str, Path]] = []
    for path in files:
        entries.append((name_from_stem(path.stem), path))

    entries.sort(key=lambda x: x[0])

    new_contents: dict[Path, str] = {}
    for idx, (name, _old_path) in enumerate(entries, start=1):
        id_str = f"{idx:04d}"
        new_path = CHAR_DIR / f"{id_str}{name}.md"
        new_contents[new_path] = make_content(id_str, name)

    old_paths = {p for _, p in entries}
    new_paths = set(new_contents.keys())
    for old_path in old_paths - new_paths:
        old_path.unlink()

    for new_path, content in new_contents.items():
        new_path.write_text(content, encoding="utf-8")

    print(f"Formatted {len(new_contents)} files in {CHAR_DIR}")


if __name__ == "__main__":
    main()
