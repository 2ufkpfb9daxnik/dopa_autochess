class_name RelicCombat
extends RefCounted

## 012 物語はこれでおしまい、030 画鋲: 撃破ゲージの減少量と上限は「ここでは決めない」。戦闘に撃破ゲージが無いので未適用。
## 037 ドローン: 範囲ダメージの追加体数は、範囲シナジーの選び方を書き写さない前提で、その体数選択が戦闘にまだ無いので未適用。
## 181-200 召喚物・盤面装置: 装置枠・コピー召喚・卵枠など盤面システムの設定が残っているので未適用（189の数値バフと195の初動弱体だけ一部適用）。
## 216 召喚の与ダメージ: 召喚物が出ないあいだは未適用。
## 277・278・284: 無敵時間・デバフ免疫時間・近接DoTのタイミング設定が未確定なので未適用。


static func bind(fighter, host: Node) -> void:
	var ids := ids_of(fighter.unit, host)
	fighter.relic_ids = ids
	fighter.relic_flat_damage = (
		_sum_one(ids, 1, "与ダメージ")
		+ _sum_one(ids, 220, "与ダメージ")
		+ _sum_one(ids, 244, "与ダメージ")
		+ _sum_one(ids, 250, "与ダメージ")
		+ _sum_one(ids, 256, "与ダメージ")
		+ _sum_one(ids, 259, "与ダメージ")
		+ _sum_one(ids, 262, "与ダメージ")
		+ _sum_one(ids, 273, "与ダメージ")
		+ _sum_one(ids, 279, "与ダメージ")
		+ _sum_one(ids, 302, "与ダメージ")
		+ _sum_one(ids, 312, "与ダメージ")
	) / 100.0
	fighter.relic_attack_pen = (
		_sum_one(ids, 7, "貫通率") + _sum_one(ids, 275, "貫通率")
	) / 100.0
	fighter.relic_element_bonus = _sum_one(ids, 19, "属性の与ダメージ") / 100.0
	fighter.relic_element_bonus += _element_bonus_from(ids, fighter.element)
	fighter.relic_opening_bonus = (
		_sum_one(ids, 10, "最初の与ダメージ") + _sum_one(ids, 222, "最初の与ダメージ")
	) / 100.0
	fighter.relic_opening = fighter.relic_opening_bonus > 0.0
	fighter.relic_low_bonus = _sum_one(ids, 20, "瀕死の与ダメージ") / 100.0
	fighter.relic_taken_cut = (
		_sum_one(ids, 14, "受けるダメージ")
		+ _sum_one(ids, 162, "受けるダメージ")
		+ _sum_one(ids, 206, "受けるダメージ")
		+ _sum_one(ids, 231, "受けるダメージ")
		+ _sum_one(ids, 259, "受けるダメージ")
		+ _sum_one(ids, 302, "受けるダメージ")
		+ _sum_one(ids, 313, "受けるダメージ")
	) / 100.0
	fighter.relic_heal_ratio = (
		_sum_one(ids, 9, "回復") + _sum_one(ids, 266, "吸血") + _sum_one(ids, 280, "吸血")
	) / 100.0
	fighter.relic_heal_left = int(_sum_one(ids, 9, "回復の回数"))
	if fighter.relic_heal_left <= 0 and fighter.relic_heal_ratio > 0.0 and (
		ids.has(266) or ids.has(280)
	):
		fighter.relic_heal_left = 99
	fighter.relic_layers = int(_sum_one(ids, 13, "層"))
	fighter.relic_weaken_cut = _sum_one(ids, 17, "次の与ダメージ") / 100.0
	fighter.relic_chase_left = int(_sum_one(ids, 11, "追撃の回数"))
	fighter.relic_neighbor = ids.has(16)
	fighter.relic_speed_step = int(
		_sum_one(ids, 18, "速度の上昇") + _sum_one(ids, 267, "速度")
	)
	fighter.relic_speed_cap = int(_sum_one(ids, 18, "速度の上限"))
	if ids.has(267) and fighter.relic_speed_cap <= 0:
		fighter.relic_speed_cap = 80
	var flat_speed := int(
		_sum_one(ids, 2, "速度")
		+ _sum_one(ids, 215, "速度")
		+ _sum_one(ids, 230, "速度")
		+ _sum_one(ids, 241, "速度")
	)
	if flat_speed != 0:
		fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + flat_speed
	fighter.defense += (
		_sum_one(ids, 3, "防御力")
		+ _sum_one(ids, 218, "防御力")
		+ _sum_one(ids, 243, "防御力")
	)
	fighter.defense *= 1.0 + (
		_sum_one(ids, 163, "防御力") / 100.0
	)
	var hp_bonus := int(_sum_one(ids, 4, "最大体力"))
	hp_bonus += int(
		_sum_one(ids, 202, "最大体力")
		+ _sum_one(ids, 219, "最大体力")
		+ _sum_one(ids, 228, "最大体力")
		+ _sum_one(ids, 232, "最大体力")
	)
	var hp_rate := (
		_sum_one(ids, 161, "最大体力")
		+ _sum_one(ids, 256, "最大体力")
		+ _sum_one(ids, 269, "最大体力")
	) / 100.0
	if ids.has(256):
		hp_rate = -absf(_sum_one(ids, 256, "最大体力") / 100.0)
	if hp_bonus != 0 or not is_zero_approx(hp_rate):
		var before: int = int(fighter.max_hp)
		fighter.max_hp = maxi(1, int(round(float(fighter.max_hp + hp_bonus) * (1.0 + hp_rate))))
		var gained: int = int(fighter.max_hp) - before
		if gained != 0:
			fighter.hp = clampi(int(fighter.hp) + gained, 1, int(fighter.max_hp))
	fighter.attack += (
		_sum_one(ids, 212, "攻撃力")
		+ _sum_one(ids, 237, "攻撃力")
		+ _sum_one(ids, 249, "攻撃力")
	)
	fighter.crit_rate += (
		_sum_one(ids, 5, "クリティカル率")
		+ _sum_one(ids, 214, "クリティカル率")
		+ _sum_one(ids, 236, "クリティカル率")
		+ _sum_one(ids, 245, "クリティカル率")
		+ _sum_one(ids, 247, "クリティカル率")
		+ _sum_one(ids, 265, "クリティカル率")
	) / 100.0
	fighter.crit_damage += (
		_sum_one(ids, 6, "クリティカルダメージ")
		+ _sum_one(ids, 227, "クリティカルダメージ")
		+ _sum_one(ids, 265, "クリティカルダメージ")
	) / 100.0
	fighter.attribute_resist += _sum_one(ids, 8, "属性耐性") / 100.0
	var priority_cut := int(_sum_one(ids, 15, "優先度の低下"))
	if priority_cut != 0:
		fighter.priority = maxi(0, fighter.priority - priority_cut)
	if ids.has(175):
		fighter.barrier += int(round(float(fighter.max_hp) * _sum_one(ids, 175, "シールド") / 100.0))
	if ids.has(282):
		fighter.barrier += int(round(float(fighter.max_hp) * _sum_one(ids, 282, "シールド") / 100.0))
	var board: BoardController = null
	if host != null:
		board = host.get("board") as BoardController
	if ids.has(262) and board != null and _row(fighter.unit, board).x == 1:
		fighter.hp = maxi(1, int(round(float(fighter.max_hp) * _sum_one(ids, 262, "開始体力") / 100.0)))
	var gauge_bonus := _sum_one(ids, 217, "ゲージ") + _sum_one(ids, 271, "ゲージ")
	if gauge_bonus != 0.0:
		fighter.kit["gauge_rate"] = float(fighter.kit.get("gauge_rate", 1.0)) + gauge_bonus / 100.0
	_apply_pulse_kit(fighter, ids)


