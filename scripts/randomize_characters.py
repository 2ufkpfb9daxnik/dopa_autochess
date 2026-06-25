#!/usr/bin/env python3
"""characters2.md と src/characters/*/character.md にランダムな役割・属性・コスト・シナジーを割り当てる。

属性・シナジー（元素）は synergys.md 先頭7つ（炎水雷土氷風吸収）。
煉獄・大滝などは技名用（本スクリプトでは属性に使わない）。
"""

import re
import random
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "src" / "characters"
CHARACTERS2 = ROOT / "dump" / "characters2.md"
CHARACTERS_LIST = ROOT / "dump" / "characters.md"
SYNERGYS = ROOT / "dump" / "synergys.md"

SPECIAL_NAME = "nksy"

# シナジー・攻撃属性・得意/苦手で使う元素
ELEMENTS = ["炎", "水", "雷", "土", "氷", "風", "吸収"]
PHYSICAL_ATTR = "物理"

# 役割配分（魔法は元素ごと。属性名と一致）
ROLE_TEMPLATE: list[tuple[str, int]] = [
    ("物理攻撃", 10),
    ("防御", 10),
    ("炎", 5),
    ("水", 5),
    ("雷", 5),
    ("土", 5),
    ("氷", 5),
    ("風", 5),
    ("吸収", 5),
    ("回復", 10),
    ("バフ", 10),
    ("デバフ", 10),
]

# 1と4は稀、2〜3が多め
SYNERGY_COUNT_WEIGHTS = [(1, 0.08), (2, 0.45), (3, 0.38), (4, 0.05)]
COST_RANGE = range(1, 8)
MAX_SYNERGIES_PER_CHAR = 4
MIN_SYNERGIES_PER_CHAR = 1


def parse_names_from_bullets(path: Path) -> list[str]:
    names: list[str] = []
    started = False
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("合計"):
            started = True
            continue
        if not started:
            continue
        if not line.startswith("- "):
            continue
        candidate = line[2:].strip()
        if candidate:
            names.append(candidate)
    return names


def load_character_names() -> list[str]:
    names = parse_names_from_bullets(CHARACTERS_LIST)
    special = [n for n in names if n == SPECIAL_NAME]
    regular = sorted([n for n in names if n != SPECIAL_NAME])
    return regular + special


def parse_synergies() -> list[str]:
    names: list[str] = []
    for line in SYNERGYS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("- "):
            names.append(line[2:].strip())
    return names


def scale_role_pool(n: int, rng: random.Random) -> list[str]:
    base_total = sum(c for _, c in ROLE_TEMPLATE)
    pool: list[str] = []
    remainders: list[tuple[float, str]] = []
    for label, count in ROLE_TEMPLATE:
        exact = count * n / base_total
        whole = int(exact)
        pool.extend([label] * whole)
        remainders.append((exact - whole, label))
    remainders.sort(key=lambda x: -x[0])
    while len(pool) < n:
        pool.append(remainders[len(pool) % len(remainders)][1])
    pool = pool[:n]
    rng.shuffle(pool)
    return pool


def role_display(role: str) -> str:
    if role in ELEMENTS:
        return f"魔法攻撃({role})"
    return role


def attack_attribute(role: str) -> str:
    if role == "物理攻撃":
        return PHYSICAL_ATTR
    if role in ELEMENTS:
        return role
    return ""


def pick_synergy_count(rng: random.Random) -> int:
    roll = rng.random()
    acc = 0.0
    for count, weight in SYNERGY_COUNT_WEIGHTS:
        acc += weight
        if roll <= acc:
            return min(count, MAX_SYNERGIES_PER_CHAR)
    return min(3, MAX_SYNERGIES_PER_CHAR)


