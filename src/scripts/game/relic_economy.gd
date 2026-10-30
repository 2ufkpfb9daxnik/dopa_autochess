class_name RelicEconomy
extends RefCounted

## 056 回収: ほかのレリックを売ったときゴールドが増える。レリックを売る操作がまだ無いので未適用。
## 075 舞台が終わる: ロックした枠だけ残す更新。枠ごとのロックが無く、ショップ全体のロックしか無いので未適用。
## 087 達人: プレイヤー同士の戦闘が無く、対CPU戦しか無いので未適用。
## 090 パレード: レベル21までの必要経験値が書かれていないので未適用。
## 091 パラダイス！のプレイヤーダメージ: プレイヤー同士の敗北が無いので、出撃上限だけ適用する。
## 101・105・107・110・113・115・116・119: 異種合成がまだ無いので未適用。
## 103・104・108: キャラクターを選んで使う操作がまだ無いので未適用。
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
## 303-306・310: レリックを選んで消費／再抽選するUIが無いので未適用。
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
		117:
			item["left"] = int(_value(117, "回数"))
		124:
			session.win_streak = int(_value(124, "連勝"))
			session.loss_streak = 0
			session.add_coins(int(_value(124, "ゴールド")))
			session.take_relic(uid)
		133:
			item["left"] = int(_value(133, "回数"))
		169:
			if not bool(item.get("rolled", false)):
				item["rolled"] = true
				if randi() % 10 < int(_value(169, "当たり")):
					var bonus_uid := session.add_relic(169)
					var bonus := _item(session, bonus_uid)
					if not bonus.is_empty():
						bonus["rolled"] = true
		170:
			if not bool(item.get("from_copy", false)):
				for _i in int(_value(170, "追加")):
					var copy_uid := session.add_relic(170)
					var copy := _item(session, copy_uid)
					if not copy.is_empty():
						copy["from_copy"] = true
		178:
			if not bool(item.get("seed", false)) and not bool(item.get("from_copy", false)):
				item["seed"] = true
				item["left"] = int(_value(178, "回数"))
			elif bool(item.get("from_copy", false)):
				item["seed"] = false
		207:
			session.add_coins(int(_value(207, "ゴールド")))
		209:
			session.gain_experience(int(_value(209, "経験値")))
		253:
			pass
		254:
			item["hp_exp"] = true
		255:
			item["block_interest"] = true
		258:
			item["block_paid_reroll"] = true
		261:
			session.player_hp = maxi(1, session.player_hp - int(_value(261, "HP")))
			item["left"] = int(_value(261, "戦闘"))
		263:
			item["bank"] = session.coins
			session.coins = 0
			item["left"] = int(_value(263, "ラウンド"))
		285:
			_queue_random_relic(session)
			item["left"] = int(_value(285, "ラウンド"))
		286:
			item["progress"] = 0
			item["grants"] = 0
		296:
			item["armed"] = true
		297:
			item["armed"] = true
		298:
			item["armed"] = true
		299:
			item["left"] = int(_value(299, "回数"))
		301:
			if not bool(item.get("from_copy", false)):
				_queue_random_relic(session)
		307:
			pass
		310:
			pass


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
	return _count(session, 64) * int(_value(64, "利息"))


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
	gold += _refill_to_cap(session)
	gold += _resolve_timed_bank(session)
	session.free_rerolls += _count(session, 61) * int(_value(61, "無料更新"))
	session.free_rerolls += _coyote_rerolls(session)
	session.free_rerolls += _count(session, 258) * int(_value(258, "無料更新"))
	session.free_rerolls += _count(session, 312) * int(_value(312, "無料更新"))
	session.free_rerolls += _count(session, 302) * int(_value(302, "無料更新"))
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
	session.relic_end_xp = end_xp
	_spend_each(session, 96, 1)
	var remove: Array[int] = []
	for uid in session.relic_043_live:
		remove.append(uid)
	session.relic_043_live.clear()
	session.relic_shop_discount = 0
	for uid in remove:
		session.take_relic(uid)


static func on_shop_refreshed(session: GameSession) -> void:
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
		price = int(floor(float(price) * (1.0 - _value(257, "値引き") / 100.0)))
	return maxi(0, price)


static func paid_reroll_cost(session: GameSession) -> int:
	if _count(session, 258) > 0:
		return 999
	var cost := GameSession.REROLL_COST
	if not session.relic_paid_free_used and _count(session, 51) > 0:
		return 0
	cost -= _charges(session, 57) * int(_value(57, "値引き"))
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


static func exp_cost(session: GameSession) -> int:
	if _count(session, 254) > 0:
		return 0
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
		var cost := clampi(after - 4, 1, int(_value(88, "上限コスト")))
		var pool := UnitCatalog.get_unit_ids_by_cost(cost)
		for _i in copies88:
			if not pool.is_empty():
				_queue_unit(session, pool[randi() % pool.size()], 2)
		session.add_coins(copies88 * int(_value(88, "ゴールド")))
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
		session.player_hp = mini(PlayerHp.INITIAL_HP, session.player_hp + heal)
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
	if new_stars >= 3:
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
	return int(round(float(refund) * sell_mult(session)))


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
	session.player_hp = mini(PlayerHp.INITIAL_HP, session.player_hp + heal)
	item["battle_heal"] = used + heal


static func _growth_of(session: GameSession, uid: int) -> float:
	return float(_item(session, uid).get("growth", 0.0))


static func _is_damage_growth(relic_id: int) -> bool:
	return relic_id == 141 or relic_id == 143 or relic_id == 145 or relic_id == 147 or relic_id == 150 or relic_id == 151 or relic_id == 152 or relic_id == 154 or relic_id == 159


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
	level += bonus
	level -= _count(session, 260) * int(_value(260, "レベル低下"))
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
	for item in session.relics:
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
			_queue_random_relic(session)
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
		var copy_uid := session.add_relic(178)
		var copy := _item(session, copy_uid)
		if not copy.is_empty():
			copy["from_copy"] = true
			copy["seed"] = false
		if left - 1 <= 0:
			session.take_relic(int(item.get("uid", -1)))
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
		_queue_random_relic(session)
		session.take_relic(int(item.get("uid", -1)))


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
	if not won and _count(session, 259) > 0:
		_consume_all(session, 259)
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


static func _queue_random_relic(session: GameSession) -> void:
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if pool.is_empty():
		return
	session.add_relic(pool[randi() % pool.size()])


static func _value(relic_id: int, key: String) -> float:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	return float(effects.get(key, 0.0))