static func ids_of(unit: GameUnit, host: Node) -> Array[int]:
	var out: Array[int] = []
	if unit == null or host == null or host.get("session") == null:
		return out
	var session: GameSession = host.session
	for uid in unit.equipped_relic_uids:
		var relic_id := session.relic_id_of(int(uid))
		if relic_id > 0:
			out.append(relic_id)
	return out


static func attack_penetration(fighter) -> float:
	return fighter.relic_attack_pen


static func flat_outgoing(fighter) -> float:
	return fighter.relic_flat_damage


static func element_outgoing(fighter, element: String) -> float:
	if element.is_empty() or element != fighter.element:
		return 0.0
	return fighter.relic_element_bonus


static func named_coef(fighter, is_dot: bool) -> float:
	var coef := 1.0
	if not is_dot and fighter.relic_opening:
		coef *= 1.0 + fighter.relic_opening_bonus
	if not is_dot and fighter.relic_weaken_now > 0.0:
		coef *= maxf(0.0, 1.0 - fighter.relic_weaken_now)
	if fighter.relic_low_bonus > 0.0 and _is_low_hp(fighter):
		coef *= 1.0 + fighter.relic_low_bonus
	return coef


static func taken_mult(fighter, is_dot: bool) -> float:
	if is_dot or fighter.relic_taken_cut <= 0.0:
		return 1.0
	return maxf(0.0, 1.0 - fighter.relic_taken_cut)