def assign_synergies(
    names: list[str],
    synergies: list[str],
    rng: random.Random,
    min_per: int = 5,
    max_per_char: int = MAX_SYNERGIES_PER_CHAR,
) -> dict[str, list[str]]:
    char_syn: dict[str, list[str]] = {name: [] for name in names}
    syn_count: dict[str, int] = {s: 0 for s in synergies}
    min_phase_cap = min(3, max_per_char)

    for syn in synergies:
        candidates = names.copy()
        rng.shuffle(candidates)
        for name in candidates:
            if syn_count[syn] >= min_per:
                break
            if len(char_syn[name]) >= min_phase_cap:
                continue
            if syn in char_syn[name]:
                continue
            char_syn[name].append(syn)
            syn_count[syn] += 1
        if syn_count[syn] < min_per:
            raise RuntimeError(f"シナジー「{syn}」に {min_per} 体割り当てられませんでした")

    # 全キャラ最低1シナジー
    for name in names:
        if char_syn[name]:
            continue
        available = [s for s in synergies if s not in char_syn[name]]
        rng.shuffle(available)
        if not available:
            raise RuntimeError(f"「{name}」にシナジーを割り当てられませんでした")
        pick = available[0]
        char_syn[name].append(pick)
        syn_count[pick] += 1

    # 4シナジーは全体の約5%だけ（1シナジーと同程度に稀）
    four_cap = max(1, round(len(names) * 0.05))
    candidates_for_4 = [n for n in names if len(char_syn[n]) == 3]
    rng.shuffle(candidates_for_4)
    four_chars = set(candidates_for_4[:four_cap])
    for name in four_chars:
        available = [s for s in synergies if s not in char_syn[name]]
        if not available:
            continue
        pick = rng.choice(available)
        char_syn[name].append(pick)
        syn_count[pick] += 1

    # 1シナジーは全体の約5%だけに抑え、残りは2へ
    one_cap = max(1, round(len(names) * 0.05))
    with_one = [n for n in names if len(char_syn[n]) == 1]
    rng.shuffle(with_one)
    keep_one = set(with_one[:one_cap])
    for name in with_one:
        if name in keep_one:
            continue
        if len(char_syn[name]) >= 3:
            continue
        available = [s for s in synergies if s not in char_syn[name]]
        if not available:
            continue
        pick = rng.choice(available)
        char_syn[name].append(pick)
        syn_count[pick] += 1

    return char_syn


def split_attributes(attack_attr: str, rng: random.Random) -> tuple[list[str], list[str]]:
    if attack_attr == PHYSICAL_ATTR:
        pool = ELEMENTS.copy()
    elif attack_attr in ELEMENTS:
        pool = [e for e in ELEMENTS if e != attack_attr]
    else:
        pool = ELEMENTS.copy()

    rng.shuffle(pool)
    if len(pool) >= 6:
        return pool[:3], pool[3:6]
    mid = len(pool) // 2
    return pool[:mid], pool[mid:]


def assign_costs(names: list[str], rng: random.Random) -> dict[str, int]:
    costs: dict[str, int] = {}
    for name in names:
        if name == SPECIAL_NAME:
            costs[name] = 7
        else:
            costs[name] = rng.choice(list(COST_RANGE))
    return costs


def assign_roles(names: list[str], rng: random.Random) -> dict[str, str]:
    regular = [n for n in names if n != SPECIAL_NAME]
    special = [n for n in names if n == SPECIAL_NAME]
    role_labels = [label for label, _ in ROLE_TEMPLATE]

    role_pool = scale_role_pool(len(regular), rng)
    roles = {name: role_pool[i] for i, name in enumerate(regular)}
    for name in special:
        roles[name] = "吸収"
    return roles


def extract_flavor_block(text: str) -> str:
    match = re.search(r"^## フレーバー\s*\n.*?(?=^## |\Z)", text, re.M | re.S)
    if not match:
        return ""
    return match.group(0).rstrip() + "\n\n"


def build_name_to_id() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for sheet in CHAR_DIR.glob("*/character.md"):
        text = sheet.read_text(encoding="utf-8")
        m_id = re.search(r"^ID:\s*(\S+)", text, re.M)
        m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
        if m_id and m_name:
            mapping[m_name.group(1).strip()] = m_id.group(1).strip()
    return mapping


    for sheet in CHAR_DIR.glob("*/character.md"):
        text = sheet.read_text(encoding="utf-8")
        m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
        if m_name and m_name.group(1).strip() == name:
            return sheet
    return None


def find_character_file(name: str) -> Path | None:
    for sheet in CHAR_DIR.glob("*/character.md"):
        text = sheet.read_text(encoding="utf-8")
        m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
        if m_name and m_name.group(1).strip() == name:
            return sheet
    return None


def update_character_sheet(
    path: Path,
    cost: int,
    role: str,
    attack_attr: str,
    strong: list[str],
    weak: list[str],
    synergies: list[str],
) -> None:
    text = path.read_text(encoding="utf-8")
    m_id = re.search(r"^ID:\s*(\S+)", text, re.M)
    m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
    id_str = m_id.group(1) if m_id else ""
    name_str = m_name.group(1).strip() if m_name else path.stem[4:]

    strong_text = "\n".join(f"- {a}" for a in strong) if strong else ""
    weak_text = "\n".join(f"- {a}" for a in weak) if weak else ""
    syn_text = "\n".join(f"- {s}" for s in synergies) if synergies else ""
    flavor_block = extract_flavor_block(text)

    detail_section = "## 詳細な説明文\n\n"
    if flavor_block:
        detail_section += "\n" + flavor_block

    body = f"""# {id_str} {name_str}

ID: {id_str}
名前: {name_str}
コスト: {cost}

## 簡単な説明文

役割: {role_display(role)}

{detail_section}## シナジー

{syn_text}

## 攻撃属性

{attack_attr}

## 特異属性 3つ

{strong_text}

## 苦手属性 3つ

{weak_text}

## 性能



##  各種ステータス（このキャラが使う項目のみ）



## 合成


"""
    path.write_text(body, encoding="utf-8")


