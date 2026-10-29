"""Character / synergy / relic editor.

Writes src/data/characters/*.md and src/data/relics/*.md.
Star scales live in src/data/star_scales.json. A blank ★2+ cell is
★1 × (that row's scale[star] / scale[★1]). Effect rows with no scale
use effectDefault (1, 1.2, 1.5, 1.7). A filled cell is used as written.

Run from the repository root:
    python leveleditor/server.py
Then open http://127.0.0.1:8765/
"""

from __future__ import annotations

import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
CHAR_DIR = ROOT / "src" / "data" / "characters"
RELIC_DIR = ROOT / "src" / "data" / "relics"
BASE_PATH = ROOT / "dump" / "characters_base.md"
SYNERGY_PATH = ROOT / "dump" / "synergys_base.md"
SYNERGY_TEXT_PATH = ROOT / "dump" / "synergys_text.md"
SETTINGS_PATH = ROOT / "src" / "data" / "star_scales.json"
INDEX_PATH = Path(__file__).with_name("index.html")
HOST = "127.0.0.1"
PORT = 8765
RELIC_CATEGORIES = [
    "戦闘中の個体効果",
    "戦闘中の部隊効果",
    "配置・盤面操作",
    "ショップ・通貨・購入",
    "経験値・レベル・出現率",
    "合成・売却・複製",
    "勝敗・連勝・連敗",
    "ラウンドをまたぐ成長",
    "HP、防御の増強、回復",
    "召喚物・盤面装置",
    "シナジー追加",
    "強い利益と明確な代償",
    "クエスト・達成報酬",
    "ラン開始時の戦略決定",
    "確率・選択肢・情報操作",
    "複数レリック間の相互作用",
]

NUMERIC_STATS = [
    "最大HP",
    "攻撃力",
    "防御力",
    "速度",
    "属性耐性",
    "ターゲット優先度",
    "クリティカル率",
    "クリティカルダメージ倍率",
]
RETIRED_STATS = ["属性ダメージ倍率", "属性ダメージ耐性", "攻撃対象数"]
ATTRIBUTES = ["炎", "水", "雷", "土", "氷", "風", "吸収"]
ACTION_RATES = [("攻撃", "attack"), ("バフ/デバフ", "support"), ("ガード", "guard")]
STAR_COUNT = 4
DEFAULT_SCALES = [1.0, 3.5, 10.0, 28.0]
EFFECT_DEFAULT = [1.0, 1.2, 1.5, 1.7]
TOTAL_STATS = ["最大HP", "攻撃力", "速度"]


def _split_list(value: str) -> list[str]:
    if not value.strip():
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def _join_list(values: list[str]) -> str:
    return ", ".join(item.strip() for item in values if item.strip())


def _section_map(text: str) -> tuple[str, dict[str, str]]:
    parts = re.split(r"\n(?=##\s+)", text)
    head = parts[0]
    sections: dict[str, str] = {}
    for part in parts[1:]:
        lines = part.splitlines()
        title = re.sub(r"^##\s+", "", lines[0]).strip()
        body = "\n".join(lines[1:]).strip("\n")
        sections[title] = body
    return head, sections


def _find_section(sections: dict[str, str], prefix: str) -> str:
    for title, body in sections.items():
        if title.startswith(prefix):
            return body
    return ""