static func begin_attack(fighter) -> bool:
	fighter.relic_killed = false
	if fighter.relic_weaken_left > 0 and fighter.relic_weaken_cut > 0.0:
		fighter.relic_weaken_now = fighter.relic_weaken_cut
		fighter.relic_weaken_left = 0
	else:
		fighter.relic_weaken_now = 0.0
	return fighter.relic_opening


static func finish_attack(fighter) -> void:
	fighter.relic_opening = false
	fighter.relic_weaken_now = 0.0
	if fighter.relic_speed_step <= 0 or fighter.relic_speed_cap <= 0:
		return
	var room: int = int(fighter.relic_speed_cap) - int(fighter.relic_speed_stack)
	if room <= 0:
		return
	var gain: int = mini(int(fighter.relic_speed_step), room)
	fighter.relic_speed_stack += gain
	fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + gain


static func on_direct_hit(actor, target, fighters: Dictionary) -> void:
	if actor.relic_heal_left > 0 and actor.relic_heal_ratio > 0.0 and actor.alive:
		var heal := int(round(float(actor.max_hp) * actor.relic_heal_ratio))
		if heal > 0:
			actor.hp = mini(actor.max_hp, actor.hp + heal)
			actor.relic_heal_left -= 1
			if is_instance_valid(actor.unit):
				actor.unit.set_battle_hp(actor.hp, actor.max_hp)
	if actor.relic_layers > 0 and target != null:
		target.layers[actor.element] = int(target.layers.get(actor.element, 0)) + actor.relic_layers
	if actor.relic_weaken_cut <= 0.0 or target == null or not is_instance_valid(target.unit):
		return
	if not target.alive:
		_release_mark(actor, fighters)
		return
	_release_mark(actor, fighters)
	actor.relic_mark_id = target.unit.get_instance_id()
	target.relic_weaken_cut = actor.relic_weaken_cut
	target.relic_weaken_left = 1
	target.relic_weaken_source = actor.unit.get_instance_id()


static func note_kill(actor) -> void:
	actor.relic_killed = true


static func clear_touching(dead, fighters: Dictionary) -> void:
	dead.relic_weaken_left = 0
	dead.relic_weaken_now = 0.0
	var dead_id := 0
	if is_instance_valid(dead.unit):
		dead_id = dead.unit.get_instance_id()
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.relic_weaken_source == dead_id and dead_id != 0:
			fighter.relic_weaken_left = 0
			fighter.relic_weaken_now = 0.0
		if fighter.relic_mark_id == dead_id and dead_id != 0:
			fighter.relic_mark_id = 0


static func _release_mark(actor, fighters: Dictionary) -> void:
	if actor.relic_mark_id != 0 and fighters.has(actor.relic_mark_id):
		var prev = fighters[actor.relic_mark_id]
		prev.relic_weaken_left = 0
		prev.relic_weaken_now = 0.0
	actor.relic_mark_id = 0


static func _is_low_hp(fighter) -> bool:
	var line := int(ceil(float(fighter.max_hp) / 2.0))
	return fighter.hp <= line


