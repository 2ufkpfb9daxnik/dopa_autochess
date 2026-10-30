# -*- coding: utf-8 -*-
"""Rewrite relic brief/detail text to state values directly."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "data" / "relics"

EFFECT_TABLE_RE = re.compile(
    r"## 効果値\n\n.*?\n\| 効果値 \| 値 \|\n\| --- \| ---: \|\n((?:\|.+\n?)+)",
    re.S,
)
DETAIL_RE = re.compile(r"(## 詳細な説明文\n\n)(.+?)(\n\n## )", re.S)
BRIEF_RE = re.compile(r"(## 簡単な説明文\n\n)(.+?)(\n\n## )", re.S)

# Keys may contain の (速度の上昇, 回復の回数, …)
PAIR_RE = re.compile(
    r"効果値の(?P<key>.+?)の欄の(?P<rest>[^。]+)である。"
    r"(?P<num>\d+(?:\.\d+)?)(?P<pct>%?)である。"
    r"(?:この欄は%ではない。|この欄は%である。)?"
)

# Broken mid-state from earlier pass: 効果値のXの欄の値はNまでである
BROKEN_LIMIT_RE = re.compile(
    r"効果値の(?P<key>.+?)の欄の値は(?P<num>\d+(?:\.\d+)?)までである。"
)

INLINE_RE = re.compile(r"効果値の(?P<key>.+?)の欄の(?P<rest>[^。、]+)")
PCT_NOTE_RE = re.compile(r"この欄は%ではない。|この欄は%である。")
DUAL_KEYS_RE = re.compile(
    r"効果値の(?P<k1>.+?)の欄と(?P<k2>.+?)の欄の値である。"
    r"(?:どちらも|どちらも同じく)?(?P<num>\d+(?:\.\d+)?)(?P<pct>%?)である。"
    r"(?:この欄は%ではない。|この欄は%である。)?"
)

PERCENT_KEYS = {
    "与ダメージ",
    "受けるダメージ",
    "貫通率",
    "属性耐性",
    "回復",
    "次の与ダメージ",
    "最初の与ダメージ",
    "瀕死の与ダメージ",
    "属性の与ダメージ",
    "炎の与ダメージ",
    "水の与ダメージ",
    "雷の与ダメージ",
    "土の与ダメージ",
    "氷の与ダメージ",
    "風の与ダメージ",
    "吸収の与ダメージ",
}


def parse_effects(text: str) -> dict[str, float]:
    m = EFFECT_TABLE_RE.search(text)
    if not m:
        return {}
    effects: dict[str, float] = {}
    for line in m.group(1).splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|") if c.strip() != ""]
        if len(cells) < 2:
            continue
        key, value = cells[0], cells[1]
        if key in ("効果値", "---") or value in ("値", "---:"):
            continue
        try:
            effects[key] = float(value)
        except ValueError:
            continue
    return effects


def fmt_num(value: float) -> str:
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    return "%g" % value


def is_percent_key(key: str, rest: str = "", pct_mark: str = "") -> bool:
    if pct_mark == "%":
        return True
    if "割合" in rest:
        return True
    if key in PERCENT_KEYS or key.endswith("の与ダメージ"):
        return True
    if key == "閾値" and "ゴールド" not in key:
        # many thresholds are % of HP; gold thresholds are absolute — handled by context
        return False
    return False


def token_for(key: str, rest: str, num: str, pct: str) -> str:
    if not num:
        return ""
    if is_percent_key(key, rest, pct):
        return num if num.endswith("%") else f"{num}%"
    return num


def rewrite_pair(m: re.Match) -> str:
    key = m.group("key")
    rest = m.group("rest")
    token = token_for(key, rest, m.group("num"), m.group("pct"))
    if rest in ("値", "割合"):
        return f"{token}である。"
    if rest.endswith("まで"):
        return f"{token}までである。"
    if "以下のときだけ" in rest:
        return f"{token}以下のときだけである。"
    if rest.endswith("倍"):
        return f"{token}倍である。"
    if "を掛けた数" in rest:
        return f"{token}を掛けた数である。"
    if "回数で獲得する" in rest:
        return f"{token}回で獲得する。"
    if "回数まで" in rest:
        return f"{token}回までである。"
    if "回数だけ入る" in rest:
        return f"{token}回入る。"
    if "回数である" in rest:
        return f"{token}回である。"
    return f"{token}である。"


def rewrite_inline(m: re.Match, effects: dict[str, float]) -> str:
    key = m.group("key")
    rest = m.group("rest")
    if "と" in key and "欄" in key:
        return m.group(0)
    if key not in effects:
        return m.group(0)
    num = fmt_num(effects[key])
    token = token_for(key, rest, num, "")
    mapping = {
        "値だけ多い": f"{token}だけ多い",
        "値だけ多いものとして数える": f"{token}だけ多いものとして数える",
        "値だけ入る": f"{token}だけ入る",
        "値だけ入り": f"{token}だけ入り",
        "値だけ安い": f"{token}だけ安い",
        "値だけ少ない": f"{token}だけ少ない",
        "値だけ減る": f"{token}だけ減る",
        "値だけ増える": f"{token}だけ増える",
        "値だけ上がる": f"{token}だけ上がる",
        "値だけ高い": f"{token}だけ高い",
        "値だけ低い表と同じである": f"{token}だけ低い表と同じである",
        "値だけ回復する": f"{token}だけ回復する",
        "値だけ獲得する": f"{token}だけ獲得する",
        "値だけ終わったとき": f"{token}だけ終わったとき",
        "値である": f"{token}である",
        "値になる": f"{token}になる",
        "値に達したとき": f"{token}に達したとき",
        "値に達するたび": f"{token}に達するたび",
        "値のあいだ": f"{token}のあいだ",
        "値のラウンドごと": f"{token}ラウンドごと",
        "値のラウンド数が減っていく": f"{token}ラウンド数が減っていく",
        "値のラウンド数が経ったとき": f"{token}ラウンドが経ったとき",
        "値のラウンド数だけ": f"{token}ラウンドだけ",
        "値のラウンド数のあいだ": f"{token}ラウンドのあいだ",
        "値の回数だけ入る": f"{token}回入る",
        "値の回数である": f"{token}回である",
        "値の回数で獲得する": f"{token}回で獲得する",
        "値の回数までである": f"{token}回までである",
        "値までである": f"{token}までである",
        "値を掛けたぶんだけ": f"{token}を掛けたぶんだけ",
        "値を掛けたぶん高くなる": f"{token}を掛けたぶん高くなる",
        "値を掛けた数である": f"{token}を掛けた数である",
        "値を掛けた数以上になったとき": f"{token}を掛けた数以上になったとき",
        "値を足したコストの合成先になる": f"{token}を足したコストの合成先になる",
        "値を足したゴールドが入る": f"{token}を足したゴールドが入る",
        "値を足した数である": f"{token}を足した数である",
        "値以上なら": f"{token}以上なら",
        "値以上になったとき": f"{token}以上になったとき",
        "値以上のとき": f"{token}以上のとき",
        "値以上持っているあいだ": f"{token}以上持っているあいだ",
        "値以下のときだけである": f"{token}以下のときだけである",
        "値倍である": f"{token}倍である",
        "値倍になる": f"{token}倍になる",
        "値回終わるたびに数える": f"{token}回終わるたびに数える",
        "値未満なら": f"{token}未満なら",
        "値で割った回数だけ": f"{token}で割った回数だけ",
        "値ごとに": f"{token}ごとに",
        "値が": f"{token}が",
        "割合が体力に戻る": f"{token}が体力に戻る" if token.endswith("%") else f"{token}%が体力に戻る",
        "割合が戻る": f"{token}が戻る" if token.endswith("%") else f"{token}%が戻る",
        "割合だけ低い": f"{token}だけ低い" if token.endswith("%") else f"{token}%だけ低い",
        "割合だけ低くなる": f"{token}だけ低くなる" if token.endswith("%") else f"{token}%だけ低くなる",
        "割合だけ安くなる": f"{token}だけ安くなる" if token.endswith("%") else f"{token}%だけ安くなる",
        "割合だけ高い": f"{token}だけ高い" if token.endswith("%") else f"{token}%だけ高い",
        "割合である": token + "である" if token.endswith("%") else f"{token}%である",
        "割合になる": token + "になる" if token.endswith("%") else f"{token}%になる",
        "割合に達するたび": (token if token.endswith("%") else f"{token}%") + "に達するたび",
        "割合以下になったとき": (token if token.endswith("%") else f"{token}%") + "以下になったとき",
    }
    if rest in mapping:
        return mapping[rest]
    fixed = re.match(r"値は(\d+(?:\.\d+)?)である", rest)
    if fixed:
        return f"{fixed.group(1)}である"
    return m.group(0)


def polish(text: str) -> str:
    text = PCT_NOTE_RE.sub("", text)
    text = re.sub(r"は、(?=\d)", "は", text)

    # Merge redundant quantity sentences
    text = re.sub(
        r"([^。]*?)が高くなる。高くなる割合は(\d+(?:\.\d+)?)%である。",
        r"\1が\2%高くなる。",
        text,
    )
    text = re.sub(
        r"([^。]*?)が低くなる。低くなる割合は(\d+(?:\.\d+)?)%である。",
        r"\1が\2%低くなる。",
        text,
    )
    text = re.sub(
        r"([^。]*?)が高くなる。高くなる量は(\d+(?:\.\d+)?)である。",
        r"\1が\2高くなる。",
        text,
    )
    text = re.sub(
        r"([^。]*?)が低くなる。低くなる量は(\d+(?:\.\d+)?)である。",
        r"\1が\2低くなる。",
        text,
    )
    text = re.sub(
        r"1回で高くなる量は(\d+(?:\.\d+)?)である。",
        r"1回で\1高くなる。",
        text,
    )
    text = re.sub(
        r"1回で高くなる割合は(\d+(?:\.\d+)?)%である。",
        r"1回で\1%高くなる。",
        text,
    )
    text = re.sub(
        r"無料更新を獲得する。獲得する数は(\d+(?:\.\d+)?)である。",
        r"無料更新が\1回入手できる。",
        text,
    )
    text = re.sub(
        r"無料更新を獲得する。獲得する無料更新は(\d+)である。",
        r"無料更新が\1回入手できる。",
        text,
    )
    text = re.sub(r"ゴールドが入る。入る量は(\d+(?:\.\d+)?)である。", r"ゴールドが\1入る。", text)
    text = re.sub(r"経験値が入る。入る量は(\d+(?:\.\d+)?)である。", r"経験値が\1入る。", text)
    text = re.sub(r"安くなる。安くなる量は(\d+(?:\.\d+)?)である。", r"\1安くなる。", text)
    text = re.sub(r"層が付く。付く数は(\d+(?:\.\d+)?)である。", r"層が\1付く。", text)
    text = re.sub(r"貫通する。貫通する割合は(\d+(?:\.\d+)?)%である。", r"\1貫通する。", text)
    text = re.sub(
        r"体力が戻る。戻る量は、そのときの最大体力のうち、(\d+(?:\.\d+)?)%である。",
        r"最大体力の\1%だけ体力が戻る。",
        text,
    )
    text = re.sub(
        r"戻る量は、そのときの最大体力のうち、(\d+(?:\.\d+)?)%である。",
        r"戻る量は最大体力の\1%である。",
        text,
    )
    text = re.sub(
        r"戻る量は、その味方の最大体力のうち、(\d+(?:\.\d+)?)%である。",
        r"戻る量はその味方の最大体力の\1%である。",
        text,
    )
    text = re.sub(r"回数は、(\d+)である。", r"回数は\1である。", text)
    text = re.sub(r"上限は(\d+(?:\.\d+)?)である。", r"上限は\1である。", text)
    text = re.sub(
        r"1戦闘で(?:戻る|出せる|減らせる|付けられる)回数は(\d+)までである。",
        r"1戦闘で\1回までである。",
        text,
    )
    text = re.sub(
        r"1戦闘で戻る回数は(\d+)までである。",
        r"1戦闘で\1回まで戻る。",
        text,
    )
    # Clarify leftover "のうち、8%である"
    text = re.sub(r"のうち、(\d+(?:\.\d+)?)%である。", r"のうち\1%である。", text)
    text = re.sub(r"。{2,}", "。", text)
    text = re.sub(r"、{2,}", "、", text)
    return text.strip()


def rewrite_detail(detail: str, effects: dict[str, float]) -> str:
    def dual(m: re.Match) -> str:
        num = m.group("num")
        pct = m.group("pct") or "%"
        # Both keys share the same stated number in these sheets
        return f"どちらも{num}{pct}である。"

    detail = DUAL_KEYS_RE.sub(dual, detail)
    detail = PAIR_RE.sub(rewrite_pair, detail)
    detail = BROKEN_LIMIT_RE.sub(lambda m: f"{m.group('num')}までである。", detail)

    for _ in range(4):
        new = INLINE_RE.sub(lambda m: rewrite_inline(m, effects), detail)
        new = PCT_NOTE_RE.sub("", new)
        if new == detail:
            break
        detail = new
    return polish(detail)


def rewrite_brief(brief: str, effects: dict[str, float]) -> str:
    brief = brief.strip()
    if "無料更新" in brief and "無料更新" in effects:
        n = fmt_num(effects["無料更新"])
        brief = re.sub(r"無料更新をまとめて獲得する", f"無料更新が{n}回入手できる", brief)
        brief = re.sub(r"無料更新を獲得する", f"無料更新が{n}回入手できる", brief)
    if re.search(r"\d", brief):
        return brief.strip()

    if "ゴールドが入る" in brief and "ゴールド" in effects:
        brief = brief.replace("ゴールドが入る", f"ゴールドが{fmt_num(effects['ゴールド'])}入る", 1)
    if "経験値が入る" in brief and "経験値" in effects:
        brief = brief.replace("経験値が入る", f"経験値が{fmt_num(effects['経験値'])}入る", 1)

    swaps = [
        ("与えるダメージが高くなる", "与ダメージ", True, "与えるダメージが{t}高くなる"),
        ("与ダメージが高くなる", "与ダメージ", True, "与ダメージが{t}高くなる"),
        ("速度が高くなる", "速度", False, "速度が{t}高くなる"),
        ("防御力が高くなる", "防御力", False, "防御力が{t}高くなる"),
        ("最大体力が高くなる", "最大体力", False, "最大体力が{t}高くなる"),
        ("クリティカル率が高くなる", "クリティカル率", False, "クリティカル率が{t}高くなる"),
        ("クリティカルダメージが高くなる", "クリティカルダメージ", False, "クリティカルダメージが{t}高くなる"),
        ("属性耐性が高くなる", "属性耐性", True, "属性耐性が{t}高くなる"),
        ("受けるダメージが低くなる", "受けるダメージ", True, "受けるダメージが{t}低くなる"),
        ("防御を貫通する", "貫通率", True, "防御を{t}貫通する"),
    ]
    for phrase, key, as_pct, template in swaps:
        if phrase not in brief or key not in effects:
            continue
        num = fmt_num(effects[key])
        token = f"{num}%" if as_pct else num
        brief = brief.replace(phrase, template.format(t=token), 1)
        break
    return brief.strip()


def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    text = original
    effects = parse_effects(text)

    dm = DETAIL_RE.search(text)
    if dm:
        new_detail = rewrite_detail(dm.group(2), effects)
        text = text[: dm.start(2)] + new_detail + text[dm.end(2) :]

    bm = BRIEF_RE.search(text)
    if bm:
        new_brief = rewrite_brief(bm.group(2), effects)
        text = text[: bm.start(2)] + new_brief + text[bm.end(2) :]

    # Second pass on detail after brief edits don't change effects
    dm = DETAIL_RE.search(text)
    if dm and ("効果値の" in dm.group(2) or "この欄は%" in dm.group(2) or "高くなる割合は" in dm.group(2) or "獲得する数は" in dm.group(2)):
        new_detail = rewrite_detail(dm.group(2), effects)
        text = text[: dm.start(2)] + new_detail + text[dm.end(2) :]

    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        return True
    return False


def main() -> None:
    changed = 0
    residual = []
    for path in sorted(ROOT.glob("*.md")):
        if process_file(path):
            changed += 1
        text = path.read_text(encoding="utf-8")
        dm = DETAIL_RE.search(text)
        if not dm:
            continue
        detail = dm.group(2)
        if "効果値の" in detail or "この欄は%" in detail:
            residual.append(path.name)
    print(f"changed={changed} residual={len(residual)}")
    for name in residual:
        path = ROOT / name
        text = path.read_text(encoding="utf-8")
        dm = DETAIL_RE.search(text)
        idx = dm.group(2).find("効果値の")
        snippet = dm.group(2)[max(0, idx - 10) : idx + 70]
        print(f" {name}: {snippet}")


if __name__ == "__main__":
    main()
