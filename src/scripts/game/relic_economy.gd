class_name RelicEconomy
extends RefCounted

## 056 回収: ほかのレリックを売ったときゴールドが増える。レリックを売る操作がまだ無いので未適用。
## 075 舞台が終わる: ロックした枠だけ残す更新。枠ごとのロックが無く、ショップ全体のロックしか無いので未適用。
## 087 達人: プレイヤー同士の戦闘が無く、対CPU戦しか無いので未適用。
## 090 パレード: レベル21までの必要経験値が書かれていないので未適用。
## 091 パラダイス！のプレイヤーダメージ: プレイヤー同士の敗北が無いので、出撃上限だけ適用する。
## 101・105・107・110・113・115・116・119: 異種合成がまだ無いので未適用。
## 103・104: キャラクターを選んで使う操作がまだ無いので未適用。
## 109 歴史資料: キャラクターを分解する操作がまだ無いので未適用。
## 121・122・123・128・129・131・132・134・135・136・137・138・139: プレイヤー同士の戦闘が無いので未適用。
## 142・144・146・149・160: プレイヤー同士の戦闘が条件なので未適用。
## 148 反例: デバフに残り時間が無いので未適用。
## 156 ギター: 任意のタイミングで積みを換える操作が無いので未適用。
## 167・173・177・179・180: 付け替えUI・余剰回復シールド上限・被弾スタック・分類ショップ値引き・手動消費の操作が未確定なので未適用。
## 181-200: 盤面装置・コピー召喚・卵枠など未実装のため、195の初動弱体以外は未適用。
## 216: 召喚物与ダメージ。召喚が出ないあいだ未適用。
## 264: 異種合成ペナルティ。異種合成が無いので未適用。
## 277・278・284: 時間指定の戦闘効果が未確定なので未適用。
## 287-295・300: 合成装備級や装置回数など報酬テーブル／進捗定義の設定が残っているので未適用。
## 303-306: レリックを選んで消費するUIが無いので未適用。
## 309・311: 合成時追加と「効果が初めて発動」の判定が未確定なので未適用。


static func on_gained(session: GameSession, uid: int, relic_id: int) -> void:
	var item := _item(session, uid)
	if item.is_empty():
		return
	match relic_id:
		41:
			session.free_rerolls += int(_value(41, "無料更新"))
			session.take_relic(uid)
		46:
			item["left"] = int(_value(46, "ラウンド"))
		44, 52, 57:
			item["left"] = int(_value(relic_id, "回数"))
		43:
			session.relic_043_armed.append(uid)
		60:
			session.add_coins(int(_value(60, "ゴールド")))
			session.take_relic(uid)
		62:
			item["hits"] = int(_value(62, "当たり"))
			item["draws"] = 10
		66:
			item["left"] = int(_value(66, "ラウンド"))
		67:
			session.add_coins(int(_value(67, "ゴールド")))
			session.take_relic(uid)
		77:
			item["left"] = int(_value(77, "回数"))
		84:
			session.gain_experience(int(_value(84, "経験値")))
			session.take_relic(uid)
		85:
			session.gain_experience(int(_value(85, "経験値")))
			item["left"] = int(_value(85, "ラウンド"))
		90:
			session.gain_experience(int(_value(90, "経験値")))
		192:
			item["left"] = int(_value(192, "ラウンド"))
		89:
			if session.get_level() >= 8:
				session.free_rerolls += int(_value(89, "無料更新"))
				session.take_relic(uid)
		94:
			_remember_unit(session, item)
		96:
			item["left"] = int(_value(96, "ラウンド"))
		97:
			_grant_hologram_now(session, uid)
		98:
			item["age"] = 1
		100:
			item["left"] = int(_value(100, "回数"))
		108:
			var host_108 := session.get_parent()
			if host_108 != null and host_108.has_method("relic_upgrade_board_costs"):
				host_108.relic_upgrade_board_costs(int(_value(108, "コスト上昇")))
			session.take_relic(uid)
		117:
			item["left"] = int(_value(117, "回数"))
		124:
			session.win_streak = int(_value(124, "連勝"))
			session.loss_streak = 0
			session.add_coins(int(_value(124, "ゴールド")))
			session.take_relic(uid)
		133:
			item["left"] = int(_value(133, "回数"))
		116:
			item["left"] = int(_value(116, "ラウンド"))
		171:
			session.player_hp += int(_value(171, "最大HP"))
		260:
			session.player_hp += int(round(float(PlayerHp.INITIAL_HP) * _value(260, "最大HP") / 100.0))
		170:
			if not bool(item.get("from_copy", false)):
				for _i in int(_value(170, "追加")):
					session.add_relic(170, {"from_copy": true})
		178:
			if not bool(item.get("seed", false)) and not bool(item.get("from_copy", false)):
				item["seed"] = true
				item["left"] = int(_value(178, "回数"))
			elif bool(item.get("from_copy", false)):
				item["seed"] = false
		253:
			pass
		254:
			item["hp_exp"] = true
		255:
			item["block_interest"] = true
			session.add_coins(int(_value(255, "ゴールド")))
		259:
			item["armed"] = session.win_streak > 0
		258:
			item["block_paid_reroll"] = true
		261:
			session.player_hp = maxi(1, session.player_hp - int(_value(261, "HP")))
			item["left"] = int(_value(261, "戦闘"))
		263:
			item["bank"] = session.coins
			if session.coins > 0:
				session.spend_coins(session.coins)
			item["left"] = int(_value(263, "ラウンド"))
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
		299:
			item["left"] = int(_value(299, "回数"))
		301:
			pass
		307:
			pass
		310:
			session.relic_pending_picks += 1


static func prepare_round(session: GameSession) -> void:
	session.relic_paid_free_used = false
	session.relic_buy_counts.clear()
	session.relic_cost_rewarded.clear()


static func interest_step(session: GameSession) -> int:
	if _count(session, 50) > 0:
		return int(_value(50, "必要ゴールド"))
	return 8


static func interest_extra(session: GameSession) -> int:
	var extra := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 46:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		extra += int(_value(46, "利息"))
		item["left"] = left - 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return extra


static func interest_principal_extra(session: GameSession) -> int:
	return _count(session, 65) * int(_value(65, "元手"))


static func interest_flat(session: GameSession) -> int:
	return _count(session, 64) * int(_value(64, "利息")) + _count(session, 137) * int(_value(137, "利息"))


static func interest_extra_preview(session: GameSession) -> int:
	var extra := 0
	for item in session.relics:
		if int(item.get("id", -1)) != 46 or int(item.get("left", 0)) <= 0:
			continue
		extra += int(_value(46, "利息"))
	return extra


static func round_start_gold(session: GameSession) -> int:
	var gold := _count(session, 42) * int(_value(42, "ゴールド"))
	gold += _count(session, 255) * int(_value(255, "ゴールド"))
	gold += _count(session, 302) * int(_value(302, "ゴールド"))
	gold += _count(session, 313) * int(_value(313, "ゴールド"))
	gold += _count(session, 308) * int(_value(308, "ゴールド")) * session.relics.size()
	return gold