static func aura_outgoing(attacker, fighters: Dictionary, board: BoardController) -> float:
	var bonus := 0.0
	var bearer21 = _unique_living(fighters, 21, attacker.enemy, board)
	if bearer21 != null:
		bonus += _value(21, "与ダメージ") / 100.0
	var bearer25 = _unique_living(fighters, 25, attacker.enemy, board)
	if bearer25 != null and _row(attacker.unit, board).x == 1:
		bonus += _value(25, "与ダメージ") / 100.0
	bonus += _neighbor_damage(attacker, fighters, board)
	bonus += _owned_outgoing(attacker, board)
	if _row(attacker.unit, board).x == 1 and attacker.relic_ids.has(248):
		bonus += _sum_one(attacker.relic_ids, 248, "与ダメージ") / 100.0
	if _row(attacker.unit, board).x == 1:
		bonus += float(_count_side(fighters, 262, attacker.enemy)) * _value(262, "与ダメージ") / 100.0
	bonus += _neighbor_ally_damage(attacker, fighters, board)
	return bonus


static func _owned_outgoing(attacker, board: BoardController) -> float:
	if attacker.enemy or board == null or board.get_parent() == null:
		return 0.0
	var session = board.get_parent().get("session")
	if session == null:
		return 0.0
	return RelicEconomy.owned_outgoing(session)


static func aura_speed(fighter, fighters: Dictionary, board: BoardController) -> int:
	if _unique_living(fighters, 22, fighter.enemy, board) == null:
		return 0
	return int(_value(22, "速度"))


static func aura_defense(fighter, fighters: Dictionary, board: BoardController) -> float:
	if _row(fighter.unit, board).x != 0:
		return 0.0
	if _unique_living(fighters, 24, fighter.enemy, board) == null:
		return 0.0
	return _value(24, "防御力")


static func aura_pen(attacker, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 34, attacker.enemy, _board) == null:
		return 0.0
	return _value(34, "貫通率") / 100.0


static func aura_crit(attacker, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 27, attacker.enemy, _board) == null:
		return 0.0
	return _value(27, "クリティカル率") / 100.0


static func aura_resist(defender, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 28, defender.enemy, _board) == null:
		return 0.0
	return _value(28, "属性耐性") / 100.0


static func aura_taken_cut(defender, fighters: Dictionary, board: BoardController) -> float:
	var cut := 0.0
	if _unique_living(fighters, 23, defender.enemy, board) != null:
		cut += _value(23, "受けるダメージ") / 100.0
	cut += float(_count_side(fighters, 165, defender.enemy)) * _value(165, "受けるダメージ") / 100.0
	if _count_side(fighters, 176, defender.enemy) >= int(_value(176, "枚数")):
		cut += _value(176, "受けるダメージ") / 100.0
	cut += _adjacent_mitigation(defender, fighters, board)
	if defender.relic_ids.has(270):
		var row := _row(defender.unit, board)
		var neighbors := 0
		for key in fighters.keys():
			var ally = fighters[key]
			if ally == defender or ally.enemy != defender.enemy or not _living(ally):
				continue
			var ally_row := _row(ally.unit, board)
			if ally_row.x == row.x and absi(ally_row.y - row.y) == 1:
				neighbors += 1
		cut += float(neighbors) * _sum_one(defender.relic_ids, 270, "受けるダメージ") / 100.0
	cut += _guard_neighbor_cut(defender, fighters, board)
	return cut


static func aura_priority(fighter, fighters: Dictionary, board: BoardController) -> int:
	var bonus := 0
	var row := _row(fighter.unit, board)
	if row.x < 0:
		return 0
	for key in fighters.keys():
		var bearer = fighters[key]
		if bearer.enemy != fighter.enemy or not _living(bearer) or not bearer.relic_ids.has(39):
			continue
		var bearer_row := _row(bearer.unit, board)
		if bearer_row.x != row.x:
			continue
		if bearer == fighter or absi(bearer_row.y - row.y) == 1:
			bonus += int(_value(39, "優先度の上昇"))
	return bonus


