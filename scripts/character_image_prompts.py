#!/usr/bin/env python3
"""キャラクターイラスト用プロンプトを生成する（画像生成バッチ用）。"""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "src" / "characters"
OUT_JSON = ROOT / "scripts" / "character_image_prompts.json"
SPECIAL_SKIP_IMAGE = "0121"

VISUAL_HOOKS = [
    "oversized ornate pauldrons shaped like lion heads",
    "long asymmetrical white hair with a single red streak",
    "carries a crystal staff topped with a floating geometric orb",
    "wears a hooded cloak covered in constellation embroidery",
    "distinctive mechanical wing backpack with brass gears",
    "one-eyed scar across the left cheek, eyepatch with rune",
    "twin braids wrapped in golden ribbons and bells",
    "armor made of layered blue ice plates",
    "giant flower-shaped hat with petals that glow",
    "chain whip coiled around both arms",
    "mask covering lower face, ornate horned helmet",
    "carries a book chained to wrist, pages fluttering",
    "coral-shaped shoulder armor with seafoam green trim",
    "spiked gauntlets with magma cracks glowing orange",
    "cape made of layered feather scales in teal gradient",
    "antler crown with hanging lantern charms",
    "dual daggers with mismatched blade shapes",
    "round shield painted as a smiling sun emblem",
    "serpent-shaped brooch that seems alive",
    "boots with spring-loaded stilts",
    "hair shaped like sharp lightning bolts standing up",
    "robe hem dissolving into swirling wind ribbons",
    "stone golem fist gauntlet on right arm only",
    "bubble-like glass armor spheres on shoulders",
    "sash made of woven thundercloud fabric",
    "goggles with multiple colored lenses stacked",
    "pet small fox spirit peeking from hood",
    "armor engraved with musical notation lines",
    "giant scissors used as off-hand weapon",
    "crown of frozen thorns with soft blue glow",
]

STYLE = (
    "Square fantasy autochess character portrait illustration, full character visible, "
    "bold readable silhouette, vibrant colors, mobile game hero icon style, "
    "high detail, sharp focus, single character centered, simple gradient background, "
    "no text, no watermark, no UI frame, 1024x1024"
)


def parse_character(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    char_id = path.parent.name
    name = ""
    cost = ""
    role = ""
    attack = ""
    m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
    m_cost = re.search(r"^コスト:\s*(.+)$", text, re.M)
    m_role = re.search(r"^役割:\s*(.+)$", text, re.M)
    m_attack = re.search(r"^## 攻撃属性\s*\n+([^\n#]+)", text, re.M)
    if m_name:
        name = m_name.group(1).strip()
    if m_cost:
        cost = m_cost.group(1).strip()
    if m_role:
        role = m_role.group(1).strip()
    attack = ""
    if m_attack:
        attack = m_attack.group(1).strip()
    if not attack and role:
        m_elem = re.search(r"魔法攻撃\(([^)]+)\)", role)
        if m_elem:
            attack = m_elem.group(1).strip()
    return {
        "id": char_id,
        "name": name,
        "cost": cost,
        "role": role,
        "attack": attack,
    }


def element_theme(attack: str) -> str:
    themes = {
        "炎": "fire orange red gold color palette, warm glow",
        "水": "water blue cyan color palette, fluid accents",
        "雷": "lightning yellow purple electric accents",
        "土": "earth brown amber stone armor accents",
        "氷": "ice pale blue white frost crystal accents",
        "風": "wind yellow-green lime airy flowing fabric",
        "吸収": "absorption dark purple void mystical aura",
        "物理": "steel gray martial weapon focus, neutral metallic tones",
    }
    return themes.get(attack, "balanced fantasy palette")


def pick_hook(char_id: str, name: str) -> str:
    digest = hashlib.sha256(f"{char_id}:{name}".encode()).hexdigest()
    idx = int(digest[:8], 16) % len(VISUAL_HOOKS)
    return VISUAL_HOOKS[idx]


def build_prompt(meta: dict) -> str:
    hook = pick_hook(meta["id"], meta["name"])
    theme = element_theme(meta["attack"])
    role = meta["role"] or "adventurer"
    return (
        f"Original fantasy character '{meta['name']}', {role}, "
        f"{theme}. Unique visual identity: {hook}. "
        f"Must look completely different from other game characters. "
        f"{STYLE}"
    )


def main() -> None:
    entries: list[dict] = []
    for char_dir in sorted(CHAR_DIR.iterdir()):
        if not char_dir.is_dir():
            continue
        if not re.fullmatch(r"\d{4}", char_dir.name):
            continue
        sheet = char_dir / "character.md"
        if not sheet.is_file():
            continue
        meta = parse_character(sheet)
        meta["image_path"] = f"src/characters/{meta['id']}/{meta['id']}.png"
        meta["skip_image"] = meta["id"] == SPECIAL_SKIP_IMAGE
        meta["prompt"] = build_prompt(meta)
        entries.append(meta)

    OUT_JSON.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    to_gen = [e for e in entries if not e["skip_image"]]
    print(f"Wrote {len(entries)} entries to {OUT_JSON}")
    print(f"Images to generate: {len(to_gen)} (skip {SPECIAL_SKIP_IMAGE})")


if __name__ == "__main__":
    main()