def write_characters2(
    names: list[str],
    costs: dict[str, int],
    roles: dict[str, str],
    attacks: dict[str, str],
    strong_map: dict[str, list[str]],
    weak_map: dict[str, list[str]],
    syn_map: dict[str, list[str]],
    seed: int,
) -> None:
    name_to_id = build_name_to_id()
    lines = [
        "# キャラクター(小)詳細",
        "",
        f"（`scripts/randomize_characters.py` で生成・seed={seed}）",
        "",
        "属性・元素シナジー: 炎・水・雷・土・氷・風・吸収（synergys.md 先頭7つ）",
        "",
    ]
    table_header = (
        "| ID | 名前 | コスト | 役割 | 攻撃属性 | 得意属性 | 苦手属性 | シナジー |"
    )
    table_sep = "| --- | --- | ---: | --- | --- | --- | --- | --- |"

    by_cost: dict[int, list[str]] = {}
    for name in names:
        by_cost.setdefault(costs[name], []).append(name)

    for cost in sorted(by_cost.keys()):
        lines.append(f"## コスト {cost}")
        lines.append("")
        lines.append(table_header)
        lines.append(table_sep)
        for name in sorted(by_cost[cost], key=lambda n: name_to_id.get(n, n)):
            char_id = name_to_id.get(name, "")
            strong = "・".join(strong_map[name]) if strong_map[name] else ""
            weak = "・".join(weak_map[name]) if weak_map[name] else ""
            syn = "・".join(syn_map[name]) if syn_map[name] else ""
            lines.append(
                f"| {char_id} | {name} | {costs[name]} | {role_display(roles[name])} | "
                f"{attacks[name]} | {strong} | {weak} | {syn} |"
            )
        lines.append("")

    CHARACTERS2.write_text("\n".join(lines), encoding="utf-8")


def estimate_min_characters(
    synergy_count: int,
    min_per_synergy: int = 5,
    avg_synergies_per_char: float = 3.0,
    max_synergies_per_char: int = 4,
) -> int:
    """共通シナジー（各 min 体）を満たす最低キャラ数の目安。"""
    min_slots = synergy_count * min_per_synergy
    by_avg = int(-(-min_slots // int(avg_synergies_per_char)))  # ceil division
    by_max = int(-(-min_slots // max_synergies_per_char))
    return max(by_avg, by_max)


def main() -> None:
    seed = 42
    rng = random.Random(seed)

    names = load_character_names()
    synergies = parse_synergies()
    if not names:
        raise SystemExit("characters.md に名前がありません")
    if not synergies:
        raise SystemExit("synergys.md にシナジーがありません")

    roles = assign_roles(names, rng)
    costs = assign_costs(names, rng)
    attacks = {name: attack_attribute(roles[name]) for name in names}

    strong_map: dict[str, list[str]] = {}
    weak_map: dict[str, list[str]] = {}
    for name in names:
        strong, weak = split_attributes(attacks[name], rng)
        strong_map[name] = strong
        weak_map[name] = weak

    syn_map = assign_synergies(names, synergies, rng)

    write_characters2(
        names, costs, roles, attacks, strong_map, weak_map, syn_map, seed
    )

    updated = 0
    for name in names:
        path = find_character_file(name)
        if path is None:
            continue
        update_character_sheet(
            path,
            costs[name],
            roles[name],
            attacks[name],
            strong_map[name],
            weak_map[name],
            syn_map[name],
        )
        updated += 1

    per_char = Counter(len(syn_map[n]) for n in names)
    total_slots = sum(k * v for k, v in per_char.items())
    min_slots = len(synergies) * 5

    print(f"characters2.md: {len(names)} 体")
    print(f"個別シート更新: {updated} 件")
    print(f"シナジー種類: {len(synergies)}（各最低5体）")
    print(f"シナジー枠合計: {total_slots}（最低必要 {min_slots}）")
    print(f"1体あたりシナジー数: {dict(sorted(per_char.items()))}")
    print(
        f"目安: 平均3枠なら {estimate_min_characters(len(synergies), 5, 3.0)} 体以上、"
        f"平均2.5枠なら {estimate_min_characters(len(synergies), 5, 2.5)} 体以上"
    )


if __name__ == "__main__":
    main()