static func note_front_hit(target, fighters: Dictionary, board: BoardController) -> void:
	var bearer = _unique_living(fighters, 33, target.enemy, board)
	if bearer != target or _row(target.unit, board).x != 0:
		return
	var cut := _value(33, "受けるダメージ") / 100.0
	var row := _row(target.unit, board)
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == target or ally.enemy != target.enemy or not _living(ally):
			continue
		if _row(ally.unit, board) != Vector2i(0, row.y - 1) and _row(ally.unit, board) != Vector2i(0, row.y + 1):
			continue
		if ally.relic_next_cut <= 0.0:
			ally.relic_next_cut = cut


static func crit_layer_bearer(actor, fighters: Dictionary, charges_left: int, board: BoardController = null):
	if charges_left <= 0:
		return null
	return _unique_living(fighters, 31, actor.enemy, board)


static func battle_relic_value(fighters: Dictionary, relic_id: int, ally_enemy: bool, key: String) -> float:
	if _unique_living(fighters, relic_id, ally_enemy) == null:
		return 0.0
	return _value(relic_id, key)


static func side_has(fighters: Dictionary, relic_id: int, ally_enemy: bool) -> bool:
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.enemy == ally_enemy and fighter.relic_ids.has(relic_id):
			return true
	return false


static func _neighbor_damage(attacker, fighters: Dictionary, board: BoardController) -> float:
	var row := _row(attacker.unit, board)
	if row.x < 0:
		return 0.0
	var bonus := 0.0
	var rate := _value(26, "与ダメージ") / 100.0
	for key in fighters.keys():
		var bearer = fighters[key]
		if bearer == attacker or bearer.enemy != attacker.enemy or not _living(bearer):
			continue
		if not bearer.relic_ids.has(26):
			continue
		var bearer_row := _row(bearer.unit, board)
		if bearer_row.x == row.x and absi(bearer_row.y - row.y) == 1:
			bonus += rate
	return bonus


static func _guard_neighbor_cut(defender, fighters: Dictionary, board: BoardController) -> float:
	if _unique_living(fighters, 35, defender.enemy, board) == null:
		return 0.0
	var row := _row(defender.unit, board)
	if row.x != 0:
		return 0.0
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == defender or ally.enemy != defender.enemy or not ally.guarding or not _living(ally):
			continue
		var ally_row := _row(ally.unit, board)
		if ally_row.x == 0 and absi(ally_row.y - row.y) == 1:
			return _value(35, "受けるダメージ") / 100.0
	return 0.0


static func bearer_deployed(fighters: Dictionary, board: BoardController, relic_id: int, ally_enemy: bool) -> bool:
	var unit := _designated_unit(fighters, board, relic_id, ally_enemy)
	return unit != null and fighters.has(unit.get_instance_id())


static func _unique_living(fighters: Dictionary, relic_id: int, ally_enemy: bool, board: BoardController = null):
	var unit := _designated_unit(fighters, board, relic_id, ally_enemy)
	if unit == null or not fighters.has(unit.get_instance_id()):
		return null
	var fighter = fighters[unit.get_instance_id()]
	if not _living(fighter):
		return null
	return fighter


static func _designated_unit(fighters: Dictionary, board: BoardController, relic_id: int, ally_enemy: bool) -> GameUnit:
	var chosen: GameUnit = null
	var seen := {}
	var session = null
	if board != null and board.get_parent() != null and board.get_parent().get("session") != null:
		session = board.get_parent().session
	if board != null and session != null:
		for entry in board.get_all_units():
			var unit := entry as GameUnit
			if unit == null or unit.is_enemy != ally_enemy or not _unit_has_relic(unit, session, relic_id):
				continue
			seen[unit.get_instance_id()] = true
			if _smaller_bearer(unit, chosen):
				chosen = unit
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.enemy != ally_enemy or not is_instance_valid(fighter.unit):
			continue
		if seen.has(fighter.unit.get_instance_id()) or not fighter.relic_ids.has(relic_id):
			continue
		if _smaller_bearer(fighter.unit, chosen):
			chosen = fighter.unit
	return chosen


