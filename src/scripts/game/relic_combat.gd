class_name RelicCombat
extends RefCounted

## 012 物語はこれでおしまい、030 画鋲: 撃破ゲージの減少量と上限は「ここでは決めない」。戦闘に撃破ゲージが無いので未適用。
## 037 ドローン: 範囲ダメージの追加体数は、範囲シナジーの選び方を書き写さない前提で、その体数選択が戦闘にまだ無いので未適用。


static func bind(fighter, host: Node) -> void:
	var ids := ids_of(fighter.unit, host)
	fighter.relic_ids = ids
	fighter.relic_flat_damage = _sum_one(ids, 1, "与ダメージ") / 100.0
	fighter.relic_attack_pen = _sum_one(ids, 7, "貫通率") / 100.0
	fighter.relic_element_bonus = _sum_one(ids, 19, "属性の与ダメージ") / 100.0
	fighter.relic_opening_bonus = _sum_one(ids, 10, "最初の与ダメージ") / 100.0
	fighter.relic_opening = fighter.relic_opening_bonus > 0.0
	fighter.relic_low_bonus = _sum_one(ids, 20, "瀕死の与ダメージ") / 100.0
	fighter.relic_taken_cut = _sum_one(ids, 14, "受けるダメージ") / 100.0
	fighter.relic_heal_ratio = _sum_one(ids, 9, "回復") / 100.0
	fighter.relic_heal_left = int(_sum_one(ids, 9, "回復の回数"))
	fighter.relic_layers = int(_sum_one(ids, 13, "層"))
	fighter.relic_weaken_cut = _sum_one(ids, 17, "次の与ダメージ") / 100.0
	fighter.relic_chase_left = int(_sum_one(ids, 11, "追撃の回数"))
	fighter.relic_neighbor = ids.has(16)
	fighter.relic_speed_step = int(_sum_one(ids, 18, "速度の上昇"))
	fighter.relic_speed_cap = int(_sum_one(ids, 18, "速度の上限"))
	var flat_speed := int(_sum_one(ids, 2, "速度"))
	if flat_speed != 0:
		fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + flat_speed
	fighter.defense += _sum_one(ids, 3, "防御力")
	var hp_bonus := int(_sum_one(ids, 4, "最大体力"))
	if hp_bonus != 0:
		fighter.max_hp = maxi(1, fighter.max_hp + hp_bonus)
		fighter.hp = mini(fighter.max_hp, fighter.hp + hp_bonus)
	fighter.crit_rate += _sum_one(ids, 5, "クリティカル率") / 100.0
	fighter.crit_damage += _sum_one(ids, 6, "クリティカルダメージ") / 100.0
	fighter.attribute_resist += _sum_one(ids, 8, "属性耐性") / 100.0
	var priority_cut := int(_sum_one(ids, 15, "優先度の低下"))
	if priority_cut != 0:
		fighter.priority = maxi(0, fighter.priority - priority_cut)


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
	var room := fighter.relic_speed_cap - fighter.relic_speed_stack
	if room <= 0:
		return
	var gain := mini(fighter.relic_speed_step, room)
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
