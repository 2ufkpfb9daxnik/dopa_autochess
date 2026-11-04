class_name RelicEconomy
extends "res://scripts/game/relic_economy_use.gd"

## まだ効果が入らないレリック（土台の仕組みが無いもの）。ほかはすべて適用済み。
## 056 回収: レリックを売る操作が無いので未適用。
## 075 舞台が終わる: ショップは全体のロックだけで、枠ごとのロックが無いので未適用。
## 101・105・107・110・113・115・119・264・293: 異種合成が無いので未適用（101・264 は合成上限の加算だけ synth_cost_cap に入る）。
## 109 歴史資料: キャラクターを分解する操作が無いので未適用。
## 179 流行: ショップにレリックが並ばないので未適用。
## 311 ハイブリッド: 「ほかのレリックの効果が初めて発動した」をレリックごとに記録する仕組みが無いので未適用。
##
## このファイルは入手とラウンドの区切り（いくつものテーマにまたがる入口）だけを持つ。
## ほかの関数はテーマごとのファイルにあり、継承でつながっている（relic_economy_base.gd の先頭を参照）。
## 外からは今までどおり RelicEconomy.xxx で呼べる。


## 入手したとき残り（left）を効果値で決めるだけのもの。値は効果値の名前。
const LEFT_ON_GAIN := {
	44: "回数", 46: "ラウンド", 52: "回数", 57: "回数", 66: "ラウンド", 77: "回数", 96: "ラウンド",
	100: "回数", 116: "ラウンド", 117: "回数", 133: "回数", 192: "ラウンド", 299: "回数",
}


static func on_gained(session: GameSession, uid: int, relic_id: int) -> void:
	var item := _item(session, uid)
	if item.is_empty():
		return
	if LEFT_ON_GAIN.has(relic_id):
		item["left"] = int(_value(relic_id, LEFT_ON_GAIN[relic_id]))
		return
	match relic_id:
		41:
			session.free_rerolls += int(_value(41, "無料更新"))
			session.take_relic(uid)
		43:
			session.relic_043_armed.append(uid)
		60, 67:
			session.add_coins(int(_value(relic_id, "ゴールド")))
			session.take_relic(uid)
		62:
			item["hits"] = int(_value(62, "当たり"))
			item["draws"] = 10
		84:
			session.gain_experience(int(_value(84, "経験値")))
			session.take_relic(uid)
		85:
			session.gain_experience(int(_value(85, "経験値")))
			item["left"] = int(_value(85, "ラウンド"))
		89:
			if session.get_level() >= 8:
				session.free_rerolls += int(_value(89, "無料更新"))
				session.take_relic(uid)
		90:
			session.gain_experience(int(_value(90, "経験値")))
		94:
			_remember_unit(session, item)
		97:
			_grant_hologram_now(session, uid)
		98:
			item["age"] = 1
		124:
			session.win_streak = int(_value(124, "連勝"))
			session.loss_streak = 0
			session.add_coins(int(_value(124, "ゴールド")))
			session.take_relic(uid)
		170:
			if not bool(item.get("from_copy", false)):
				for _i in int(_value(170, "追加")):
					session.add_relic(170, {"from_copy": true})
		171:
			session.player_hp += int(_value(171, "最大HP"))
		178:
			if not bool(item.get("seed", false)) and not bool(item.get("from_copy", false)):
				item["seed"] = true
				item["left"] = int(_value(178, "回数"))
			elif bool(item.get("from_copy", false)):
				item["seed"] = false
		254:
			item["hp_exp"] = true
		255:
			item["block_interest"] = true
			session.add_coins(int(_value(255, "ゴールド")))
		258:
			item["block_paid_reroll"] = true
		259:
			item["armed"] = session.win_streak > 0
		260:
			session.player_hp += int(round(float(PlayerHp.INITIAL_HP) * _value(260, "最大HP") / 100.0))
		261:
			session.player_hp = maxi(1, session.player_hp - int(_value(261, "HP")))
			item["left"] = int(_value(261, "戦闘"))
		263:
			item["bank"] = session.coins
			if session.coins > 0:
				session.spend_coins(session.coins)
			item["left"] = int(_value(263, "ラウンド"))
		279:
			## 入手した直後のラウンドは与ダメージ側。戦闘のあと（ラウンド開始の前）に入ったときは、
			## 次のラウンド開始の切り替えで与ダメージ側になるよう、回復側にしておく。
			if not session.is_prep():
				item["mode"] = 1
		285:
			_queue_random_relic(session)
			item["left"] = int(_value(285, "ラウンド"))
		286:
			item["progress"] = 0
			item["grants"] = 0
		296, 297, 298:
			item["armed"] = true
			## すでに条件を満たしていれば、入手したときに入る。
			note_streak_quests(session)
			_check_level_quest(session)
		310:
			session.relic_pending_picks += 1


static func prepare_round(session: GameSession) -> void:
	session.relic_paid_free_used = false
	session.relic_buy_counts.clear()
	session.relic_cost_rewarded.clear()


## ラウンド開始。入るゴールドを返す（加えるのは呼ぶ側）。
static func apply_round_open(session: GameSession) -> int:
	var gold := round_start_gold(session)
	gold += _tick_down(session, 66) * int(_value(66, "ゴールド"))
	gold += _resolve_timed_bank(session)
	session.free_rerolls += _coyote_rerolls(session)
	for relic_id in [61, 258, 312, 302, 132]:
		session.free_rerolls += _owned_value(session, relic_id, "無料更新")
	advance_eggs(session)
	_tick_down(session, 116)
	if _count(session, 169) > 0 and randi() % 10 < int(_value(169, "当たり")):
		session.add_relic(169)
	gold += _circle_bearers(session, 207) * int(_value(207, "ゴールド"))
	session.gain_experience(round_start_experience(session))
	note_growth_round(session)
	gold += round_streak_gold(session)
	_advance_grant_rounds(session)
	_check_level_quest(session)
	_rewrite_bottom_bench(session)
	_toggle_round_relics(session)
	return gold


static func on_round_end(session: GameSession, bench_count: int, bench_cap: int) -> void:
	var bench_full := bench_cap > 0 and bench_count >= bench_cap
	var bench_empty := not bench_full and bench_count <= 0
	var bench_gold := 0
	if bench_full:
		bench_gold = _owned_value(session, 48, "ゴールド")
	elif bench_empty:
		bench_gold = _owned_value(session, 55, "ゴールド")
	if bench_gold > 0:
		session.add_coins(bench_gold)
	if session.coins < int(_value(54, "閾値")):
		session.add_coins(_owned_value(session, 54, "ゴールド"))
	var end_xp := 0
	if bench_full:
		end_xp = _owned_value(session, 82, "経験値")
	elif bench_empty:
		end_xp = _owned_value(session, 81, "経験値")
	end_xp += _circle_bearers(session, 209) * int(_value(209, "経験値"))
	session.relic_end_xp = end_xp
	_tick_down(session, 96)
	## 043 の値引きはそのラウンドだけ。
	var remove: Array[int] = session.relic_043_live.duplicate()
	session.relic_043_live.clear()
	session.relic_shop_discount = 0
	session.relic_139_live = 0
	for uid in remove:
		session.take_relic(uid)