static func _smaller_bearer(unit: GameUnit, chosen: GameUnit) -> bool:
	if chosen == null:
		return true
	if unit.unit_id != chosen.unit_id:
		return unit.unit_id < chosen.unit_id
	return unit.get_instance_id() < chosen.get_instance_id()


static func _unit_has_relic(unit: GameUnit, session: GameSession, relic_id: int) -> bool:
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(int(uid)) == relic_id:
			return true
	return false


static func _living(fighter) -> bool:
	return fighter != null and fighter.alive and fighter.hp > 0 and is_instance_valid(fighter.unit)


static func _row(unit: GameUnit, board: BoardController) -> Vector2i:
	if unit == null or board == null:
		return Vector2i(-1, -1)
	if unit.is_enemy:
		var slot := board.front_slot_of(unit)
		if slot >= 0:
			return Vector2i(0, slot)
		return Vector2i(-1, -1)
	for slot_index in BoardController.SLOTS_PER_FACE:
		if board.get_resolved_unit(board.active_face, slot_index) == unit:
			return Vector2i(0 if slot_index < BoardController.FRONT_COUNT else 1, slot_index % BoardController.FRONT_COUNT)
	return Vector2i(-1, -1)


static func _element_bonus_from(ids: Array[int], element: String) -> float:
	if element.is_empty():
		return 0.0
	var key := "%sの与ダメージ" % _element_label(element)
	if key == "の与ダメージ":
		return 0.0
	var total := 0.0
	for relic_id in ids:
		var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
		total += float(effects.get(key, 0.0))
	return total / 100.0


static func _element_label(element: String) -> String:
	if element == "fire" or element == "炎":
		return "炎"
	if element == "water" or element == "水":
		return "水"
	if element == "thunder" or element == "雷":
		return "雷"
	if element == "earth" or element == "土":
		return "土"
	if element == "ice" or element == "氷":
		return "氷"
	if element == "wind" or element == "風":
		return "風"
	if element == "absorb" or element == "吸収":
		return "吸収"
	return element


static func _apply_pulse_kit(fighter, ids: Array[int]) -> void:
	var heal_gap := int(_sum_one(ids, 164, "間隔") + _sum_one(ids, 269, "間隔"))
	var heal_ratio := (_sum_one(ids, 164, "回復") + _sum_one(ids, 269, "回復")) / 100.0
	if heal_gap > 0 and heal_ratio > 0.0:
		fighter.kit["relic_pulse_gap"] = heal_gap
		fighter.kit["relic_pulse_heal"] = heal_ratio
		fighter.kit["relic_pulse_left"] = heal_gap
	var stack_gap := int(_sum_one(ids, 272, "間隔") + _sum_one(ids, 268, "上限"))
	if ids.has(272):
		fighter.kit["relic_ramp_gap"] = int(_value(272, "間隔"))
		fighter.kit["relic_ramp_step"] = _value(272, "与ダメージ") / 100.0
		fighter.kit["relic_ramp_left"] = int(_value(272, "間隔"))
	if ids.has(268):
		fighter.kit["relic_hit_step"] = _value(268, "与ダメージ") / 100.0
		fighter.kit["relic_hit_cap"] = _value(268, "上限") / 100.0
		fighter.kit["relic_hit_stack"] = 0.0
	if stack_gap < 0:
		pass


static func _count_side(fighters: Dictionary, relic_id: int, ally_enemy: bool) -> int:
	var count := 0
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.enemy == ally_enemy and _living(fighter) and fighter.relic_ids.has(relic_id):
			count += 1
	return count


static func _adjacent_mitigation(defender, fighters: Dictionary, board: BoardController) -> float:
	var row := _row(defender.unit, board)
	if row.x < 0 or not defender.relic_ids.has(174):
		return 0.0
	var neighbors := 0
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == defender or ally.enemy != defender.enemy or not _living(ally):
			continue
		var ally_row := _row(ally.unit, board)
		if ally_row.x == row.x and absi(ally_row.y - row.y) == 1:
			neighbors += 1
	return float(neighbors) * _sum_one(defender.relic_ids, 174, "受けるダメージ") / 100.0