static func apply_round_open(session: GameSession) -> int:
	var gold := round_start_gold(session)
	gold += _spend_timed_gold(session, 66)
	gold += _resolve_timed_bank(session)
	session.free_rerolls += _count(session, 61) * int(_value(61, "無料更新"))
	session.free_rerolls += _coyote_rerolls(session)
	session.free_rerolls += _count(session, 258) * int(_value(258, "無料更新"))
	session.free_rerolls += _count(session, 312) * int(_value(312, "無料更新"))
	session.free_rerolls += _count(session, 302) * int(_value(302, "無料更新"))
	session.free_rerolls += _count(session, 132) * int(_value(132, "無料更新"))
	advance_eggs(session)
	_spend_each(session, 116, 1)
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
	var bench_gold := 0
	if bench_cap > 0 and bench_count >= bench_cap:
		bench_gold = _count(session, 48) * int(_value(48, "ゴールド"))
	elif bench_count <= 0:
		bench_gold = _count(session, 55) * int(_value(55, "ゴールド"))
	if bench_gold > 0:
		session.add_coins(bench_gold)
	if session.coins < int(_value(54, "閾値")):
		session.add_coins(_count(session, 54) * int(_value(54, "ゴールド")))
	var end_xp := 0
	if bench_cap > 0 and bench_count >= bench_cap:
		end_xp = _count(session, 82) * int(_value(82, "経験値"))
	elif bench_count <= 0:
		end_xp = _count(session, 81) * int(_value(81, "経験値"))
	end_xp += _circle_bearers(session, 209) * int(_value(209, "経験値"))
	session.relic_end_xp = end_xp
	_spend_each(session, 96, 1)
	var remove: Array[int] = []
	for uid in session.relic_043_live:
		remove.append(uid)
	session.relic_043_live.clear()
	session.relic_shop_discount = 0
	session.relic_139_live = 0
	for uid in remove:
		session.take_relic(uid)


static func on_shop_refreshed(session: GameSession) -> void:
	session.relic_139_live = session.relic_139_pending
	session.relic_139_pending = 0
	_copy_board_unit(session)
	if session.relic_043_armed.is_empty():
		session.relic_shop_discount = 0
		_roll_slot_discount(session)
		session.gain_experience(_count(session, 83) * int(_value(83, "経験値")))
		return
	var amount := 0
	for uid in session.relic_043_armed:
		if session.relic_id_of(uid) == 43:
			amount += int(_value(43, "値引き"))
			session.relic_043_live.append(uid)
	session.relic_043_armed.clear()
	session.relic_shop_discount = amount
	_roll_slot_discount(session)
	session.gain_experience(_count(session, 83) * int(_value(83, "経験値")))


static func shop_price(session: GameSession, slot_index: int) -> int:
	if slot_index < 0 or slot_index >= session.shop_unit_ids.size():
		return 0
	var unit_id := session.shop_unit_ids[slot_index]
	if unit_id < 0:
		return 0
	if _count(session, 71) > 0:
		return 0
	var catalog := int(UnitCatalog.get_unit(unit_id)["cost"])
	var price := catalog
	price -= session.relic_shop_discount
	price -= session.relic_139_live
	price -= _count(session, 68) * int(_value(68, "値引き"))
	if catalog <= 3:
		price -= _count(session, 69) * int(_value(69, "値引き"))
	if slot_index == session.shop_unit_ids.size() - 1:
		price -= _count(session, 47) * int(_value(47, "値引き"))
	if slot_index == _dearest_slot(session):
		price -= _count(session, 53) * int(_value(53, "値引き"))
	for marked in session.relic_076_slots:
		if int(marked) == slot_index:
			price -= int(_value(76, "値引き"))
	if _count(session, 257) > 0:
		## 端数は切り上げ、最低1。
		return maxi(1, int(ceil(float(price) * (1.0 - _value(257, "値引き") / 100.0))))
	return maxi(0, price)


static func paid_reroll_cost(session: GameSession) -> int:
	if _count(session, 258) > 0:
		return 999
	var cost := GameSession.REROLL_COST
	if not session.relic_paid_free_used and _count(session, 51) > 0:
		return 0
	cost -= _charges(session, 57) * int(_value(57, "値引き"))
	cost -= _count(session, 131) * int(_value(131, "値引き"))
	return maxi(0, cost)


static func note_paid_reroll(session: GameSession, paid: int) -> void:
	if not session.relic_paid_free_used and _count(session, 51) > 0:
		session.relic_paid_free_used = true
		return
	_spend_charges(session, 57, 1)
	if paid <= 0:
		return
	var grant := 0
	for item in session.relics:
		if int(item.get("id", -1)) != 62:
			continue
		var hits := int(item.get("hits", int(_value(62, "当たり"))))
		var draws := int(item.get("draws", 10))
		if draws <= 0:
			hits = int(_value(62, "当たり"))
			draws = 10
		if randi() % draws < hits:
			hits -= 1
			grant += int(_value(62, "無料更新"))
		item["hits"] = hits
		item["draws"] = draws - 1
	session.free_rerolls += grant
	_spend_each(session, 100, 1)


## 254 二重: ゴールドで経験値を買えない。
static func blocks_gold_exp(session: GameSession) -> bool:
	return _count(session, 254) > 0


static func hp_exp_gain(session: GameSession) -> int:
	return GameSession.EXP_GAIN + (int(_value(254, "経験値")) if _count(session, 254) > 0 else 0)


static func exp_cost(session: GameSession) -> int:
	if _count(session, 254) > 0:
		return 999
	var cost := GameSession.EXP_COST
	cost -= _charges(session, 52) * int(_value(52, "値引き"))
	cost -= _count(session, 314) * int(_value(314, "値引き"))
	return maxi(0, cost)


static func note_exp_bought(session: GameSession) -> void:
	session.free_rerolls += _count(session, 45) * int(_value(45, "無料更新"))
	_spend_charges(session, 52, 1)
	for _i in _count(session, 92):
		session.refresh_shop(false)


static func note_unit_sold(session: GameSession) -> void:
	var pay := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 44:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		pay += int(_value(44, "ゴールド"))
		item["left"] = left - 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	session.add_coins(pay)
	for uid in remove:
		session.take_relic(uid)


static func note_unit_bought(session: GameSession, cost: int, stars: int) -> void:
	var seen := int(session.relic_buy_counts.get(cost, 0)) + 1
	session.relic_buy_counts[cost] = seen
	if seen >= 2 and not session.relic_cost_rewarded.has(cost) and _count(session, 49) > 0:
		session.relic_cost_rewarded[cost] = true
		session.free_rerolls += _count(session, 49) * int(_value(49, "無料更新"))
	if cost >= 5 and cost <= 7:
		session.add_coins(_count(session, 59) * int(_value(59, "戻りゴールド")) * maxi(stars, 1))
	session.free_rerolls += _count(session, 72) * int(_value(72, "無料更新"))
	_consume_one(session, 71)


static func crossing_bonus(session: GameSession) -> int:
	return _count(session, 78) * int(_value(78, "ゴールド"))


static func exp_bonus(session: GameSession) -> int:
	return _count(session, 74) * int(_value(74, "経験値"))


static func sell_bonus(session: GameSession) -> int:
	return _count(session, 70) * int(_value(70, "売却"))


static func sell_mult(session: GameSession) -> float:
	if _count(session, 257) > 0:
		return maxf(0.0, 1.0 - _value(257, "値引き") / 100.0)
	return 1.0


static func synth_gold(session: GameSession) -> int:
	return _count(session, 79) * int(_value(79, "ゴールド"))


