#!/usr/bin/env python3
"""character.md から characters2.md の表を再構築する（ランダム割当は変更しない）。"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "src" / "characters"
CHARACTERS2 = ROOT / "dump" / "characters2.md"


def parse_sheet(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    m_id = re.search(r"^ID:\s*(\S+)", text, re.M)
    m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
    m_cost = re.search(r"^コスト:\s*(.+)$", text, re.M)
    m_role = re.search(r"^役割:\s*(.+)$", text, re.M)
    if not m_id or not m_name:
        return None

    attack = ""
    m_attack = re.search(r"^## 攻撃属性\s*\n+([^\n#]+)", text, re.M)
    if m_attack:
        attack = m_attack.group(1).strip()

    strong: list[str] = []
    weak: list[str] = []
    synergies: list[str] = []
    section = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "## 特異属性 3つ":
            section = "strong"
            continue
        if stripped == "## 苦手属性 3つ":
            section = "weak"
            continue
        if stripped == "## シナジー":
            section = "syn"
            continue
        if stripped.startswith("## "):
            section = None
            continue
        if stripped.startswith("- ") and section:
            item = stripped[2:].strip()
            if section == "strong":
                strong.append(item)
            elif section == "weak":
                weak.append(item)
            elif section == "syn":
                synergies.append(item)

    cost_raw = m_cost.group(1).strip() if m_cost else "0"
    try:
        cost = int(cost_raw)
    except ValueError:
        cost = 0

    return {
        "id": m_id.group(1).strip(),
        "name": m_name.group(1).strip(),
        "cost": cost,
        "role": m_role.group(1).strip() if m_role else "",
        "attack": attack,
        "strong": strong,
        "weak": weak,
        "synergies": synergies,
    }


def main() -> None:
    rows: list[dict] = []
    for sheet in CHAR_DIR.glob("*/character.md"):
        row = parse_sheet(sheet)
        if row:
            rows.append(row)

    lines = [
        "# キャラクター(小)詳細",
        "",
        "（`scripts/refresh_characters2_table.py` で character.md から再構築）",
        "",
        "属性・元素シナジー: 炎・水・雷・土・氷・風・吸収（synergys.md 先頭7つ）",
        "",
    ]
    header = "| ID | 名前 | コスト | 役割 | 攻撃属性 | 得意属性 | 苦手属性 | シナジー |"
    sep = "| --- | --- | ---: | --- | --- | --- | --- | --- |"

    by_cost: dict[int, list[dict]] = {}
    for row in rows:
        by_cost.setdefault(row["cost"], []).append(row)

    for cost in sorted(by_cost.keys()):
        lines.append(f"## コスト {cost}")
        lines.append("")
        lines.append(header)
        lines.append(sep)
        for row in sorted(by_cost[cost], key=lambda r: r["id"]):
            strong = "・".join(row["strong"])
            weak = "・".join(row["weak"])
            syn = "・".join(row["synergies"])
            lines.append(
                f"| {row['id']} | {row['name']} | {row['cost']} | {row['role']} | "
                f"{row['attack']} | {strong} | {weak} | {syn} |"
            )
        lines.append("")

    CHARACTERS2.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {CHARACTERS2} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