static func _front_stack_hp_aura(defender, fighters: Dictionary, board: BoardController) -> float:
	# 168 uses max HP, applied in bind via board-wide recount; mitigation unused here.
	return 0.0


static func _neighbor_ally_damage(attacker, fighters: Dictionary, board: BoardController) -> float:
	var row := _row(attacker.unit, board)
	if row.x < 0:
		return 0.0
	var bonus := 0.0
	for key in fighters.keys():
		var bearer = fighters[key]
		if bearer == attacker or bearer.enemy != attacker.enemy or not _living(bearer):
			continue
		if not bearer.relic_ids.has(281):
			continue
		var bearer_row := _row(bearer.unit, board)
		if bearer_row.x == row.x and absi(bearer_row.y - row.y) == 1:
			bonus += _sum_one(bearer.relic_ids, 281, "与ダメージ") / 100.0
	if attacker.relic_ids.has(270):
		var neighbors := 0
		for key in fighters.keys():
			var ally = fighters[key]
			if ally == attacker or ally.enemy != attacker.enemy or not _living(ally):
				continue
			var ally_row := _row(ally.unit, board)
			if ally_row.x == row.x and absi(ally_row.y - row.y) == 1:
				neighbors += 1
		# 270 is taken-cut; handled in aura_taken_cut via adjacent style — skip here
		if neighbors < 0:
			bonus += 0.0
	return bonus


static func apply_front_hp_aura(fighters: Dictionary, board: BoardController) -> void:
	for side in [false, true]:
		var stacks := _count_side(fighters, 168, side)
		if stacks <= 0:
			continue
		var rate := float(stacks) * _value(168, "最大体力") / 100.0
		for key in fighters.keys():
			var fighter = fighters[key]
			if fighter.enemy != side or not _living(fighter):
				continue
			if _row(fighter.unit, board).x != 0:
				continue
			var before: int = int(fighter.max_hp)
			fighter.max_hp = maxi(1, int(round(float(fighter.max_hp) * (1.0 + rate))))
			fighter.hp = mini(int(fighter.max_hp), int(fighter.hp) + (int(fighter.max_hp) - before))


static func tick_pulses(fighters: Dictionary) -> void:
	for key in fighters.keys():
		var fighter = fighters[key]
		if not _living(fighter):
			continue
		var gap := int(fighter.kit.get("relic_pulse_gap", 0))
		if gap > 0:
			var left := int(fighter.kit.get("relic_pulse_left", gap)) - 1
			if left <= 0:
				var ratio := float(fighter.kit.get("relic_pulse_heal", 0.0))
				var heal := int(round(float(fighter.max_hp) * ratio))
				fighter.hp = mini(fighter.max_hp, fighter.hp + heal)
				if is_instance_valid(fighter.unit):
					fighter.unit.set_battle_hp(fighter.hp, fighter.max_hp)
				left = gap
			fighter.kit["relic_pulse_left"] = left
		var ramp_gap := int(fighter.kit.get("relic_ramp_gap", 0))
		if ramp_gap > 0:
			var ramp_left := int(fighter.kit.get("relic_ramp_left", ramp_gap)) - 1
			if ramp_left <= 0:
				fighter.relic_flat_damage += float(fighter.kit.get("relic_ramp_step", 0.0))
				ramp_left = ramp_gap
			fighter.kit["relic_ramp_left"] = ramp_left


static func note_hit_stack(fighter) -> void:
	if fighter == null:
		return
	var step := float(fighter.kit.get("relic_hit_step", 0.0))
	if step <= 0.0:
		return
	var cap := float(fighter.kit.get("relic_hit_cap", 0.0))
	var stack := float(fighter.kit.get("relic_hit_stack", 0.0))
	var next := stack + step
	if cap > 0.0:
		next = minf(cap, next)
	fighter.kit["relic_hit_stack"] = next
	fighter.relic_flat_damage += next - stack


static func _value(relic_id: int, key: String) -> float:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	return float(effects.get(key, 0.0))


static func _sum_one(ids: Array[int], relic_id: int, key: String) -> float:
	var total := 0.0
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	var value := float(effects.get(key, 0.0))
	for owned in ids:
		if owned == relic_id:
			total += value
	return total