static func note_level_up(session: GameSession, before: int, after: int) -> void:
	if after <= before:
		return
	var steps := after - before
	session.free_rerolls += _count(session, 73) * after * int(_value(73, "倍率"))
	var copies88 := _count(session, 88)
	if copies88 > 0:
		## 1レベル上がるたびに1回。
		for level in range(before + 1, after + 1):
			var cost := clampi(level - 4, 1, int(_value(88, "上限コスト")))
			var pool := UnitCatalog.get_unit_ids_by_cost(cost)
			for _i in copies88:
				if not pool.is_empty():
					_queue_unit(session, pool[randi() % pool.size()], 2)
			session.add_coins(copies88 * int(_value(88, "ゴールド")))
	_check_level_quest(session)
	if before < 8 and after >= 8:
		var copies89 := _count(session, 89)
		if copies89 > 0:
			session.free_rerolls += copies89 * int(_value(89, "無料更新"))
			_consume_all(session, 89)
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 94:
			continue
		var memory := int(item.get("memory", -1))
		if UnitCatalog.get_unit(memory).is_empty():
			continue
		for _step in steps:
			_queue_unit(session, memory, 1)
	var copies99 := _count(session, 99)
	if copies99 > 0 and steps > 0:
		var heal := steps * copies99 * int(_value(99, "HP"))
		session.player_hp = mini(player_max_hp(session), session.player_hp + heal)
		session.free_rerolls += steps * copies99 * int(_value(99, "無料更新"))
	note_level_growth(session, steps)


static func pair_merge_ready(session: GameSession) -> bool:
	return _count(session, 114) > 0


static func note_pair_merge(session: GameSession) -> void:
	_consume_one(session, 114)


static func note_same_merge(session: GameSession, unit_id: int, new_stars: int, cost: int) -> void:
	session.add_coins(_count(session, 106) * int(_value(106, "ゴールド")))
	session.add_coins(_count(session, 112) * maxi(cost, 0))
	session.gain_experience(_count(session, 120) * int(_value(120, "経験値")))
	if new_stars >= int(_value(118, "星")):
		for _i in _count(session, 118):
			_queue_unit(session, unit_id, 2)
	_trigger_merge_copy(session)
	note_same_merge_quest(session)
	if new_stars == 3:
		_grant_star3_quest(session)


static func star_sell_refund(session: GameSession, cost: int, stars: int) -> int:
	var refund := maxi(cost, 0) + sell_bonus(session)
	if stars > 1 and _count(session, 111) > 0:
		var assembled := maxi(cost, 0)
		var bodies := 1
		for _i in stars - 1:
			bodies *= 3
		assembled *= bodies
		refund = assembled + _count(session, 111) * int(_value(111, "ゴールド")) + sell_bonus(session)
	return int(floor(float(refund) * sell_mult(session)))


static func note_sold_unit(session: GameSession, unit_id: int, cost: int, stars: int, free_slots: int) -> void:
	if free_slots <= 0:
		return
	var choices: Array[int] = []
	for candidate in UnitCatalog.get_unit_ids_by_cost(cost):
		if candidate != unit_id:
			choices.append(candidate)
	if choices.is_empty():
		return
	var spawned := 0
	var remove: Array[int] = []
	for item in session.relics:
		if spawned >= free_slots:
			break
		if int(item.get("id", -1)) != 117 or int(item.get("left", 0)) <= 0:
			continue
		_queue_unit(session, choices[randi() % choices.size()], stars)
		var left := int(item.get("left", 0)) - 1
		item["left"] = left
		if left <= 0:
			remove.append(int(item.get("uid", -1)))
		spawned += 1
	for uid in remove:
		session.take_relic(uid)


static func _rewrite_bottom_bench(session: GameSession) -> void:
	var copies := _count(session, 102)
	if copies <= 0:
		return
	var host := session.get_parent()
	if host != null and host.has_method("relic_rewrite_bottom_bench"):
		host.relic_rewrite_bottom_bench(copies)
	session.add_coins(copies * int(_value(102, "ゴールド")))


static func streak_extra(session: GameSession) -> int:
	if maxi(session.win_streak, session.loss_streak) <= 0:
		return 0
	return _count(session, 127) * int(_value(127, "ゴールド"))


static func round_streak_gold(session: GameSession) -> int:
	if maxi(session.win_streak, session.loss_streak) < int(_value(140, "連")):
		return 0
	return _count(session, 140) * int(_value(140, "ゴールド"))


static func note_streak_broken(session: GameSession) -> void:
	var gold := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 133 or int(item.get("left", 0)) <= 0:
			continue
		gold += int(_value(133, "ゴールド"))
		var left := int(item.get("left", 0)) - 1
		item["left"] = left
		if left <= 0:
			remove.append(int(item.get("uid", -1)))
	if gold > 0:
		session.add_coins(gold)
	for uid in remove:
		session.take_relic(uid)


static func owned_outgoing(session: GameSession) -> float:
	var bonus := 0.0
	if session.win_streak > 0 and _count(session, 125) > 0:
		var each := minf(float(session.win_streak) * _value(125, "与ダメージ"), _value(125, "上限")) / 100.0
		bonus += float(_count(session, 125)) * each
	if session.loss_streak > 0 and _count(session, 126) > 0:
		var each_loss := minf(float(session.loss_streak) * _value(126, "与ダメージ"), _value(126, "上限")) / 100.0
		bonus += float(_count(session, 126)) * each_loss
	var missing := maxi(player_max_hp(session) - session.player_hp, 0)
	if missing > 0:
		bonus += float(_count(session, 130)) * float(missing) * _value(130, "与ダメージ") / 100.0
	if session.win_streak > 0:
		bonus += float(_count(session, 259)) * _value(259, "与ダメージ") / 100.0
	bonus += float(_count(session, 256)) * _value(256, "与ダメージ") / 100.0
	bonus += float(_count(session, 302)) * _value(302, "与ダメージ") / 100.0
	bonus += float(_count(session, 312)) * _value(312, "与ダメージ") / 100.0
	bonus += float(_count(session, 136)) * _value(136, "与ダメージ") / 100.0
	bonus += slide_outgoing(session)
	return bonus


static func growth_outgoing(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var total := 0.0
	for uid in unit.equipped_relic_uids:
		var relic_id := session.relic_id_of(uid)
		if relic_id == 158:
			total += float(session.round_number) * _value(158, "与ダメージ")
		elif _is_damage_growth(relic_id):
			total += _growth_of(session, uid)
	total += relic_279_outgoing(session, unit) * 100.0
	return total / 100.0


static func growth_taken(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var total := 0.0
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) == 153:
			total += _growth_of(session, uid)
	return total / 100.0


static func note_growth_round(session: GameSession) -> void:
	for unit in _owned_units(session):
		for uid in unit.equipped_relic_uids:
			var relic_id := session.relic_id_of(uid)
			if relic_id == 143:
				_add_growth(session, uid, _value(143, "与ダメージ"))
			elif relic_id == 147:
				_add_growth(session, uid, _value(147, "与ダメージ"))
			elif relic_id == 159:
				if session.win_streak > 0:
					_add_growth(session, uid, _value(159, "連勝"))
				elif session.loss_streak > 0:
					_add_growth(session, uid, _value(159, "連敗"))


static func note_level_growth(session: GameSession, steps: int) -> void:
	if steps <= 0:
		return
	for unit in _owned_units(session):
		for uid in unit.equipped_relic_uids:
			if session.relic_id_of(uid) == 152:
				_add_growth(session, uid, _value(152, "与ダメージ") * float(steps))


static func note_equipped_star(session: GameSession, unit: GameUnit) -> void:
	if unit == null:
		return
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) == 151:
			_add_growth(session, uid, _value(151, "与ダメージ"))