def _parse_stats(body: str) -> dict[str, list]:
    stats: dict[str, list] = {}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in {"ステータス", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        if cells[0].startswith("---"):
            continue
        values: list = []
        for cell in cells[1:STAR_COUNT + 1]:
            if cell == "" or cell == "-":
                values.append(None)
            else:
                try:
                    number = float(cell)
                    values.append(int(number) if number.is_integer() else number)
                except ValueError:
                    values.append(None)
        while len(values) < STAR_COUNT:
            values.append(None)
        stats[cells[0]] = values[:STAR_COUNT]
    return stats


def parse_character(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    head, sections = _section_map(text)
    fields: dict[str, str] = {}
    for line in head.splitlines():
        match = re.match(r"^-\s+([^:：]+)[:：]\s*(.*)$", line)
        if match:
            fields[match.group(1).strip()] = match.group(2).strip()
    title = ""
    for line in head.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    char_id = fields.get("ID", path.stem).zfill(3)
    stats = _parse_stats(_find_section(sections, "各種ステータス"))
    for name in NUMERIC_STATS:
        stats.setdefault(name, [None] * STAR_COUNT)
    for name in RETIRED_STATS:
        stats.pop(name, None)
    return {
        "id": char_id,
        "name": fields.get("名前", title),
        "cost": int(fields.get("コスト", "0") or 0),
        "synergies": _split_list(fields.get("シナジー", "")),
        "attack": fields.get("攻撃属性", ""),
        "strong": _split_list(fields.get("得意属性3つ", "")),
        "weak": _split_list(fields.get("苦手属性3つ", "")),
        "brief": _find_section(sections, "簡単な説明文").strip(),
        "detail": _find_section(sections, "詳細な説明文").strip(),
        "flavor": _find_section(sections, "フレーバー").strip(),
        "buffDebuff": _find_section(sections, "バフ/デバフ").strip(),
        "buffValues": _parse_buff_values(_find_section(sections, "効果値")),
        "actionRates": _parse_action_rates(_find_section(sections, "行動割合")),
        "stats": stats,
        "attributeMods": _parse_attribute_mods(_find_section(sections, "属性補正")),
    }


def _optional_number(cell: str):
    if cell == "" or cell == "-":
        return None
    try:
        number = float(cell)
    except ValueError:
        return None
    return int(number) if number.is_integer() else number


def _parse_buff_values(body: str) -> dict[str, list]:
    values = _parse_stats(body)
    values.pop("効果値", None)
    return values


def _render_buff_values(values: dict | None) -> list[str]:
    if not values:
        return []
    lines = [
        "",
        "## 効果値",
        "",
        "バフまたはデバフが変える数値。単位は%。空欄の★2以降は、その行の星倍率を★1に掛ける。星倍率の設定が無い行は、★1を1、★2を1.2、★3を1.5、★4を1.7として掛ける。欄に書いた値は、その星では倍率を使わない。",
        "",
        "| 効果値 | ★1 | ★2 | ★3 | ★4 |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for name, row in values.items():
        row = row or [None] * STAR_COUNT
        cells = [_format_number(row[index] if index < len(row) else None) for index in range(STAR_COUNT)]
        lines.append(f"| {name} | " + " | ".join(cells) + " |")
    return lines


def _parse_action_rates(body: str) -> dict:
    labels = {label: key for label, key in ACTION_RATES}
    rates = {key: None for _, key in ACTION_RATES}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in {"行動", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        key = labels.get(cells[0])
        if key:
            rates[key] = _optional_number(cells[1])
    return rates


def _render_action_rates(rates: dict | None) -> list[str]:
    rates = rates or {}
    lines = [
        "## 行動割合",
        "",
        "| 行動 | 割合 |",
        "| --- | ---: |",
    ]
    for label, key in ACTION_RATES:
        lines.append(f"| {label} | {_format_number(rates.get(key))} |")
    return lines


def _parse_attribute_mods(body: str) -> dict[str, dict]:
    mods = {name: {"damage": None, "resist": None} for name in ATTRIBUTES}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 3 or cells[0] in {"属性", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        mods[cells[0]] = {"damage": _optional_number(cells[1]), "resist": _optional_number(cells[2])}
    return mods


def _format_number(value) -> str:
    if value is None or value == "":
        return ""
    number = float(value)
    if number.is_integer():
        return str(int(number))
    return str(number)


def render_character(data: dict) -> str:
    lines = [
        f"# {data['name']}",
        "",
        f"- ID: {str(data['id']).zfill(3)}",
        f"- 名前: {data['name']}",
        f"- コスト: {int(data['cost'])}",
        f"- シナジー: {_join_list(data.get('synergies', []))}",
        f"- 攻撃属性: {data.get('attack', '')}",
        f"- 得意属性3つ: {_join_list(data.get('strong', []))}",
        f"- 苦手属性3つ: {_join_list(data.get('weak', []))}",
        "",
        "## 簡単な説明文",
        "",
        data.get("brief", "").strip(),
        "",
        "## 詳細な説明文",
        "",
        data.get("detail", "").strip(),
        "",
        "## フレーバー",
        "",
        data.get("flavor", "").strip(),
        "",
        "## バフ/デバフ",
        "",
        data.get("buffDebuff", "").strip(),
        *_render_buff_values(data.get("buffValues")),
        "",
        *_render_action_rates(data.get("actionRates")),
        "",
        "## 各種ステータス",
        "",
        "空欄の★2以降は、そのステータスごとの星倍率を★1に掛けた値として扱う。",
        "",
        "| ステータス | ★1 | ★2 | ★3 | ★4 |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    stats = data.get("stats", {})
    names = list(NUMERIC_STATS)
    for name in stats:
        if name not in names and name not in RETIRED_STATS:
            names.append(name)
    for name in names:
        values = stats.get(name, [None] * STAR_COUNT)
        cells = [_format_number(values[index] if index < len(values) else None) for index in range(STAR_COUNT)]
        lines.append(f"| {name} | " + " | ".join(cells) + " |")
    lines.extend(_render_attribute_mods(data.get("attributeMods", {})))
    return "\n".join(lines).rstrip() + "\n"


def _render_attribute_mods(mods: dict) -> list[str]:
    lines = [
        "",
        "## 属性補正",
        "",
        "空欄は 0%。属性ごとにダメージ倍率とダメージ耐性を持つ。",
        "",
        "| 属性 | ダメージ倍率 | ダメージ耐性 |",
        "| --- | ---: | ---: |",
    ]
    names = list(ATTRIBUTES)
    for name in mods:
        if name not in names:
            names.append(name)
    for name in names:
        row = mods.get(name) or {}
        lines.append(
            f"| {name} | {_format_number(row.get('damage'))} | {_format_number(row.get('resist'))} |"
        )
    return lines


def _existing_synergy_order() -> list[str]:
    if not SYNERGY_PATH.exists():
        return []
    names = []
    for line in SYNERGY_PATH.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or cells[0] in {"シナジー", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        names.append(cells[0])
    return names


def render_synergy_base(characters: list[dict]) -> str:
    groups: dict[str, list[dict]] = {}
    for character in characters:
        for name in character.get("synergies", []):
            if name:
                groups.setdefault(name, []).append(character)
    order = [name for name in _existing_synergy_order() if name in groups]
    for name in sorted(groups):
        if name not in order:
            order.append(name)
    lines = ["# シナジー別", "", "| シナジー | キャラクター |", "| --- | --- |"]
    for name in order:
        members = sorted(groups[name], key=lambda character: character["id"])
        cell = "<br>".join(
            f"- {character['id']} {int(character['cost'])}コスト {character['name']}" for character in members
        )
        lines.append(f"| {name} | {cell} |")
    return "\n".join(lines) + "\n"


TIER_MARK = "### 段階"


def _clean_tier_cell(value) -> str:
    return str(value or "").replace("|", "／").replace("\r", " ").replace("\n", " ").strip()


def _parse_tiers(section: str) -> list[dict]:
    tiers = []
    for line in section.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in {"人数", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        count = _clean_tier_cell(cells[0])
        performance = _clean_tier_cell(cells[1])
        if not count and not performance:
            continue
        tiers.append({"count": count, "performance": performance})
    return tiers


def _split_synergy_body(body: str) -> dict:
    marker = f"\n{TIER_MARK}"
    if body.startswith(TIER_MARK):
        text, section = "", body
    elif marker in body:
        text, section = body.split(marker, 1)
    else:
        text, section = body, ""
    tiers = _parse_tiers(section) if section else []
    return {"text": text.strip(), "tiers": tiers}


def _render_synergy_body(text: str, tiers: list[dict]) -> str:
    body = text.strip()
    cleaned = []
    for tier in tiers or []:
        if not isinstance(tier, dict):
            continue
        count = _clean_tier_cell(tier.get("count", ""))
        performance = _clean_tier_cell(tier.get("performance", ""))
        if not count and not performance:
            continue
        cleaned.append({"count": count, "performance": performance})
    if not cleaned:
        return body
    rows = ["", TIER_MARK, "", "| 人数 | 性能 |", "| --- | --- |"]
    rows.extend(f"| {tier['count']} | {tier['performance']} |" for tier in cleaned)
    table = "\n".join(rows)
    return f"{body}{table}" if body else table.strip()


def load_synergy_texts() -> dict[str, dict]:
    if not SYNERGY_TEXT_PATH.exists():
        return {}
    text = SYNERGY_TEXT_PATH.read_text(encoding="utf-8")
    parts = re.split(r"\n(?=## )", text)
    texts: dict[str, dict] = {}
    for part in parts:
        if not part.startswith("## "):
            continue
        lines = part.splitlines()
        name = lines[0][3:].strip()
        if name:
            texts[name] = _split_synergy_body("\n".join(lines[1:]).strip())
    return texts


def save_synergy_text(name: str, text: str, tiers: list | None = None) -> dict:
    stored = load_synergy_texts()
    body = _render_synergy_body(text, tiers if tiers is not None else [])
    if body:
        stored[name] = _split_synergy_body(body)
    else:
        stored.pop(name, None)
    lines = ["# シナジー性能", ""]
    for key, value in stored.items():
        rendered = _render_synergy_body(value.get("text", ""), value.get("tiers", []))
        lines.extend([f"## {key}", "", rendered, ""])
    SYNERGY_TEXT_PATH.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return stored.get(name, {"text": "", "tiers": []})


def write_synergy_base(characters: list[dict]) -> None:
    text = render_synergy_base(characters)
    if SYNERGY_PATH.exists() and SYNERGY_PATH.read_text(encoding="utf-8") == text:
        return
    SYNERGY_PATH.write_text(text, encoding="utf-8")


def update_base_row(data: dict) -> None:
    if not BASE_PATH.exists():
        return
    text = BASE_PATH.read_text(encoding="utf-8")
    char_id = str(data["id"]).zfill(3)
    row = (
        f"| {char_id} | {data['name']} | {int(data['cost'])} | "
        f"{_join_list(data.get('synergies', []))} | {data.get('attack', '')} | "
        f"{_join_list(data.get('strong', []))} | {_join_list(data.get('weak', []))} |"
    )
    pattern = re.compile(rf"^\| {re.escape(char_id)} \|.*$", re.M)
    if pattern.search(text):
        text = pattern.sub(row, text, count=1)
    else:
        text = text.rstrip() + "\n" + row + "\n"
    BASE_PATH.write_text(text, encoding="utf-8")


def load_characters() -> list[dict]:
    characters = []
    for path in sorted(CHAR_DIR.glob("*.md")):
        characters.append(parse_character(path))
    return characters


def _parse_yes_no(value: str, default: bool = True) -> bool:
    text = (value or "").strip()
    if not text:
        return default
    if text in {"はい", "true", "True", "1", "yes", "YES"}:
        return True
    if text in {"いいえ", "false", "False", "0", "no", "NO"}:
        return False
    return default


def _yes_no(value: bool) -> str:
    return "はい" if value else "いいえ"


def _parse_relic_effects(body: str) -> dict[str, float | int | None]:
    effects: dict[str, float | int | None] = {}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in {"効果値", "---"} or set(cells[0]) <= {"-", ":"}:
            continue
        effects[cells[0]] = _optional_number(cells[1])
    return effects


def _render_relic_effects(effects: dict | None) -> list[str]:
    if not effects:
        return []
    lines = [
        "",
        "## 効果値",
        "",
        "レリックが変える数値。単位は欄による。",
        "",
        "| 効果値 | 値 |",
        "| --- | ---: |",
    ]
    for name, value in effects.items():
        lines.append(f"| {name} | {_format_number(value)} |")
    return lines


def parse_relic(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    head, sections = _section_map(text)
    fields: dict[str, str] = {}
    for line in head.splitlines():
        match = re.match(r"^-\s+([^:：]+)[:：]\s*(.*)$", line)
        if match:
            fields[match.group(1).strip()] = match.group(2).strip()
    title = ""
    for line in head.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    relic_id = fields.get("ID", path.stem).zfill(3)
    return {
        "id": relic_id,
        "name": fields.get("名前", title),
        "category": fields.get("分類", ""),
        "equipable": _parse_yes_no(fields.get("装備可能", "はい")),
        "combinable": _parse_yes_no(fields.get("合成可能", "はい")),
        "brief": _find_section(sections, "簡単な説明文").strip(),
        "detail": _find_section(sections, "詳細な説明文").strip(),
        "effects": _parse_relic_effects(_find_section(sections, "効果値")),
    }


def render_relic(data: dict) -> str:
    name = (data.get("name") or "").strip()
    lines = [
        f"# {name}",
        "",
        f"- ID: {str(data['id']).zfill(3)}",
        f"- 名前: {name}",
        f"- 分類: {data.get('category', '')}",
        f"- 装備可能: {_yes_no(bool(data.get('equipable', True)))}",
        f"- 合成可能: {_yes_no(bool(data.get('combinable', True)))}",
        "",
        "## 簡単な説明文",
        "",
        data.get("brief", "").strip(),
        "",
        "## 詳細な説明文",
        "",
        data.get("detail", "").strip(),
        *_render_relic_effects(data.get("effects")),
    ]
    return "\n".join(lines).rstrip() + "\n"


def load_relics() -> list[dict]:
    relics = []
    if not RELIC_DIR.exists():
        return relics
    for path in sorted(RELIC_DIR.glob("*.md")):
        relics.append(parse_relic(path))
    return relics


def _scale_row(values, fallback: list[float]) -> list[float]:
    source = values if isinstance(values, list) else fallback
    row = []
    for index in range(STAR_COUNT):
        try:
            row.append(float(source[index]))
        except (TypeError, ValueError, IndexError):
            row.append(float(fallback[index] if index < len(fallback) else fallback[-1]))
    return row


def _clean_standards(raw) -> dict[str, dict]:
    cleaned: dict[str, dict] = {}
    if not isinstance(raw, dict):
        return cleaned
    for cost in range(1, 8):
        row = raw.get(str(cost), raw.get(cost)) or {}
        if not isinstance(row, dict):
            continue
        values = {}
        for name, value in row.items():
            if str(name) in RETIRED_STATS or value in (None, ""):
                continue
            try:
                number = float(value)
            except (TypeError, ValueError):
                continue
            values[str(name)] = int(number) if number.is_integer() else number
        if values:
            cleaned[str(cost)] = values
    return cleaned


def load_settings() -> dict:
    data = {}
    if SETTINGS_PATH.exists():
        data = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    raw = data.get("scales", DEFAULT_SCALES)
    if isinstance(raw, list):
        base = _scale_row(raw, DEFAULT_SCALES)
        scales = {name: list(base) for name in NUMERIC_STATS}
    elif isinstance(raw, dict):
        fallback = list(DEFAULT_SCALES)
        for value in raw.values():
            if isinstance(value, list) and value:
                fallback = _scale_row(value, DEFAULT_SCALES)
                break
        scales = {name: _scale_row(raw.get(name), fallback) for name in NUMERIC_STATS}
        for name, value in raw.items():
            if name not in scales and name not in RETIRED_STATS:
                scales[name] = _scale_row(value, fallback)
    else:
        scales = {name: list(DEFAULT_SCALES) for name in NUMERIC_STATS}
    effect = _scale_row(data.get("effectDefault"), EFFECT_DEFAULT)
    return {
        "scales": scales,
        "standards": _clean_standards(data.get("standards", {})),
        "effectDefault": effect,
    }


def save_settings(data: dict) -> dict:
    settings = load_settings()
    if "scales" in data and isinstance(data["scales"], dict):
        fallback = next(iter(settings["scales"].values()))
        merged = dict(settings["scales"])
        for name, value in data["scales"].items():
            if name in RETIRED_STATS:
                continue
            merged[str(name)] = _scale_row(value, fallback)
        for name in NUMERIC_STATS:
            merged.setdefault(name, _scale_row(None, fallback))
        settings["scales"] = merged
    if "standards" in data:
        settings["standards"] = _clean_standards(data["standards"])
    if "effectDefault" in data:
        settings["effectDefault"] = _scale_row(data.get("effectDefault"), EFFECT_DEFAULT)
    SETTINGS_PATH.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return settings


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802
        path = unquote(self.path.split("?", 1)[0])
        if path in {"/", "/index.html"}:
            self._send(200, INDEX_PATH.read_bytes(), "text/html; charset=utf-8")
            return
        if path == "/api/characters":
            payload = {
                "characters": load_characters(),
                "numericStats": NUMERIC_STATS,
                "totalStats": TOTAL_STATS,
                "attributes": ATTRIBUTES,
            }
            self._send(200, json.dumps(payload, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        if path == "/api/settings":
            self._send(200, json.dumps(load_settings(), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        if path == "/api/synergy-text":
            self._send(200, json.dumps(load_synergy_texts(), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        if path == "/api/relics":
            payload = {
                "relics": load_relics(),
                "categories": RELIC_CATEGORIES,
            }
            self._send(200, json.dumps(payload, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        self._send(404, b"not found", "text/plain; charset=utf-8")

    def do_PUT(self) -> None:  # noqa: N802
        path = unquote(self.path.split("?", 1)[0])
        try:
            data = self._read_json()
        except json.JSONDecodeError:
            self._send(400, b"invalid json", "text/plain; charset=utf-8")
            return
        if path == "/api/settings":
            saved = save_settings(data)
            self._send(200, json.dumps(saved, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        if path == "/api/synergy-text":
            name = str(data.get("name", "")).strip()
            if not name or any(char in name for char in "\r\n#"):
                self._send(400, b"invalid name", "text/plain; charset=utf-8")
                return
            saved = save_synergy_text(name, str(data.get("text", "")), data.get("tiers") or [])
            self._send(200, json.dumps({"name": name, **saved}, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        relic_match = re.fullmatch(r"/api/relics/(\d+)", path)
        if relic_match:
            relic_id = relic_match.group(1).zfill(3)
            data["id"] = relic_id
            RELIC_DIR.mkdir(parents=True, exist_ok=True)
            (RELIC_DIR / f"{relic_id}.md").write_text(render_relic(data), encoding="utf-8")
            self._send(200, json.dumps(parse_relic(RELIC_DIR / f"{relic_id}.md"), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        match = re.fullmatch(r"/api/characters/(\d+)", path)
        if not match:
            self._send(404, b"not found", "text/plain; charset=utf-8")
            return
        char_id = match.group(1).zfill(3)
        data["id"] = char_id
        CHAR_DIR.mkdir(parents=True, exist_ok=True)
        (CHAR_DIR / f"{char_id}.md").write_text(render_character(data), encoding="utf-8")
        update_base_row(data)
        write_synergy_base(load_characters())
        self._send(200, json.dumps(parse_character(CHAR_DIR / f"{char_id}.md"), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        print(f"[{self.log_date_time_string()}] {format % args}")


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"editor: http://{HOST}:{PORT}/")
    server.serve_forever()


if __name__ == "__main__":
    main()
