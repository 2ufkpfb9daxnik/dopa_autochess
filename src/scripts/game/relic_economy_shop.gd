extends "res://scripts/game/relic_economy_gold.gd"

## ショップ（値段・更新・出現率）と、キャラクターの売買・合成。
## 継承のつながりは relic_economy_base.gd の先頭を参照。


# ---------------------------------------------------------------------------
# ショップの値段と更新
# ---------------------------------------------------------------------------

static func on_shop_refreshed(session: GameSession) -> void:
	session.relic_139_live = session.relic_139_pending
	session.relic_139_pending = 0
	_copy_board_unit(session)
	## 043: 入手のあと最初の更新で、そのショップだけ値引き。ラウンドの終わりに消える。
	var amount := 0
	for uid in session.relic_043_armed:
		if session.relic_id_of(uid) == 43:
			amount += int(_value(43, "値引き"))
			session.relic_043_live.append(uid)
	session.relic_043_armed.clear()
	session.relic_shop_discount = amount
	_roll_slot_discount(session)
	session.gain_experience(_owned_value(session, 83, "経験値"))


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
	price -= _owned_value(session, 68, "値引き")
	if catalog <= 3:
		price -= _owned_value(session, 69, "値引き")
	if slot_index == session.shop_unit_ids.size() - 1:
		price -= _owned_value(session, 47, "値引き")
	if slot_index == _dearest_slot(session):
		price -= _owned_value(session, 53, "値引き")
	for marked in session.relic_076_slots:
		if int(marked) == slot_index:
			price -= int(_value(76, "値引き"))
	if _count(session, 257) > 0:
		## 端数は切り上げ、最低1。
		return maxi(1, int(ceil(float(price) * (1.0 - _value(257, "値引き") / 100.0))))
	return maxi(0, price)


## いちばん高いキャラクターの枠（053）。同じなら左。
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


## 076: 更新ごとに値引きする枠を選ぶ。
static func _roll_slot_discount(session: GameSession) -> void:
	session.relic_076_slots.clear()
	var picks := _count(session, 76)
	if picks <= 0 or session.shop_unit_ids.is_empty():
		return
	for _i in picks:
		session.relic_076_slots.append(randi() % session.shop_unit_ids.size())


## 086: 更新したショップの枠を、サークルにいる味方に書き換える。
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


static func paid_reroll_cost(session: GameSession) -> int:
	if _count(session, 258) > 0:
		return 999
	var cost := GameSession.REROLL_COST
	if not session.relic_paid_free_used and _count(session, 51) > 0:
		return 0
	cost -= _charges(session, 57) * int(_value(57, "値引き"))
	cost -= _owned_value(session, 131, "値引き")
	return maxi(0, cost)


static func blocks_paid_reroll(session: GameSession) -> bool:
	return _count(session, 258) > 0


static func note_paid_reroll(session: GameSession, paid: int) -> void:
	if not session.relic_paid_free_used and _count(session, 51) > 0:
		session.relic_paid_free_used = true
		return
	_tick_down(session, 57, Callable(), 1)
	if paid <= 0:
		return
	## 062: 10回のうち「当たり」の回数だけ無料更新が入る（引いたら戻さない）。
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
	_tick_down(session, 100)


## 058 誤操作: ラウンド開始時に自動で入れ直す回数。
static func auto_refresh_count(session: GameSession) -> int:
	return _owned_value(session, 58, "更新")


static func shop_odds_level(session: GameSession, paid_gold: bool) -> int:
	var level := session.get_level()
	var bonus := 0
	if _charges(session, 96) > 0:
		bonus = 1
	if paid_gold and _charges(session, 100) > 0:
		bonus = maxi(bonus, 1)
	## 260 レコードの低下を先に引いてから、ラジオ・通過の+1を足す。
	level = maxi(1, level - _owned_value(session, 260, "レベル低下"))
	level += bonus
	return clampi(level, 1, ShopOdds.TABLE_LEVELS)