static func note_growth_kill(session: GameSession, killer: GameUnit, deployed: Array) -> void:
	if killer != null:
		for uid in killer.equipped_relic_uids:
			var relic_id := session.relic_id_of(uid)
			if relic_id == 141:
				_add_growth(session, uid, _value(141, "与ダメージ"))
			elif relic_id == 157:
				_heal_from_kill(session, uid)
	for entry in deployed:
		var ally := entry as GameUnit
		if ally == null:
			continue
		for uid in ally.equipped_relic_uids:
			if session.relic_id_of(uid) != 145:
				continue
			var key := "自分" if ally == killer else "味方"
			_add_growth(session, uid, _value(145, key))


static func note_row_survivors(session: GameSession, front: Array, back: Array) -> void:
	for entry in front:
		var unit := entry as GameUnit
		if unit == null:
			continue
		for uid in unit.equipped_relic_uids:
			if session.relic_id_of(uid) == 153:
				_add_growth(session, uid, _value(153, "軽減"))
	for entry in back:
		var unit := entry as GameUnit
		if unit == null:
			continue
		for uid in unit.equipped_relic_uids:
			if session.relic_id_of(uid) == 154:
				_add_growth(session, uid, _value(154, "与ダメージ"))


static func note_battle_started(session: GameSession) -> void:
	arm_battle_slides(session)
	for item in session.relics:
		if int(item.get("id", -1)) == 157:
			item["battle_heal"] = 0


static func note_gold_spent(session: GameSession, amount: int) -> void:
	if amount <= 0:
		return
	var step := maxi(int(_value(150, "ゴールド")), 1)
	for unit in _owned_units(session):
		for uid in unit.equipped_relic_uids:
			if session.relic_id_of(uid) != 150:
				continue
			var item := _item(session, uid)
			if item.is_empty():
				continue
			var paid := int(item.get("paid", 0)) + amount
			var stacks := paid / step
			item["paid"] = paid % step
			if stacks > 0:
				_add_growth(session, uid, float(stacks) * _value(150, "与ダメージ"))


static func _add_growth(session: GameSession, uid: int, percent: float) -> void:
	if percent <= 0.0:
		return
	var item := _item(session, uid)
	if item.is_empty():
		return
	var extra := 0.0
	if int(item.get("id", -1)) != 155:
		extra = _growth_bonus(session, uid)
	item["growth"] = float(item.get("growth", 0.0)) + percent + extra


static func _growth_bonus(session: GameSession, uid: int) -> float:
	var owner := _equipped_owner(session, uid)
	if owner == null:
		return 0.0
	var extra := 0.0
	for other in owner.equipped_relic_uids:
		if other == uid or session.relic_id_of(other) != 155:
			continue
		extra += _value(155, "追加")
	return extra


static func _heal_from_kill(session: GameSession, uid: int) -> void:
	var item := _item(session, uid)
	if item.is_empty():
		return
	var used := int(item.get("battle_heal", 0))
	var cap := int(_value(157, "上限"))
	if used >= cap:
		return
	var heal := mini(int(_value(157, "HP")), cap - used)
	session.player_hp = mini(player_max_hp(session), session.player_hp + heal)
	item["battle_heal"] = used + heal


static func _growth_of(session: GameSession, uid: int) -> float:
	return float(_item(session, uid).get("growth", 0.0))


## 与ダメージを積む「ラウンドをまたぐ成長」。ギター(156)が換えられるのもこれだけ。
const DAMAGE_GROWTH_IDS: Array[int] = [141, 143, 144, 145, 146, 147, 149, 150, 151, 152, 154, 159, 160]


static func _is_damage_growth(relic_id: int) -> bool:
	return DAMAGE_GROWTH_IDS.has(relic_id)


static func _owned_units(session: GameSession) -> Array:
	var host := session.get_parent()
	if host == null or host.get("board") == null:
		return []
	return host.board.get_all_units()


static func _equipped_owner(session: GameSession, uid: int) -> GameUnit:
	for unit in _owned_units(session):
		if unit != null and unit.equipped_relic_uids.has(uid):
			return unit
	return null


static func strip_equipped_uid(session: GameSession, uid: int) -> void:
	if uid < 0:
		return
	for unit in _owned_units(session):
		if unit == null or unit.equipped_relic_uids.is_empty():
			continue
		while unit.equipped_relic_uids.has(uid):
			unit.equipped_relic_uids.erase(uid)


static func note_star_ups(session: GameSession, times: int) -> void:
	if times <= 0:
		return
	session.free_rerolls += times * _count(session, 80) * int(_value(80, "無料更新"))


static func _dearest_slot(session: GameSession) -> int:
	var best := -1
	var slot := -1
	for index in session.shop_unit_ids.size():
		var unit_id := session.shop_unit_ids[index]
		if unit_id < 0:
			continue
		var cost := int(UnitCatalog.get_unit(unit_id)["cost"])
		if cost > best:
			best = cost
			slot = index
	return slot


static func _roll_slot_discount(session: GameSession) -> void:
	session.relic_076_slots.clear()
	var picks := _count(session, 76)
	if picks <= 0 or session.shop_unit_ids.is_empty():
		return
	for _i in picks:
		session.relic_076_slots.append(randi() % session.shop_unit_ids.size())


static func _spend_timed_gold(session: GameSession, relic_id: int) -> int:
	var gold := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		gold += int(_value(relic_id, "ゴールド"))
		item["left"] = left - 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return gold


static func _refill_to_cap(session: GameSession) -> int:
	var cap := maxi(session.get_level(), 1) * 10
	var virtual := session.coins
	var gold := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 77:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		if virtual >= cap:
			break
		var gap := cap - virtual
		gold += gap
		virtual += gap
		item["left"] = left - 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return gold


static func _coyote_rerolls(session: GameSession) -> int:
	var copies := _count(session, 63)
	if copies <= 0:
		return 0
	var held := session.coins
	var each := 0
	if held >= int(_value(63, "多い段")):
		each = 2
	elif held >= int(_value(63, "少ない段")):
		each = 1
	return copies * each


static func _consume_one(session: GameSession, relic_id: int) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		session.take_relic(int(item.get("uid", -1)))
		return


## 異種合成と同じ合成上限。基本はレベル-3。自動起動・雨粒・特質の加算を含む。
static func synth_cost_cap(session: GameSession) -> int:
	var cap := session.get_level() - 3
	cap += _count(session, 101) * int(_value(101, "上限"))
	cap += _charges(session, 116) * int(_value(116, "上限"))
	cap += _count(session, 264) * int(_value(264, "上限"))
	return clampi(cap, 1, ShopOdds.MAX_COST)


static func blocks_interest(session: GameSession) -> bool:
	return _count(session, 93) > 0 or _count(session, 255) > 0


static func deploy_bonus(session: GameSession) -> int:
	return (
		_count(session, 91) * int(_value(91, "出撃"))
		+ _count(session, 253) * int(_value(253, "出撃"))
		+ _count(session, 314) * int(_value(314, "出撃"))
	)


static func hp_exp_cost(session: GameSession) -> int:
	if _count(session, 254) > 0:
		return int(_value(254, "HP"))
	if _count(session, 95) <= 0:
		return 0
	return int(_value(95, "HP"))


