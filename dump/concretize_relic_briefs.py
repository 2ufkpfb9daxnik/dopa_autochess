# -*- coding: utf-8 -*-
"""簡単な説明文の曖昧語をやめ、効果値の具体数を入れる。"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "data" / "relics"
BRIEF_RE = re.compile(r"(## 簡単な説明文\n\n)(.+?)(\n\n## )", re.S)
DETAIL_RE = re.compile(r"(## 詳細な説明文\n\n)(.+?)(\n\n## |\Z)", re.S)
EFFECT_RE = re.compile(r"\|\s*([^|]+?)\s*\|\s*([0-9.]+)\s*\|")
VAGUE_RE = re.compile(
	r"一定|少し|しばしば|数回|数ラウンド|まとまって|大きく|極度に|非常に|しばらく"
)


def parse(text: str) -> tuple[str, str, dict[str, float]]:
	bm = BRIEF_RE.search(text)
	dm = DETAIL_RE.search(text)
	brief = bm.group(2).strip() if bm else ""
	detail = dm.group(2).strip() if dm else ""
	effects: dict[str, float] = {}
	for key, val in EFFECT_RE.findall(text):
		k = key.strip()
		if k in ("効果値", "---"):
			continue
		try:
			effects[k] = float(val)
		except ValueError:
			pass
	return brief, detail, effects


def iv(effects: dict[str, float], *keys: str, default: int | None = None) -> int | None:
	for key in keys:
		if key in effects:
			return int(effects[key])
	return default


def pct(n: int | float | None) -> str:
	if n is None:
		return "?"
	v = int(n)
	return f"{v}%"


def rewrite_brief(brief: str, detail: str, effects: dict[str, float]) -> str:
	b = brief
	e = effects

	def sub(pattern: str, repl: str) -> None:
		nonlocal b
		b = re.sub(pattern, repl, b)

	# --- common vague → concrete ---
	g = iv(e, "ゴールド")
	if g is not None:
		sub(r"ゴールドが少し入る", f"ゴールドが{g}入る")
		sub(r"ゴールドがまとまって入る", f"ゴールドが{g}入る")
		sub(r"ゴールドも入る", f"ゴールドが{g}入る")
		sub(r"ゴールドが多く戻る", f"ゴールドが{g}多く戻る")
		sub(r"ゴールドが多く入る", f"ゴールドが{g}入る")
		sub(r"まとまったゴールドが入って消える", f"ゴールドが{g}入って消える")
		sub(r"ゴールドと無料更新が入る", f"ゴールドが{g}と無料更新が入る")
		sub(r"ゴールドと耐久のレリックが入る", f"ゴールドが{g}と耐久のレリックが入る")
		sub(r"ゴールドとレリックが入る", f"ゴールドが{g}とレリックが入る")

	x = iv(e, "経験値")
	if x is not None:
		sub(r"経験値が少し入る", f"経験値が{x}入る")
		sub(r"経験値がまとまって入る", f"経験値が{x}入る")
		sub(r"経験値が少し多い", f"経験値が{x}多い")
		sub(r"経験値が多く入る", f"経験値が{x}入る")

	r = iv(e, "ラウンド")
	if r is not None:
		sub(r"続く数ラウンド", f"続く{r}ラウンド")
		sub(r"入手から数ラウンド", f"入手から{r}ラウンド")
		sub(r"数ラウンドのあいだ", f"{r}ラウンドのあいだ")
		sub(r"数ラウンド後に", f"{r}ラウンド後に")
		sub(r"数ラウンドで", f"{r}ラウンドで")
		sub(r"数ラウンドの開始時", f"{r}ラウンドの開始時")
		sub(r"そのあと数戦闘で", f"そのあと")  # 戦闘キーで後段処理

	c = iv(e, "回数")
	if c is not None:
		sub(r"次の有料更新数回だけ", f"次の有料更新{c}回だけ")
		sub(r"次の異種合成数回だけ", f"次の異種合成{c}回だけ")
		sub(r"一定回数まで", f"{c}回まで")

	hits = iv(e, "当たり")
	if hits is not None:
		sub(r"しばしば無料更新が1回入手できる", f"10回中{hits}回、無料更新が1回入手できる")
		sub(r"しばしば同じレリックがもう1つ入る", f"10回中{hits}回、同じレリックがもう1つ入る")

	iv_interval = iv(e, "間隔")
	if iv_interval is not None:
		sub(r"一定ラウンドごとに", f"{iv_interval}ラウンドごとに")
		sub(r"一定時間ごとに", f"{iv_interval}行動ごとに" if "行動" in detail or "間隔" in detail else f"{iv_interval}ごとに")

	# 戦闘間隔の文言は詳細に合わせる
	if iv_interval is not None and ("行動" in detail or "秒" in detail or "時間" in detail):
		if "行動" in detail:
			sub(rf"{iv_interval}ごとに", f"{iv_interval}行動ごとに")
		elif re.search(rf"{iv_interval}である", detail) and "時間" in detail:
			sub(rf"{iv_interval}ごとに", f"{iv_interval}のあいだごとに")

	th = iv(e, "閾値")
	if th is not None:
		sub(r"一定割合たまるたび", f"{th}%たまるたび")
		sub(r"体力が低いと", f"体力が{th}%以下だと" if "閾値" in e else "体力が低いと")

	n = iv(e, "枚数")
	if n is not None:
		sub(r"一定枚数持っているとき", f"{n}枚持っているとき")

	prog = iv(e, "進捗")
	if prog is not None:
		sub(r"一定数で", f"{prog}で")
		sub(r"一定回出たら", f"{prog}回出たら")
		sub(r"一定回命中したら", f"{prog}回命中したら")
		sub(r"一定回したら", f"{prog}回したら")
		sub(r"一定回使ったら", f"{prog}回使ったら")
		sub(r"一定回壊れたら", f"{prog}回壊れたら")
		sub(r"進む。一定数で", f"進む。{prog}で")

	gauge = iv(e, "ゲージ")
	if gauge is not None and "一定量" in b:
		sub(r"一定量使ったら", f"{gauge}使ったら")

	ws = iv(e, "連勝")
	if ws is not None and "一定" in b:
		sub(r"連勝が一定に達したら", f"連勝が{ws}に達したら")
		sub(r"連勝がまとまって付き", f"連勝が{ws}になる")

	ls = iv(e, "連敗")
	if ls is not None and "一定" in b:
		sub(r"連敗が一定に達したら", f"連敗が{ls}に達したら")

	lv = iv(e, "レベル")
	if lv is not None and "一定" in b:
		sub(r"プレイヤーレベルが一定に達したら", f"プレイヤーレベルが{lv}に達したら")

	dmg = iv(e, "与ダメージ")
	if dmg is not None:
		sub(r"与ダメージの積みがまとまって増える", f"与ダメージの積みが{pct(dmg)}増える")
		sub(r"与ダメージが大きく高い", f"与ダメージが{pct(dmg)}高くなる")
		sub(r"与ダメージが大きく高い。", f"与ダメージが{pct(dmg)}高くなる。")
		sub(r"次の戦闘の与ダメージが大きく高い", f"次の戦闘の与ダメージが{pct(dmg)}高くなる")
		sub(r"味方全員の与ダメージが大きく高い", f"味方全員の与ダメージが{pct(dmg)}高くなる")
		sub(r"後衛の与ダメージが大きく高い", f"後衛の与ダメージが{pct(dmg)}高くなる")
		sub(r"与ダメージが大きく高い", f"与ダメージが{pct(dmg)}高くなる")
		sub(r"クリティカル率とクリティカルダメージが大きく高い", "")  # handled below
		if "与ダメージが高い" in b and not re.search(r"\d", b):
			sub(r"与ダメージが高い", f"与ダメージが{pct(dmg)}高くなる")
		if "非常に強い" in b:
			recv = iv(e, "受けるダメージ")
			if recv is not None:
				sub(
					r"連勝中だけ味方全員が非常に強い",
					f"連勝中だけ味方全員の与ダメージが{pct(dmg)}高く、受けるダメージが{pct(recv)}低くなる",
				)

	# attribute synergy: 少し強くなる
	for attr_key, label in [
		("炎の与ダメージ", "炎"),
		("水の与ダメージ", "水"),
		("氷の与ダメージ", "氷"),
		("風の与ダメージ", "風"),
		("雷の与ダメージ", "雷"),
		("土の与ダメージ", "土"),
		("吸収の与ダメージ", "吸収"),
	]:
		v = iv(e, attr_key)
		if v is not None:
			sub(rf"{label}属性の攻撃が少し強くなる", f"{label}属性の攻撃の与ダメージが{pct(v)}高くなる")

	atk = iv(e, "攻撃力")
	if atk is not None and "攻撃力が高くなる" in b and not re.search(r"\d", b.split("攻撃力")[-1][:8]):
		sub(r"攻撃力が高くなる", f"攻撃力が{atk}高くなる")

	first = iv(e, "最初の与ダメージ")
	if first is not None:
		sub(r"最初の攻撃が強くなる", f"最初の攻撃の与ダメージが{pct(first)}高くなる")
		sub(r"最初の攻撃は外れず、強くなる", f"最初の攻撃は外れず、与ダメージが{pct(first)}高くなる")

	summon = iv(e, "召喚の与ダメージ")
	if summon is not None:
		sub(r"召喚物の与ダメージが高くなる", f"召喚物の与ダメージが{pct(summon)}高くなる")

	g15 = iv(e, "ゲージ")
	if g15 is not None and "ゲージが増えやすい" in b:
		sub(r"ゲージが増えやすい", f"ゲージが{g15}増えやすい")
	if g15 is not None and "ゲージが大きく増える" in b:
		sub(r"ゲージが大きく増える", f"ゲージが{g15}増える")

	hpmax = iv(e, "最大体力", "最大HP")
	if hpmax is not None:
		sub(r"最大体力は大きく低い", f"最大体力が{pct(hpmax)}低くなる")
		sub(r"最大体力が大きく高く", f"最大体力が{pct(hpmax)}高く")
		sub(r"プレイヤー最大HPが大きく増える", f"プレイヤー最大HPが{hpmax}増える")
		sub(r"プレイヤーの最大HPが高くなる", f"プレイヤーの最大HPが{hpmax}高くなる")

	recv = iv(e, "受けるダメージ")
	if recv is not None:
		sub(r"受けるダメージが極度に低い", f"受けるダメージが{pct(recv)}低くなる")
		if "受けるダメージがさらに低くなる" in b and not re.search(r"\d+%低", b):
			sub(r"受けるダメージがさらに低くなる", f"受けるダメージがさらに{pct(recv)}低くなる")
		if "受けるダメージが低い" in b and not re.search(r"\d", b):
			sub(r"受けるダメージが低い", f"受けるダメージが{pct(recv)}低くなる")

	cap = iv(e, "上限")
	if cap is not None and "合成上限が大きく高い" in b:
		sub(r"合成上限が大きく高い", f"合成上限が{cap}高い")

	crit_r = iv(e, "クリティカル率")
	crit_d = iv(e, "クリティカルダメージ")
	if crit_r is not None and crit_d is not None and ("クリティカル" in b) and ("大きく" in brief or not re.search(r"\d", brief)):
		b = f"クリティカル率が{crit_r}、クリティカルダメージが{pct(crit_d)}高くなる。"

	pen = iv(e, "貫通率")
	if pen is not None:
		sub(r"防御を大きく防御を40%貫通する", f"防御を{pct(pen)}貫通する")
		sub(r"貫通率が高くなる", f"貫通率が{pct(pen)}高くなる")

	fight = iv(e, "戦闘")
	hp_loss = iv(e, "HP")
	if fight is not None and hp_loss is not None and "大きく失う" in b:
		g2 = iv(e, "ゴールド")
		b = f"入手時にプレイヤーHPが{hp_loss}減る。そのあと{fight}戦闘で、ゴールドが{g2}入って消える。"

	start_hp = iv(e, "開始体力")
	if start_hp is not None and dmg is not None and "後衛" in b:
		b = f"後衛の与ダメージが{pct(dmg)}高くなる。後衛は戦闘開始時の体力が{pct(start_hp)}になる。"

	add = iv(e, "追加")
	if add is not None and "失った分より多く戻って消える" in b and r is not None:
		b = f"入手時にゴールドをすべて失う。{r}ラウンド後に、失った分に{add}を足して戻って消える。"
	if add is not None and "増え方が大きくなる" in b:
		sub(r"増え方が大きくなる", f"増え方が{add}大きくなる")

	# ダメージ「一定に達したら」クエスト系
	mult = iv(e, "倍率")
	if mult is not None and "一定に達したら" in b:
		sub(r"与えたダメージが一定に達したら", f"与えたダメージが基準の{mult}倍に達したら")
		sub(r"受けたダメージが一定に達したら", f"受けたダメージが基準の{mult}倍に達したら")

	# 302 closure
	if iv(e, "与ダメージ") == 300:
		b = (
			f"味方の与ダメージが{pct(iv(e,'与ダメージ'))}高く、受けるダメージが{pct(iv(e,'受けるダメージ'))}低くなる。"
			f"毎ラウンド、ゴールド{iv(e,'ゴールド')}、経験値{iv(e,'経験値')}、無料更新{iv(e,'無料更新')}が入る。"
		)

	# 010-style already handled; inject digits for remaining no-digit briefs
	if not re.search(r"\d", b) and e:
		b = inject_from_effects(b, e, detail)

	# cleanup double spaces / duplicate periods
	b = re.sub(r"。+", "。", b)
	b = re.sub(r"\s+", "", b) if False else b  # keep spaces as Japanese uses none mostly
	b = b.strip()
	return b


def inject_from_effects(brief: str, effects: dict[str, float], detail: str) -> str:
	"""数字が無い短い説明に、主効果の数を足す。"""
	b = brief
	# ordered preference of how to phrase
	pairs = [
		("最初の与ダメージ", "最初の与ダメージが{}%高くなる", True),
		("次の与ダメージ", "次の攻撃の与ダメージが{}%低くなる", True),
		("属性の与ダメージ", "自分の攻撃属性の与ダメージが{}%高くなる", True),
		("瀕死の与ダメージ", "体力半分以下のとき与ダメージが{}%高くなる", True),
		("与ダメージ", "与ダメージが{}%高くなる", True),
		("受けるダメージ", "受けるダメージが{}%低くなる", True),
		("軽減", "受けるダメージが{}%低くなる", True),
		("貫通率", "貫通率が{}%高くなる", True),
		("クリティカル率", "クリティカル率が{}高くなる", False),
		("攻撃力", "攻撃力が{}高くなる", False),
		("防御力", "防御力が{}%高くなる", True),
		("速度", "速度が{}高くなる", False),
		("最大体力", "最大体力が{}%高くなる", True),
		("最大HP", "最大HPが{}高くなる", False),
		("回復", "回復が{}入る", False),
		("シールド", "シールドが最大体力の{}%付く", True),
		("吸血", "与ダメージの{}%が体力に戻る", True),
		("反射", "受けたダメージの{}%を返す", True),
		("ゲージ", "ゲージが{}増える", False),
		("値引き", "価格が{}安くなる", False),
		("売却", "売却額が{}増える", False),
		("利息", "利息が{}多い", False),
		("元手", "利息の元手が{}多い", False),
		("ゴールド", "ゴールドが{}入る", False),
		("経験値", "経験値が{}入る", False),
		("無料更新", "無料更新が{}回入る", False),
		("出撃", "出撃上限が{}多い", False),
		("HP", "HPが{}関与する", False),
		("優先度の低下", "ターゲット優先度が{}低くなる", False),
		("優先度の上昇", "ターゲット優先度が{}高くなる", False),
		("層", "層が{}付く", False),
		("撃破の回数", "撃破が{}進む", False),
		("短縮", "デバフが{}短くなる", False),
		("ロック", "ロック枠が{}残る", False),
		("回数", "回数が{}ある", False),
		("列の枠", "列の枠が{}", False),
		("コスト", "コスト{}が関与する", False),
		("倍率", "倍率が{}", False),
		("ダメージ", "ダメージが{}減る", False),
		("時間", "時間が{}", False),
		("間隔", "間隔が{}", False),
		("開始体力", "開始体力が{}%", True),
		("レベル低下", "出現率がレベル{}低い扱い", False),
	]

	# If brief already states qualitative effect, append concrete clause
	for key, tmpl, is_pct in pairs:
		if key not in effects:
			continue
		val = int(effects[key]) if float(effects[key]).is_integer() else effects[key]
		num = pct(val) if is_pct and key not in ("値引き",) and "%" not in tmpl.format(val) else str(int(val) if isinstance(val, float) and val == int(val) else val)
		# special percent keys already have % in template via {}%
		clause = tmpl.format(num.replace("%", "") if "{}" in tmpl and "%高く" in tmpl or "%低く" in tmpl or "%が" in tmpl else num)
		# fix double %% 
		clause = clause.replace("%%", "%")
		if re.search(r"\d", b):
			return b
		# replace soft adjectives
		if "高くなる" in b and "与ダメージ" in key:
			return re.sub(r"高くなる。?$", f"{pct(int(effects[key]))}高くなる。", b)
		if "低くなる" in b and "受ける" in key:
			return re.sub(r"低くなる。?$", f"{pct(int(effects[key]))}低くなる。", b)
		if "安い" in b and key == "値引き":
			v = int(effects[key])
			if v >= 50:
				return re.sub(r"安い。?$", f"{v}%安くなる。", b)
			return re.sub(r"安い。?$", f"{v}安くなる。", b)
		if "多い" in b and key in ("ゴールド", "売却", "利息", "経験値", "出撃"):
			return re.sub(r"多い。?$", f"{int(effects[key])}多い。", b)
		if "少ない" in b and key in ("ダメージ",):
			return re.sub(r"少ない。?$", f"{int(effects[key])}少ない。", b)
		if "速い" in b and key == "倍率":
			return re.sub(r"速い。?$", f"{int(effects[key])}倍速い。", b)
		if "狙われにくくなる" in b and key == "優先度の低下":
			return f"ターゲット優先度が{int(effects[key])}低くなる。"
		if "狙われやすくなる" in b and key == "優先度の上昇":
			return f"ターゲット優先度が{int(effects[key])}高くなる。"
		# append
		if not b.endswith("。"):
			b += "。"
		return b + clause if not clause.endswith("。") else b + clause

	# fallback: pull a short numeric sentence from detail
	for sent in re.split(r"。", detail):
		sent = sent.strip()
		if re.search(r"\d", sent) and len(sent) < 60:
			sent = re.sub(r"^このレリックを(?:装備しているキャラクターは、|持っているあいだ、|装備したとき、|入手したとき、)", "", sent)
			return sent + "。"
	return brief


def rewrite_detail(detail: str, effects: dict[str, float]) -> str:
	d = detail
	interval = iv(effects, "間隔")
	if interval is not None:
		# 「一定時間ごと」→ 具体
		if "一定時間ごとに速度" in d:
			d = d.replace("一定時間ごとに速度", f"{interval}行動ごとに速度")
		if "一定時間ごとに与ダメージ" in d:
			d = d.replace("一定時間ごとに与ダメージ", f"{interval}ごとに与ダメージ")
		if "一定時間ごとに体力" in d:
			d = d.replace("一定時間ごとに体力", f"{interval}行動ごとに体力")
		if "一定時間ごとに最大体力" in d:
			d = d.replace("一定時間ごとに最大体力", f"{interval}行動ごとに最大体力")
		# 284
		d = re.sub(r"一定時間ごとに、", f"{interval}ごとに、", d)
	return d


def process_file(path: Path) -> bool:
	text = path.read_text(encoding="utf-8")
	brief, detail, effects = parse(text)
	if not brief:
		return False
	new_brief = rewrite_brief(brief, detail, effects)
	new_detail = rewrite_detail(detail, effects) if detail else detail
	changed = False
	if new_brief != brief:
		text2, n = BRIEF_RE.subn(lambda m: m.group(1) + new_brief + m.group(3), text, count=1)
		if n:
			text = text2
			changed = True
	if new_detail != detail and detail:
		text2, n = DETAIL_RE.subn(lambda m: m.group(1) + new_detail + m.group(3), text, count=1)
		if n:
			text = text2
			changed = True
	if changed:
		path.write_text(text, encoding="utf-8", newline="\n")
	return changed


def main() -> None:
	changed = 0
	still_vague = []
	still_no_digit = []
	for path in sorted(ROOT.glob("*.md")):
		if process_file(path):
			changed += 1
		brief, _detail, effects = parse(path.read_text(encoding="utf-8"))
		if VAGUE_RE.search(brief):
			still_vague.append((path.name, brief))
		elif effects and not re.search(r"\d", brief):
			still_no_digit.append((path.name, brief, effects))
	print(f"updated {changed} files")
	print(f"still vague {len(still_vague)}")
	for name, brief in still_vague[:40]:
		print(f"  {name}: {brief}")
	print(f"still no digit {len(still_no_digit)}")
	for name, brief, eff in still_no_digit[:40]:
		print(f"  {name}: {brief} | {eff}")


if __name__ == "__main__":
	main()