# ---------------------------------------------------------------------------
# 買う・売る
# ---------------------------------------------------------------------------

static func note_unit_bought(session: GameSession, cost: int, stars: int) -> void:
	var seen := int(session.relic_buy_counts.get(cost, 0)) + 1
	session.relic_buy_counts[cost] = seen
	if seen >= 2 and not session.relic_cost_rewarded.has(cost) and _count(session, 49) > 0:
		session.relic_cost_rewarded[cost] = true
		session.free_rerolls += _owned_value(session, 49, "無料更新")
	if cost >= 5 and cost <= 7:
		session.add_coins(_owned_value(session, 59, "戻りゴールド") * maxi(stars, 1))
	session.free_rerolls += _owned_value(session, 72, "無料更新")
	_consume_one(session, 71)


## 044: 売るたび、残り回数のある1枚ごとにゴールド。
static func note_unit_sold(session: GameSession) -> void:
	session.add_coins(_tick_down(session, 44) * int(_value(44, "ゴールド")))


static func sell_bonus(session: GameSession) -> int:
	return _owned_value(session, 70, "売却")


static func sell_mult(session: GameSession) -> float:
	if _count(session, 257) > 0:
		return maxf(0.0, 1.0 - _value(257, "値引き") / 100.0)
	return 1.0


static func star_sell_refund(session: GameSession, cost: int, stars: int) -> int:
	var refund := maxi(cost, 0) + sell_bonus(session)
	if stars > 1 and _count(session, 111) > 0:
		var assembled := maxi(cost, 0)
		var bodies := 1
		for _i in stars - 1:
			bodies *= 3
		assembled *= bodies
		refund = assembled + _owned_value(session, 111, "ゴールド") + sell_bonus(session)
	return int(floor(float(refund) * sell_mult(session)))


## 117: 売ったとき、同じコストの別のキャラクターが入る。空いている枠の数まで。
static func note_sold_unit(session: GameSession, unit_id: int, cost: int, stars: int, free_slots: int) -> void:
	if free_slots <= 0:
		return
	var choices: Array[int] = []
	for candidate in UnitCatalog.get_unit_ids_by_cost(cost):
		if candidate != unit_id:
			choices.append(candidate)
	if choices.is_empty():
		return
	var spawn := func(_item_117: Dictionary) -> void:
		_queue_unit(session, choices[randi() % choices.size()], stars)
	_tick_down(session, 117, spawn, free_slots)


# ---------------------------------------------------------------------------
# 合成
# ---------------------------------------------------------------------------

static func pair_merge_ready(session: GameSession) -> bool:
	return _count(session, 114) > 0


static func note_pair_merge(session: GameSession) -> void:
	_consume_one(session, 114)


static func note_same_merge(session: GameSession, unit_id: int, new_stars: int, cost: int) -> void:
	session.add_coins(_owned_value(session, 106, "ゴールド"))
	session.add_coins(_count(session, 112) * maxi(cost, 0))
	session.gain_experience(_owned_value(session, 120, "経験値"))
	if new_stars >= int(_value(118, "星")):
		for _i in _count(session, 118):
			_queue_unit(session, unit_id, 2)
	_trigger_merge_copy(session)
	note_same_merge_quest(session)
	if new_stars == 3:
		_grant_star3_quest(session)


static func note_star_ups(session: GameSession, times: int) -> void:
	if times <= 0:
		return
	session.free_rerolls += times * _owned_value(session, 80, "無料更新")


## 異種合成と同じ合成上限。基本はレベル-3。自動起動・雨粒・特質の加算を含む。
static func synth_cost_cap(session: GameSession) -> int:
	var cap := session.get_level() - 3
	cap += _owned_value(session, 101, "上限")
	cap += _charges(session, 116) * int(_value(116, "上限"))
	cap += _owned_value(session, 264, "上限")
	return clampi(cap, 1, ShopOdds.MAX_COST)


static func synth_gold(session: GameSession) -> int:
	return _owned_value(session, 79, "ゴールド")