static func player_max_hp(session: GameSession) -> int:
	var bonus := 0
	bonus += _count(session, 171) * int(_value(171, "最大HP"))
	bonus += int(round(float(PlayerHp.INITIAL_HP) * _count(session, 260) * _value(260, "最大HP") / 100.0))
	return PlayerHp.INITIAL_HP + bonus


static func blocks_paid_reroll(session: GameSession) -> bool:
	return _count(session, 258) > 0


static func shop_odds_level(session: GameSession, paid_gold: bool) -> int:
	var level := session.get_level()
	var bonus := 0
	if _charges(session, 96) > 0:
		bonus = 1
	if paid_gold and _charges(session, 100) > 0:
		bonus = maxi(bonus, 1)
	## 260 レコードの低下を先に引いてから、ラジオ・通過の+1を足す。
	level = maxi(1, level - _count(session, 260) * int(_value(260, "レベル低下")))
	level += bonus
	return clampi(level, 1, ShopOdds.TABLE_LEVELS)


static func apply_hologram(session: GameSession, before: int) -> void:
	if _count(session, 97) <= 0 or before >= 9 or session.get_level() < 9:
		return
	var gate := PlayerLevel.xp_to_reach(10)
	if session.experience < gate:
		session.experience = gate
	_consume_all(session, 97)


static func round_start_experience(session: GameSession) -> int:
	var xp := _spend_timed_xp(session, 85)
	xp += _count(session, 93) * int(_value(93, "経験値"))
	xp += _count(session, 254) * int(_value(254, "毎ラウンド"))
	xp += _count(session, 302) * int(_value(302, "経験値"))
	xp += _advance_pilot(session)
	return xp


static func _remember_unit(session: GameSession, item: Dictionary) -> void:
	var pool := UnitCatalog.get_unit_ids_by_cost(int(_value(94, "コスト")))
	if pool.is_empty():
		return
	var unit_id := pool[randi() % pool.size()]
	item["memory"] = unit_id
	_queue_unit(session, unit_id, 1)


static func _grant_hologram_now(session: GameSession, uid: int) -> void:
	var before := session.get_level()
	if before >= 10:
		session.take_relic(uid)
		return
	if before < 9:
		return
	var gate := PlayerLevel.xp_to_reach(10)
	if session.experience < gate:
		session.experience = gate
	session.take_relic(uid)
	var after := session.get_level()
	if after > before:
		note_level_up(session, before, after)


static func _copy_board_unit(session: GameSession) -> void:
	var copies := _count(session, 86)
	if copies <= 0 or session.shop_unit_ids.is_empty():
		return
	var host := session.get_parent()
	if host == null or host.get("board") == null:
		return
	var allies: Array[int] = []
	for unit in host.board.get_circle_units():
		if unit != null:
			allies.append(unit.unit_id)
	if allies.is_empty():
		return
	for _i in copies:
		var slot := randi() % session.shop_unit_ids.size()
		session.shop_unit_ids[slot] = allies[randi() % allies.size()]


static func _queue_unit(session: GameSession, unit_id: int, stars: int) -> void:
	if UnitCatalog.get_unit(unit_id).is_empty():
		return
	session.relic_pending_units.append({"id": unit_id, "stars": stars})


static func _consume_all(session: GameSession, relic_id: int) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)


static func _spend_each(session: GameSession, relic_id: int, amount: int) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		item["left"] = left - amount
		if left - amount <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)


static func _spend_timed_xp(session: GameSession, relic_id: int) -> int:
	var xp := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		xp += int(_value(relic_id, "経験値"))
		item["left"] = left - 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return xp


static func _advance_pilot(session: GameSession) -> int:
	var xp := 0
	var interval := maxi(int(_value(98, "間隔")), 1)
	for item in session.relics:
		if int(item.get("id", -1)) != 98:
			continue
		var age := int(item.get("age", 1)) + 1
		item["age"] = age
		if age % interval != 0:
			continue
		xp += int(_value(98, "経験値"))
		session.free_rerolls += int(_value(98, "無料更新"))
	return xp


static func _count(session: GameSession, relic_id: int) -> int:
	var count := 0
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id:
			count += 1
	return count


static func _charges(session: GameSession, relic_id: int) -> int:
	var count := 0
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id and int(item.get("left", 0)) > 0:
			count += 1
	return count


static func _spend_charges(session: GameSession, relic_id: int, times: int) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		if times <= 0:
			break
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		var spend := mini(left, times)
		item["left"] = left - spend
		times -= spend
		if left - spend <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)


static func _item(session: GameSession, uid: int) -> Dictionary:
	for item in session.relics:
		if int(item.get("uid", -1)) == uid:
			return item
	return {}


static func note_ally_down(session: GameSession) -> void:
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 286:
			continue
		if int(item.get("grants", 0)) >= int(_value(286, "上限")):
			continue
		item["progress"] = int(item.get("progress", 0)) + 1
		if int(item.get("progress", 0)) < int(_value(286, "進捗")):
			continue
		item["progress"] = 0
		item["grants"] = int(item.get("grants", 0)) + 1
		_queue_random_relic(session)
		if int(item.get("grants", 0)) >= int(_value(286, "上限")):
			session.take_relic(int(item.get("uid", -1)))


static func note_streak_quests(session: GameSession) -> void:
	if session.win_streak >= int(_value(296, "連勝")):
		for item in session.relics.duplicate():
			if int(item.get("id", -1)) != 296 or not bool(item.get("armed", false)):
				continue
			session.add_coins(int(_value(296, "ゴールド")))
			session.free_rerolls += int(_value(296, "無料更新"))
			session.take_relic(int(item.get("uid", -1)))
	if session.loss_streak >= int(_value(297, "連敗")):
		for item in session.relics.duplicate():
			if int(item.get("id", -1)) != 297 or not bool(item.get("armed", false)):
				continue
			session.add_coins(int(_value(297, "ゴールド")))
			_grant_random_where(session, _is_guard_relic)
			session.take_relic(int(item.get("uid", -1)))


static func note_duplicate_name(session: GameSession, relic_id: int) -> void:
	if _count(session, 307) <= 0:
		return
	var name := str(RelicCatalog.get_relic(relic_id).get("name", ""))
	var owned := 0
	for item in session.relics:
		if str(RelicCatalog.get_relic(int(item.get("id", -1))).get("name", "")) == name:
			owned += 1
	if owned >= 2:
		session.add_coins(_count(session, 307) * int(_value(307, "ゴールド")))


