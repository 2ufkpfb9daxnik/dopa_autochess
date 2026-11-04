extends "res://scripts/game/relic_economy_base.gd"

## ラウンドをまたぐ成長（装備レリックに積む値）と、持っているだけで入る戦闘の補正。
## 継承のつながりは relic_economy_base.gd の先頭を参照。


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
	for uid in _equipped_uids(session, unit, 153):
		total += _growth_of(session, uid)
	return total / 100.0


## 142 ゼリー: 積んだ最大体力の割合（%）。
static func growth_max_hp(session: GameSession, unit: GameUnit) -> float:
	var total := 0.0
	for uid in _equipped_uids(session, unit, 142):
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


# ---------------------------------------------------------------------------
# 成長を積むきっかけ
# ---------------------------------------------------------------------------

## ラウンド開始: 143・147 は毎ラウンド、159 は連勝・連敗のとき。
static func note_growth_round(session: GameSession) -> void:
	for unit in _owned_units(session):
		for uid in unit.equipped_relic_uids:
			var relic_id := session.relic_id_of(uid)
			if relic_id == 143 or relic_id == 147:
				_add_growth(session, uid, _value(relic_id, "与ダメージ"))
			elif relic_id == 159:
				if session.win_streak > 0:
					_add_growth(session, uid, _value(159, "連勝"))
				elif session.loss_streak > 0:
					_add_growth(session, uid, _value(159, "連敗"))


## 152: レベルが上がった段数ぶん。
static func note_level_growth(session: GameSession, steps: int) -> void:
	if steps <= 0:
		return
	for unit in _owned_units(session):
		for uid in _equipped_uids(session, unit, 152):
			_add_growth(session, uid, _value(152, "与ダメージ") * float(steps))


## 151: 装備者の星が上がったとき。
static func note_equipped_star(session: GameSession, unit: GameUnit) -> void:
	for uid in _equipped_uids(session, unit, 151):
		_add_growth(session, uid, _value(151, "与ダメージ"))


## 141 は倒した本人、145 は出撃している装備者（本人か味方かで値が違う）。157 は倒すとプレイヤーHPが戻る。
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
		for uid in _equipped_uids(session, ally, 145):
			_add_growth(session, uid, _value(145, "自分" if ally == killer else "味方"))


## 戦闘のあと生き残った前衛の 153、後衛の 154。
static func note_row_survivors(session: GameSession, front: Array, back: Array) -> void:
	for entry in front:
		for uid in _equipped_uids(session, entry as GameUnit, 153):
			_add_growth(session, uid, _value(153, "軽減"))
	for entry in back:
		for uid in _equipped_uids(session, entry as GameUnit, 154):
			_add_growth(session, uid, _value(154, "与ダメージ"))


## 150: 使ったゴールドを装備ごとに貯め、段ごとに積む。
static func note_gold_spent(session: GameSession, amount: int) -> void:
	if amount <= 0:
		return
	var step := maxi(int(_value(150, "ゴールド")), 1)
	for unit in _owned_units(session):
		for uid in _equipped_uids(session, unit, 150):
			var item := _item(session, uid)
			if item.is_empty():
				continue
			var paid := int(item.get("paid", 0)) + amount
			var stacks := paid / step
			item["paid"] = paid % step
			if stacks > 0:
				_add_growth(session, uid, float(stacks) * _value(150, "与ダメージ"))


## 142・144・146・149・160: 装備者の戦闘結果で積みが増える。
static func _apply_outcome_growth(session: GameSession, units: Array) -> void:
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


## 積む。同じキャラクターが 155 を装備していれば、1回ごとにその追加も入る（155 自身には入らない）。
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
	for other in _equipped_uids(session, owner, 155):
		if other != uid:
			extra += _value(155, "追加")
	return extra


## 157: 倒すとプレイヤーHPが戻る。1戦闘の上限つき。
static func _heal_from_kill(session: GameSession, uid: int) -> void:
	var item := _item(session, uid)
	if item.is_empty():
		return
	var used := int(item.get("battle_heal", 0))
	var cap := int(_value(157, "上限"))
	if used >= cap:
		return
	var heal := mini(int(_value(157, "HP")), cap - used)
	_heal_player(session, heal)
	item["battle_heal"] = used + heal


# ---------------------------------------------------------------------------
# 279 遊牧: ラウンドごとに与ダメージ側と回復側が入れ替わる。
# ---------------------------------------------------------------------------

static func _toggle_round_relics(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) == 279:
			item["mode"] = 1 - int(item.get("mode", 0))


static func relic_279_outgoing(session: GameSession, unit: GameUnit) -> float:
	var total := 0.0
	for uid in _equipped_uids(session, unit, 279):
		if int(_item(session, uid).get("mode", 0)) == 0:
			total += _value(279, "与ダメージ")
	return total / 100.0


## 回復のラウンドで、命中したときに戻る割合。
static func nomad_heal_ratio(session: GameSession, unit: GameUnit) -> float:
	var ratio := 0.0
	for uid in _equipped_uids(session, unit, 279):
		if int(_item(session, uid).get("mode", 0)) == 1:
			ratio += _value(279, "回復") / 100.0
	return ratio


# ---------------------------------------------------------------------------
# 持っているだけで入る戦闘の補正
# ---------------------------------------------------------------------------

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
		bonus += _owned_float(session, 259, "与ダメージ") / 100.0
	for relic_id in [256, 302, 312, 136]:
		bonus += _owned_float(session, relic_id, "与ダメージ") / 100.0
	bonus += slide_outgoing(session)
	return bonus


## 持っているだけで味方全員の受けるダメージが下がるもの（259・302・313）。継続ダメージにも入る。
static func owned_taken_cut(session: GameSession) -> float:
	var cut := 0.0
	if session.win_streak > 0:
		cut += _owned_float(session, 259, "受けるダメージ") / 100.0
	cut += _owned_float(session, 302, "受けるダメージ") / 100.0
	cut += _owned_float(session, 313, "受けるダメージ") / 100.0
	return cut


## 256 仇討ち: 味方全員の最大体力が下がる（%）。
static func owned_max_hp_cut(session: GameSession) -> float:
	return _owned_float(session, 256, "最大体力")


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


static func note_battle_started(session: GameSession) -> void:
	arm_battle_slides(session)
	for item in session.relics:
		if int(item.get("id", -1)) == 157:
			item["battle_heal"] = 0