static func _trigger_merge_copy(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 178 or not bool(item.get("seed", false)):
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		item["left"] = left - 1
		## 回数を使い切っても、手元の落語そのものは残る。
		session.add_relic(178, {"from_copy": true, "seed": false})
		return


static func _grant_star3_quest(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 299:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		session.add_coins(int(_value(299, "ゴールド")))
		item["left"] = left - 1
		if left - 1 <= 0:
			session.take_relic(int(item.get("uid", -1)))
		return


static func _check_level_quest(session: GameSession) -> void:
	if session.get_level() < int(_value(298, "レベル")):
		return
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 298 or not bool(item.get("armed", false)):
			continue
		session.take_relic(int(item.get("uid", -1)))
		_grant_random_where(session, func(relic_id: int) -> bool:
			return _category(relic_id) == "合成装備レベルの強さ"
		)


static func _advance_grant_rounds(session: GameSession) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		var relic_id := int(item.get("id", -1))
		if relic_id == 285:
			var left := int(item.get("left", 0))
			if left <= 0:
				continue
			_queue_random_relic(session)
			item["left"] = left - 1
			if left - 1 <= 0:
				remove.append(int(item.get("uid", -1)))
		elif relic_id == 261:
			var fights := int(item.get("left", 0))
			if fights <= 0:
				continue
			# counted down on battle end instead
			pass
	for uid in remove:
		session.take_relic(uid)


static func note_battle_finished(session: GameSession, won: bool) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 261:
			continue
		var left := int(item.get("left", 0)) - 1
		item["left"] = left
		if left > 0:
			continue
		session.add_coins(int(_value(261, "ゴールド")))
		remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	if not won and _count(session, 172) > 0:
		var missing := maxi(player_max_hp(session) - session.player_hp, 0)
		var heal := int(round(float(missing) * float(_count(session, 172)) * _value(172, "回復") / 100.0))
		session.player_hp = mini(player_max_hp(session), session.player_hp + heal)
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 259:
			continue
		if won:
			item["armed"] = true
		elif bool(item.get("armed", false)):
			session.take_relic(int(item.get("uid", -1)))
	note_streak_quests(session)


static func _resolve_timed_bank(session: GameSession) -> int:
	var gold := 0
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) != 263:
			continue
		var left := int(item.get("left", 0)) - 1
		item["left"] = left
		if left > 0:
			continue
		gold += int(item.get("bank", 0)) + int(_value(263, "追加"))
		remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return gold


static func _toggle_round_relics(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 279:
			continue
		item["mode"] = 1 - int(item.get("mode", 0))


static func relic_279_outgoing(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var total := 0.0
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) != 279:
			continue
		var item := _item(session, uid)
		if int(item.get("mode", 0)) == 0:
			total += _value(279, "与ダメージ")
	return total / 100.0


static func trigger_shinan(session: GameSession) -> void:
	if _count(session, 301) <= 0:
		return
	## 指南で入った1つでは、指南はもう発動しない。
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if not pool.is_empty():
		session.add_relic(pool[randi() % pool.size()], {"from_shinan": true})


static func _queue_random_relic(session: GameSession) -> void:
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if pool.is_empty():
		return
	session.add_relic(pool[randi() % pool.size()])


static func _value(relic_id: int, key: String) -> float:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	return float(effects.get(key, 0.0))


# ---------------------------------------------------------------------------
# 戦闘結果まわり。対人戦は無いので「プレイヤー同士の戦闘」はラウンドの戦闘として扱う。
# ---------------------------------------------------------------------------

## 戦闘終了時に勝敗と戦闘中の記録(stats)を受け取る。stats は BattleDirector.play() の "relic_stats"。
static func note_battle_outcome(session: GameSession, won: bool, stats: Dictionary) -> void:
	_apply_outcome_gold(session, won, int(stats.get("alive_allies", 0)))
	_apply_outcome_growth(session, won, stats.get("units", []))
	_apply_outcome_quests(session, stats)
	_apply_outcome_removals(session, won)
	_advance_homecoming(session, won)
	_note_slide(session, won)
	if won:
		session.relic_139_pending = _count(session, 139) * int(_value(139, "値引き"))


static func _apply_outcome_gold(session: GameSession, won: bool, alive_allies: int) -> void:
	var xp := 0
	if won:
		xp += _count(session, 87) * int(_value(87, "勝ち"))
		session.add_coins(_count(session, 122) * int(_value(122, "ゴールド")))
		var per := maxi(int(_value(129, "人数")), 1)
		session.add_coins(_count(session, 129) * (alive_allies / per) * int(_value(129, "ゴールド")))
		if session.win_streak >= int(_value(134, "連勝")):
			xp += _count(session, 134) * int(_value(134, "経験値"))
	else:
		xp += _count(session, 87) * int(_value(87, "負け"))
		session.add_coins(_count(session, 121) * int(_value(121, "ゴールド")))
		session.free_rerolls += _count(session, 121) * int(_value(121, "無料更新"))
		if session.loss_streak >= int(_value(135, "連敗")):
			session.free_rerolls += _count(session, 135) * int(_value(135, "無料更新"))
	if xp > 0:
		session.gain_experience(xp)


## 142・144・146・149・160: 装備者の戦闘結果で積みが増える。
static func _apply_outcome_growth(session: GameSession, _won: bool, units: Array) -> void:
	for entry in units:
		var row: Dictionary = entry
		var unit := row.get("unit") as GameUnit
		if unit == null or not is_instance_valid(unit):
			continue
		var survived := bool(row.get("survived", false))
		for uid in unit.equipped_relic_uids:
			match session.relic_id_of(uid):
				142:
					if survived:
						var item := _item(session, uid)
						item["hp_growth"] = float(item.get("hp_growth", 0.0)) + _value(142, "最大体力") + _growth_bonus(session, uid)
				144:
					var step := maxi(int(_value(144, "ダメージ")), 1)
					var stacks := int(row.get("dealt", 0)) / step
					if stacks > 0:
						_add_growth(session, uid, float(stacks) * _value(144, "与ダメージ"))
				146:
					if survived:
						_add_growth(session, uid, _value(146, "与ダメージ"))
				149:
					if bool(row.get("dipped", false)):
						_add_growth(session, uid, _value(149, "与ダメージ"))
				160:
					if bool(row.get("died", false)):
						_add_growth(session, uid, _value(160, "与ダメージ"))


## 戦闘中の数を持ち越しで数えるクエスト（166・287〜291・184・300）。
static func _apply_outcome_quests(session: GameSession, stats: Dictionary) -> void:
	var team_max := maxi(int(stats.get("team_max", 0)), 1)
	if _count(session, 166) > 0:
		session.relic_166_bank += int(stats.get("team_taken", 0))
		var gate := maxi(1, int(ceil(float(team_max) * _value(166, "閾値") / 100.0)))
		while session.relic_166_bank >= gate:
			session.relic_166_bank -= gate
			session.add_relic(166)
	_progress_quest(session, 287, int(stats.get("team_dealt", 0)), team_max * int(_value(287, "倍率")), 2, _is_strike_relic)
	_progress_quest(session, 288, int(stats.get("team_taken", 0)), team_max * int(_value(288, "倍率")), 2, _is_guard_relic)
	_progress_quest(session, 289, int(stats.get("crits", 0)), int(_value(289, "進捗")), 2, _is_crit_relic)
	_progress_quest(session, 290, int(stats.get("hits", 0)), int(_value(290, "進捗")), 2, _is_speed_relic)
	_progress_quest(session, 291, int(stats.get("gauge_spent", 0)), int(_value(291, "ゲージ")), 2, _is_gauge_relic)
	var broken := int(stats.get("devices_broken", 0))
	if broken > 0:
		_progress_quest(session, 184, broken, int(_value(184, "回数")), 1, _is_guard_relic)
		for item in session.relics.duplicate():
			if int(item.get("id", -1)) != 300:
				continue
			item["progress"] = int(item.get("progress", 0)) + broken
			if int(item.get("progress", 0)) >= int(_value(300, "進捗")):
				session.take_relic(int(item.get("uid", -1)))
				session.add_relic(181)
				session.add_relic(181)


## 進捗を足して、届いたら pick に合うレリックを count 個入れてこのレリックを消す。
static func _progress_quest(session: GameSession, relic_id: int, amount: int, goal: int, count: int, pick: Callable) -> void:
	if amount <= 0:
		return
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != relic_id:
			continue
		item["progress"] = int(item.get("progress", 0)) + amount
		if int(item.get("progress", 0)) < maxi(goal, 1):
			continue
		session.take_relic(int(item.get("uid", -1)))
		for _i in count:
			_grant_random_where(session, pick)


static func _apply_outcome_removals(session: GameSession, won: bool) -> void:
	if won:
		_consume_all(session, 132)
		_consume_all(session, 136)
	else:
		_consume_all(session, 131)
		_consume_all(session, 137)


## 192 帰宅: ラウンドごとに1、勝つとさらに1減る。0でゴールドとレリック。
static func _advance_homecoming(session: GameSession, won: bool) -> void:
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 192:
			continue
		var left := int(item.get("left", int(_value(192, "ラウンド")))) - 1
		if won:
			left -= 1
		item["left"] = left
		if left > 0:
			continue
		session.take_relic(int(item.get("uid", -1)))
		session.add_coins(int(_value(192, "ゴールド")))
		_queue_random_relic(session)


## 138 スライド: 負けたら次の1戦闘だけ味方全員の与ダメージが上がる。
static func _note_slide(session: GameSession, won: bool) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 138:
			continue
		item["slide_active"] = false
		item["slide_ready"] = not won


static func arm_battle_slides(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 138:
			continue
		item["slide_active"] = bool(item.get("slide_ready", false))
		item["slide_ready"] = false


static func slide_outgoing(session: GameSession) -> float:
	var bonus := 0.0
	for item in session.relics:
		if int(item.get("id", -1)) == 138 and bool(item.get("slide_active", false)):
			bonus += _value(138, "与ダメージ") / 100.0
	return bonus


## 123 羅針: 連勝・連敗の増え方が倍になる。
static func streak_step(session: GameSession) -> int:
	var step := 1
	for _i in _count(session, 123):
		step *= int(_value(123, "倍率"))
	return maxi(step, 1)


## 128 レオニード: 敗北のプレイヤーダメージが減る。最低1。
static func loss_damage(session: GameSession, damage: int) -> int:
	if damage <= 0:
		return damage
	## 091 パラダイス！は+1、253 断層は倍。128 レオニードは-1で最低1。
	damage += _count(session, 91) * int(_value(91, "ダメージ"))
	for _i in _count(session, 253):
		damage *= int(_value(253, "倍率"))
	var cut := _count(session, 128) * int(_value(128, "ダメージ"))
	if cut > 0:
		damage = maxi(1, damage - cut)
	return damage


## 090 パレード: プレイヤーレベルの上限が上がる。
static func level_cap(session: GameSession) -> int:
	if _count(session, 90) > 0:
		return PlayerLevel.MAX_LEVEL + int(_value(90, "上限"))
	return PlayerLevel.MAX_LEVEL


## 142 ゼリー: 積んだ最大体力の割合（%）。
static func growth_max_hp(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var total := 0.0
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) == 142:
			total += float(_item(session, uid).get("hp_growth", 0.0))
	return total


## 180 レジャーで入った複製（コマーシャル相当）の最大体力（%）。
static func leisure_max_hp(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var total := 0.0
	for uid in unit.equipped_relic_uids:
		var item := _item(session, uid)
		if bool(item.get("leisure_copy", false)):
			total += float(item.get("max_hp_rate", 0.0))
	return total


static func note_free_reroll_used(session: GameSession) -> void:
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 294:
			continue
		item["progress"] = int(item.get("progress", 0)) + 1
		if int(item.get("progress", 0)) >= int(_value(294, "進捗")):
			session.take_relic(int(item.get("uid", -1)))
			session.add_relic(62)


static func note_exp_purchase(session: GameSession) -> void:
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 295:
			continue
		item["progress"] = int(item.get("progress", 0)) + 1
		if int(item.get("progress", 0)) >= int(_value(295, "進捗")):
			session.take_relic(int(item.get("uid", -1)))
			_grant_random_where(session, func(relic_id: int) -> bool:
				return _category(relic_id) == "経験値・レベル・出現率"
			)


static func note_same_merge_quest(session: GameSession) -> void:
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 292:
			continue
		item["progress"] = int(item.get("progress", 0)) + 1
		if int(item.get("progress", 0)) >= int(_value(292, "進捗")):
			session.take_relic(int(item.get("uid", -1)))
			session.add_relic(103 if randi() % 2 == 0 else 104)


## 309 幻想: レリックを合成したとき、さらに1つ入る（指南は発動しない）。
static func note_relic_synthesized(session: GameSession) -> void:
	for _i in _count(session, 309):
		var pool: Array[int] = RelicCatalog.all_pick_ids()
		if pool.is_empty():
			return
		session.add_relic(pool[randi() % pool.size()], {"from_shinan": true})


## 183 横車: 攻撃を受ける装置が壊れたとき。1戦闘の回数は戦闘側で数える。
static func device_break_gold(session: GameSession) -> int:
	return _count(session, 183) * int(_value(183, "ゴールド"))


static func _grant_random_where(session: GameSession, pick: Callable) -> void:
	var pool: Array[int] = []
	for relic_id in RelicCatalog.all_pick_ids():
		if bool(pick.call(relic_id)):
			pool.append(relic_id)
	if pool.is_empty():
		_queue_random_relic(session)
		return
	session.add_relic(pool[randi() % pool.size()])


static func _category(relic_id: int) -> String:
	return str(RelicCatalog.get_relic(relic_id).get("category", ""))


static func _has_effect_key(relic_id: int, needles: Array) -> bool:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	for key in effects.keys():
		for needle in needles:
			if str(key).find(str(needle)) >= 0:
				return true
	return false


static func _is_strike_relic(relic_id: int) -> bool:
	return _category(relic_id) == "合成装備レベルの強さ" and _has_effect_key(relic_id, ["与ダメージ", "貫通", "クリティカル"])


static func _is_guard_relic(relic_id: int) -> bool:
	return _category(relic_id) == "(プレイヤーもキャラクターも)HP、防御の増強、回復"


static func _is_crit_relic(relic_id: int) -> bool:
	return _has_effect_key(relic_id, ["クリティカル率", "クリティカルダメージ"])


static func _is_speed_relic(relic_id: int) -> bool:
	return _has_effect_key(relic_id, ["速度"])


static func _is_gauge_relic(relic_id: int) -> bool:
	return _has_effect_key(relic_id, ["ゲージ"])


# ---------------------------------------------------------------------------
# 手で使うレリック（レリックをクリックして使う）。
# ---------------------------------------------------------------------------

const USE_NONE := ""
const USE_NOW := "now"
const USE_UNIT := "unit"
const USE_RELIC := "relic"
## 消費の対象にできないもの: 階段1・2・3、クロージャ。
const UNCONSUMABLE: Array[int] = [312, 313, 314, 302]


## そのレリックの使い方。USE_NONE は使えない。
static func use_mode(session: GameSession, uid: int) -> String:
	var item := _item(session, uid)
	if item.is_empty():
		return USE_NONE
	match int(item.get("id", -1)):
		103, 104, 190, 156:
			return USE_UNIT
		191:
			return USE_NOW if item.has("egg") else USE_UNIT
		180:
			if bool(item.get("leisure_copy", false)) or session.relic_180_used >= int(_value(180, "回数")):
				return USE_NONE
			return USE_NOW
		303, 304, 305, 306:
			return USE_RELIC
	return USE_NONE


## 使う前の確認文。
static func use_prompt(session: GameSession, uid: int) -> String:
	var relic_id := session.relic_id_of(uid)
	match relic_id:
		103, 104:
			return "複製するキャラクターを選んでください（コスト%d以下）" % int(_value(relic_id, "上限コスト"))
		190:
			return "次の戦闘でコピーを出すサークルの味方を選んでください"
		191:
			if _item(session, uid).has("egg"):
				return "卵を割って、入れたときの星で控えに戻しますか？"
			return "卵に入れるキャラクターを選んでください"
		156:
			return "ギターを付けるキャラクターを選んでください。付いている成長の与ダメージをゴールドに換えます"
		180:
			return "レジャーを1つ消費して、最大体力のレリックを2つ得ますか？"
		303, 304, 305, 306:
			return "消すレリックを選んでください"
	return ""


## 156 ギター: 装備者の成長レリックを換えたときのゴールド。
static func guitar_gold(session: GameSession, owner: GameUnit) -> int:
	if owner == null:
		return 0
	var percent := 0.0
	for other in owner.equipped_relic_uids:
		if _is_damage_growth(session.relic_id_of(other)):
			percent += _growth_of(session, other)
	return int(floor(percent)) * int(_value(156, "ゴールド"))


## 対象のいらない使用。成功したら true。
static func use_now(session: GameSession, uid: int) -> bool:
	var item := _item(session, uid)
	if item.is_empty():
		return false
	match int(item.get("id", -1)):
		180:
			if use_mode(session, uid) != USE_NOW:
				return false
			session.relic_180_used += 1
			session.take_relic(uid)
			for _i in int(_value(180, "回数")):
				session.add_relic(180, {"leisure_copy": true, "max_hp_rate": _value(180, "最大体力"), "from_shinan": true})
			return true
		191:
			if not item.has("egg"):
				return false
			var egg: Dictionary = item["egg"]
			item.erase("egg")
			_queue_unit(session, int(egg.get("id", -1)), int(egg.get("stars", 1)))
			return true
	return false


## キャラクターを対象にする使用（103・104・190・191）。成功したら true。
static func use_on_unit(session: GameSession, uid: int, unit: GameUnit) -> bool:
	var item := _item(session, uid)
	if item.is_empty() or unit == null or unit.is_enemy:
		return false
	var relic_id := int(item.get("id", -1))
	match relic_id:
		103, 104:
			if unit.get_cost() > int(_value(relic_id, "上限コスト")):
				return false
			_queue_unit(session, unit.unit_id, unit.stars)
			session.take_relic(uid)
			return true
		190:
			if unit.circle_slot < 0:
				return false
			item["copy_unit"] = unit.get_instance_id()
			return true
		156:
			## ギターは装備しているキャラクターにだけ効く。付いていなければ付ける。
			if not unit.equipped_relic_uids.has(uid):
				if unit.equipped_relic_uids.size() >= GameUnit.RELIC_EQUIP_CAP:
					return false
				strip_equipped_uid(session, uid)
				unit.equipped_relic_uids.append(uid)
			var gold := guitar_gold(session, unit)
			for other in unit.equipped_relic_uids:
				if _is_damage_growth(session.relic_id_of(other)):
					_item(session, other)["growth"] = 0.0
			session.add_coins(gold)
			return true
		191:
			if item.has("egg"):
				return false
			item["egg"] = {"id": unit.unit_id, "stars": unit.stars, "left": int(_value(191, "ラウンド"))}
			return true
	return false


## レリックを消す使用（303〜306）。成功したら true。
static func use_on_relic(session: GameSession, uid: int, target_uid: int) -> bool:
	var relic_id := session.relic_id_of(uid)
	var target_id := session.relic_id_of(target_uid)
	if target_id <= 0 or UNCONSUMABLE.has(target_id):
		return false
	if not [303, 304, 305, 306].has(relic_id):
		return false
	if target_uid != uid:
		session.take_relic(target_uid)
	session.take_relic(uid)
	match relic_id:
		303:
			session.add_coins(int(_value(303, "ゴールド")))
		304:
			session.gain_experience(int(_value(304, "経験値")))
		305:
			session.free_rerolls += int(_value(305, "無料更新"))
		306:
			session.player_hp = mini(player_max_hp(session), session.player_hp + int(_value(306, "HP")))
	return true


## 191 見学: ラウンドが進むと卵が割れて、星が1段高く戻る。
static func advance_eggs(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 191 or not item.has("egg"):
			continue
		var egg: Dictionary = item["egg"]
		egg["left"] = int(egg.get("left", 1)) - 1
		if int(egg["left"]) > 0:
			continue
		item.erase("egg")
		_queue_unit(session, int(egg.get("id", -1)), mini(int(egg.get("stars", 1)) + 1, GameUnit.MAX_STARS))


## 190 破壊: 選んだ味方（インスタンスID）。戦闘で使ったら消える。
static func take_destruction_targets(session: GameSession) -> Array[int]:
	var out: Array[int] = []
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 190 or not item.has("copy_unit"):
			continue
		out.append(int(item["copy_unit"]))
		session.take_relic(int(item.get("uid", -1)))
	return out



## サークルにいるキャラクターが装備している枚数（207 七曲り・209 讃歌）。
static func _circle_bearers(session: GameSession, relic_id: int) -> int:
	var host := session.get_parent()
	if host == null or host.get("board") == null:
		return 0
	var count := 0
	for unit in host.board.get_circle_units():
		if unit == null or unit.kit_flags.has("relic_temp"):
			continue
		for uid in unit.equipped_relic_uids:
			if session.relic_id_of(uid) == relic_id:
				count += 1
	return count


## 持っているだけで味方全員の受けるダメージが下がるもの（259・302・313）。継続ダメージにも入る。
static func owned_taken_cut(session: GameSession) -> float:
	var cut := 0.0
	if session.win_streak > 0:
		cut += float(_count(session, 259)) * _value(259, "受けるダメージ") / 100.0
	cut += float(_count(session, 302)) * _value(302, "受けるダメージ") / 100.0
	cut += float(_count(session, 313)) * _value(313, "受けるダメージ") / 100.0
	return cut


## 256 仇討ち: 味方全員の最大体力が下がる（%）。
static func owned_max_hp_cut(session: GameSession) -> float:
	return float(_count(session, 256)) * _value(256, "最大体力")


## 279 遊牧: 回復のラウンドで、命中したときに戻る割合。
static func nomad_heal_ratio(session: GameSession, unit: GameUnit) -> float:
	if unit == null:
		return 0.0
	var ratio := 0.0
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) == 279 and int(_item(session, uid).get("mode", 0)) == 1:
			ratio += _value(279, "回復") / 100.0
	return ratio


## 077 再呼び出し: 収入のあとに、上限まで足りないぶんを入れる。
static func refill_after_income(session: GameSession) -> void:
	var gold := _refill_to_cap(session)
	if gold > 0:
		session.add_coins(gold)


## 302 クロージャ: 階段1・2・3をすべて持ったら入る。一度入ったら残る。
static func check_closure(session: GameSession) -> void:
	if _count(session, 302) > 0:
		return
	if _count(session, 312) > 0 and _count(session, 313) > 0 and _count(session, 314) > 0:
		session.add_relic(302, {"from_shinan": true})


## 058 誤操作: ラウンド開始時に自動で入れ直す回数。
static func auto_refresh_count(session: GameSession) -> int:
	return _count(session, 58) * int(_value(58, "更新"))
