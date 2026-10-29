class_name BattleDirector
extends RefCounted

# Turn order follows battle.md. Characters 001-006 use their sheets.
# Hit chance is still a stand-in: battle.md does not give the curve.

const AP_NUMERATOR := 65535
const FORMATION_PAIR := 0.2
const FORMATION_LINE := 0.4
const STEP_TIME := 0.28
const ATTACK_HIT_TIME := 1.05
const ATTACK_AFTER_TIME := 0.28
const GUARD_TIME := 1.15
const BUFF_TIME := 1.25

var _host: Node
var _fighters: Dictionary = {}
var _motion: Tween


class Fighter:
	var unit: GameUnit
	var enemy := false
	var hp := 1
	var max_hp := 1
	var attack := 1.0
	var defense := 0.0
	var speed := 100
	var penetration := 0.0
	var bonus_damage := 0.0
	var element := ""
	var element_damage: Dictionary = {}
	var element_resist: Dictionary = {}
	var attribute_resist := 0.0
	var sheet_id := 0
	var barrier := 0
	var stand_slot := -1
	var layers: Dictionary = {}
	var dot_bank: Dictionary = {}
	var kit: Dictionary = {}
	var damage_taken := 0.0
	var crit_rate := 0.0
	var crit_damage := 0.0
	var priority := 100
	var weight_attack := 5
	var weight_buff := 3
	var weight_guard := 2
	var uses_buff := true
	var ap := 1
	var base_ap := 1
	var saved_ap := 1
	var start_ap := 1
	var guarding := false
	var alive := true
	var in_queue := false
	var entered_once := false


func setup(host: Node) -> void:
	_host = host


func play() -> Dictionary:
	_fighters.clear()
	var won := false
	while _host != null and _host.is_inside_tree():
		_sync_queue()
		var allies := _alive_count(false)
		var enemies := _alive_count(true)
		if enemies <= 0:
			won = allies > 0 or _any_living_ally()
			break
		if allies <= 0:
			var reinforced: bool = await _reinforce_allies()
			if reinforced:
				continue
			won = false
			break
		var actor := _next_actor()
		if actor == null:
			won = allies > 0
			break
		_set_guarding(actor, false)
		var spent := actor.ap
		if _arita_skips(actor):
			if is_instance_valid(actor.unit):
				actor.unit.play_battle_role("idle")
			_spend_action_points(spent, actor, false)
			if actor.alive and is_instance_valid(actor.unit):
				actor.ap = actor.base_ap
				actor.unit.action_value = actor.ap
			var jumper := _fighter_by_id(int(actor.kit.get("last_buffer_id", -1)))
			if jumper != null and jumper.alive and is_instance_valid(jumper.unit):
				jumper.ap = 0
				jumper.unit.action_value = 0
				_host._log("%s は行動せず、%s が割り込む" % [actor.unit.get_display_name(), jumper.unit.get_display_name()])
			_refresh_bar()
			await _wait(0.05)
			continue
		var was_buff: bool = await _act(actor)
		if _host == null or not _host.is_inside_tree():
			break
		_spend_action_points(spent, actor, was_buff)
		if actor.alive and is_instance_valid(actor.unit):
			actor.ap = actor.base_ap
			actor.unit.action_value = actor.ap
		_kits_after_turn(actor, was_buff)
		_refresh_bar()
	var remaining := _alive_count(true)
	finish()
	return {"won": won, "remaining": remaining}


func cleanse_debuff(unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_clear_debuffs_on_target(unit.get_instance_id())
	_host.board.restore_debuffed_unit(unit)
	if _host.session.phase == GameSession.Phase.BATTLE:
		_sync_queue()


func _clear_battle_debuffs() -> void:
	if _host == null:
		return
	var board: BoardController = _host.board
	var changed := false
	for unit in board.get_circle_units():
		if not unit.debuffed:
			continue
		unit.debuffed = false
		unit.debuff_home_face = -1
		unit.debuff_home_slot = -1
		changed = true
	if changed:
		board.refresh_presentation()
		board.units_changed.emit()


func _release_stale_debuffs() -> void:
	var active: Dictionary = {}
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.enemy:
			continue
		for entry in fighter.kit.get("debuffs", []):
			var item: Dictionary = entry
			var target := _fighter_by_id(int(item.get("target_id", -1)))
			if target != null and not target.enemy and is_instance_valid(target.unit):
				active[target.unit] = true
	var board: BoardController = _host.board
	for unit in board.get_circle_units():
		if unit.debuffed and not active.has(unit) and _fighters.has(unit.get_instance_id()):
			board.restore_debuffed_unit(unit)


func finish() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	_clear_battle_debuffs()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		var unit := fighter.unit
		if unit == null or not is_instance_valid(unit) or unit.is_enemy:
			continue
		unit.battle_ko = false
		unit.stop_guard_hit_shake()
		unit.rotation.x = 0.0
		unit.release_battle_clip()
		unit.set_battle_walking(false)
		unit.refresh_visuals()


func _act(actor: Fighter) -> bool:
	var action := _roll_action(actor)
	if not is_instance_valid(actor.unit):
		return false
	if action != "guard":
		actor.unit.play_battle_role(action)
	match action:
		"attack":
			await _attack(actor)
		"buff":
			await _support(actor)
		_:
			await _guard(actor)
	if actor.alive and is_instance_valid(actor.unit) and not actor.unit.battle_ko and not actor.guarding:
		actor.unit.play_battle_role("idle")
	await _wait(0.08)
	return action == "buff"


func _attack(actor: Fighter) -> void:
	var forced := false
	if actor.sheet_id == 3 and bool(actor.kit.get("force_hit", false)):
		forced = true
		actor.kit["force_hit"] = false
	var primary := _cover_for_ktrnksy(actor, _pick_attack_target(actor))
	var name := actor.unit.get_display_name()
	if primary == null or not is_instance_valid(primary.unit):
		_host._log("%s の攻撃は対象がいない" % name)
		await _wait(0.2)
		return
	var packets := _attack_packets(actor, primary)
	actor.unit.popup_battle_text("攻撃", Color(1.0, 0.95, 0.82))
	var board: BoardController = _host.board
	var home := board.stand_position_for(actor.unit)
	var dest := _approach(actor.unit.global_position, primary.unit.global_position, home.y)
	await _move(actor.unit, dest, STEP_TIME)
	await _wait(ATTACK_HIT_TIME)
	for packet in packets:
		var target: Fighter = packet["target"]
		if target == null or not target.alive or not is_instance_valid(target.unit):
			continue
		await _resolve_packet(actor, target, bool(packet["direct"]), bool(packet["aoe"]), forced)
	_finish_attack_kits(actor)
	if is_instance_valid(actor.unit) and not actor.unit.battle_ko:
		var back := board.stand_position_for(actor.unit)
		await _move(actor.unit, back, STEP_TIME)
	await _wait(ATTACK_AFTER_TIME)


func _resolve_packet(actor: Fighter, target: Fighter, direct: bool, aoe: bool, forced: bool) -> void:
	if direct and (actor.sheet_id == 3 or actor.sheet_id == 104):
		actor.kit["last_target_id"] = target.unit.get_instance_id()
	var attacker_name := actor.unit.get_display_name()
	var target_name := target.unit.get_display_name()
	var connected := forced or _roll_hit(target)
	if not connected:
		if direct:
			target.unit.popup_battle_text("外れ", Color(0.9, 0.9, 0.9))
			_host._log("%s の攻撃は %s に外れた" % [attacker_name, target_name])
		if direct and actor.sheet_id == 4:
			await _absorb_followup(actor, target)
		return
	var bonus := _kit_bonus(actor, target, false)
	var dealt := 0
	var crit := false
	if direct:
		var rolled := _roll_damage(actor, target, true, bonus, -1.0)
		dealt += int(rolled["amount"])
		crit = bool(rolled["crit"])
	if aoe:
		var splash := _roll_damage(actor, target, true, bonus, -1.0)
		dealt += int(splash["amount"])
		crit = crit or bool(splash["crit"])
	var raw := dealt
	var guarded := target.guarding and raw > 0
	dealt = _mitigate(target, raw)
	var cap_before := dealt
	dealt = _ktrnksy_cap(target, dealt, direct)
	_play_attack_sounds(actor, crit)
	var absorbed := _apply_damage(target, dealt)
	if guarded:
		target.unit.popup_battle_text("ガード", Color(0.62, 0.84, 1.0))
	if dealt > 0:
		var color := Color(1.0, 0.86, 0.35) if crit else Color(1.0, 0.95, 0.9)
		target.unit.popup_battle_text("-%d" % dealt, color)
	_host._log(_damage_log(attacker_name, target_name, raw, dealt, absorbed, crit, guarded, "ダメージ", cap_before))
	_on_damage_dealt(actor, target, dealt, absorbed)
	if target.guarding and target.alive and is_instance_valid(target.unit):
		target.unit.play_guard_hit_shake()
		await _wait(0.32)
	if actor.sheet_id == 4 and direct:
		await _absorb_followup(actor, target)
		return
	if not target.alive:
		await _ko(target)
		return
	if dealt > 0 and not target.guarding:
		await _flinch(target)


func _support(actor: Fighter) -> void:
	var kind := str(actor.kit.get("buff_kind", "highest_speed_bonus"))
	if actor.uses_buff:
		var ally := _buff_target(actor, kind)
		if ally == null:
			ally = actor
		_set_single_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
		ally.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
		_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
		_note_arita_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
	else:
		var foe := _debuff_target(actor)
		if foe == null or not is_instance_valid(foe.unit):
			_host._log("%s のデバフは対象がいない" % actor.unit.get_display_name())
			await _wait(0.25)
			return
		_add_debuff(actor, foe, kind, float(actor.kit.get("buff_amount", 0.0)))
		foe.unit.popup_battle_text("デバフ", Color(0.82, 0.55, 1.0))
		_host._log("%s が %s にデバフ（%s）" % [actor.unit.get_display_name(), foe.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
		if actor.enemy and not foe.enemy:
			_host.board.mark_debuffed_unit(foe.unit)
			_host._log("%s はデバフを受けた" % foe.unit.get_display_name())
			_release_stale_debuffs()
			_sync_queue()
	await _wait(BUFF_TIME)


func _guard(actor: Fighter) -> void:
	_set_guarding(actor, true)
	if is_instance_valid(actor.unit):
		actor.unit.hold_guard_pose()
	actor.unit.popup_battle_text("ガード", Color(0.62, 0.84, 1.0))
	_host._log("%s がガード" % actor.unit.get_display_name())
	await _wait(GUARD_TIME)


func _ko(fighter: Fighter) -> void:
	fighter.alive = false
	fighter.in_queue = false
	var unit := fighter.unit
	if not is_instance_valid(unit) or unit.battle_ko:
		return
	unit.battle_ko = true
	unit.stop_guard_hit_shake()
	unit.popup_battle_text("倒れた", Color(1.0, 0.45, 0.42))
	_host._log("%s が倒れた" % unit.get_display_name())
	_on_fighter_down(fighter)
	_refresh_bar()
	var duration := unit.play_battle_role("defeat")
	if duration > 0.0:
		await _wait(duration)
	else:
		var drop := unit.global_position
		drop.y -= 0.5
		var tween := _host.create_tween()
		tween.tween_property(unit, "global_position", drop, 0.3)
		tween.parallel().tween_property(unit, "rotation:x", 1.1, 0.3)
		await tween.finished
	if is_instance_valid(unit):
		unit.defeat_playing = false
		unit.visible = false


func _flinch(target: Fighter) -> void:
	if not is_instance_valid(target.unit):
		return
	var duration := target.unit.play_battle_role("hit")
	if duration <= 0.0:
		var board: BoardController = _host.board
		var stand := board.stand_position_for(target.unit)
		var kicked := stand
		kicked.z += 0.1 if target.enemy else -0.1
		var tween := _host.create_tween()
		tween.tween_property(target.unit, "global_position", kicked, 0.07)
		tween.tween_property(target.unit, "global_position", stand, 0.1)
		await tween.finished
		return
	await _wait(duration)
	if target.alive and is_instance_valid(target.unit) and not target.unit.battle_ko:
		target.unit.play_battle_role("idle")


func _sync_queue() -> void:
	var board: BoardController = _host.board
	var present: Dictionary = {}
	for unit in board.front_units(false):
		var ally: GameUnit = unit as GameUnit
		if ally == null or ally.battle_ko:
			continue
		present[ally] = false
	for unit in board.front_units(true):
		var enemy: GameUnit = unit as GameUnit
		if enemy == null or enemy.battle_ko:
			continue
		present[enemy] = true
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not is_instance_valid(fighter.unit):
			continue
		var on_front: bool = present.has(fighter.unit)
		if fighter.in_queue and (not on_front or not fighter.alive):
			if fighter.alive:
				fighter.saved_ap = fighter.ap
			fighter.in_queue = false
	for unit_key in present.keys():
		var unit: GameUnit = unit_key as GameUnit
		var fighter := _fighter(unit, unit.circle_slot)
		fighter.enemy = bool(present[unit])
		fighter.stand_slot = board.front_slot_of(unit)
		if not fighter.alive:
			continue
		if not fighter.in_queue:
			if fighter.entered_once:
				fighter.ap = fighter.saved_ap
			else:
				fighter.ap = fighter.base_ap
				fighter.entered_once = true
			fighter.in_queue = true
		unit.action_value = fighter.ap
		unit.set_battle_hp(fighter.hp, fighter.max_hp)
		_show_gauge(fighter)
	_publish_waiting_ap(board)
	_refresh_bar()


func _publish_waiting_ap(board: BoardController) -> void:
	var seen: Dictionary = {}
	for slot_index in BoardController.SLOTS_PER_FACE:
		var ally := board.get_resolved_unit(board.active_face, slot_index)
		if ally != null and not seen.has(ally):
			seen[ally] = true
			_publish_unit_ap(ally, slot_index)
	for unit in board.enemy_units():
		var enemy: GameUnit = unit as GameUnit
		if enemy == null or seen.has(enemy):
			continue
		seen[enemy] = true
		_publish_unit_ap(enemy, enemy.circle_slot)


func _publish_unit_ap(unit: GameUnit, slot_hint: int) -> void:
	if unit.battle_ko:
		return
	var fighter := _fighter(unit, slot_hint)
	if fighter.in_queue:
		unit.action_value = fighter.ap
	elif fighter.entered_once:
		unit.action_value = fighter.saved_ap
	else:
		unit.action_value = fighter.base_ap


func _spend_action_points(spent: int, actor: Fighter, was_buff: bool) -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.in_queue or not fighter.alive or not is_instance_valid(fighter.unit):
			continue
		var before := fighter.ap
		fighter.ap = maxi(0, fighter.ap - spent)
		var lost := before - fighter.ap
		_shed_dot_layers(fighter, lost)
		if fighter != actor and lost > 0:
			_arita_on_ap_loss(fighter, was_buff)
		fighter.unit.action_value = fighter.ap
	if actor.alive and is_instance_valid(actor.unit):
		actor.ap = actor.base_ap
		actor.unit.action_value = actor.ap


func _shed_dot_layers(fighter: Fighter, lost: int) -> void:
	if lost <= 0 or fighter.start_ap <= 0:
		return
	for element in fighter.layers.keys():
		var count := int(fighter.layers[element])
		if count <= 0:
			continue
		var bank := int(fighter.dot_bank.get(element, 0)) + lost
		while count > 0 and bank >= fighter.start_ap:
			bank -= fighter.start_ap
			count -= 1
		fighter.layers[element] = count
		fighter.dot_bank[element] = bank


func _fighter(unit: GameUnit, slot_hint: int) -> Fighter:
	var key := unit.get_instance_id()
	if _fighters.has(key):
		return _fighters[key] as Fighter
	var fighter := Fighter.new()
	fighter.unit = unit
	fighter.enemy = unit.is_enemy
	_assign_placeholder(fighter, slot_hint)
	_apply_synergy_stats(fighter)
	_fighters[key] = fighter
	return fighter


func _assign_placeholder(fighter: Fighter, _slot_hint: int) -> void:
	var sheet := CharacterSheet.make(fighter.unit.unit_id, fighter.unit.stars)
	if not sheet.is_empty():
		_assign_sheet(fighter, sheet)
		return
	var unit := fighter.unit
	var speed := 78 + (absi(unit.unit_id) % 6) * 9 + unit.stars * 4
	_init_timing(fighter, speed)
	fighter.sheet_id = 0
	fighter.element = "fire"
	fighter.max_hp = 220 + unit.stars * 35
	fighter.hp = fighter.max_hp
	fighter.attack = 68.0 + float(unit.stars) * 14.0
	fighter.defense = 220.0 + float(absi(unit.unit_id) % 4) * 35.0
	fighter.crit_rate = 0.22
	fighter.crit_damage = 0.6
	fighter.priority = 80 + (absi(unit.unit_id) % 8) * 9
	fighter.uses_buff = true
	fighter.weight_attack = 5
	fighter.weight_buff = 3
	fighter.weight_guard = 2
	fighter.kit = {"buff_kind": "highest_speed_bonus", "buff_amount": 0.15}


func _assign_sheet(fighter: Fighter, sheet: Dictionary) -> void:
	fighter.sheet_id = fighter.unit.unit_id
	fighter.element = str(sheet["element"])
	fighter.element_damage = sheet["element_damage"]
	fighter.element_resist = sheet["element_resist"]
	fighter.max_hp = int(sheet["hp"])
	fighter.hp = fighter.max_hp
	fighter.attack = float(sheet["attack"])
	fighter.defense = float(sheet["defense"])
	fighter.attribute_resist = float(sheet["attribute_resist"])
	fighter.priority = int(sheet["priority"])
	fighter.crit_rate = float(sheet["crit_rate"])
	fighter.crit_damage = float(sheet["crit_damage"])
	fighter.weight_attack = int(sheet["weight_attack"])
	fighter.weight_buff = int(sheet["weight_buff"])
	fighter.weight_guard = int(sheet["weight_guard"])
	fighter.uses_buff = bool(sheet["uses_buff"])
	fighter.barrier = int(sheet.get("barrier_max", 0))
	_init_timing(fighter, int(sheet["speed"]))
	fighter.kit = sheet.duplicate(true)
	fighter.kit["base_speed"] = int(sheet["speed"])
	fighter.kit["fire_ramp"] = 0.0
	fighter.kit["ramp_ids"] = {}
	fighter.kit["first_attack"] = true
	fighter.kit["empowered"] = false
	fighter.kit["force_hit"] = false
	_recompute_speed(fighter, true)
	fighter.ap = fighter.base_ap
	fighter.saved_ap = fighter.base_ap
	fighter.start_ap = fighter.base_ap
	if is_instance_valid(fighter.unit):
		fighter.unit.action_value = fighter.ap


func _roll_action(fighter: Fighter) -> String:
	var roll := randi() % 10
	if roll < fighter.weight_attack:
		return "attack"
	roll -= fighter.weight_attack
	if roll < fighter.weight_buff:
		return "buff"
	return "guard"


func _roll_hit(defender: Fighter) -> bool:
	var chance := clampf(1.05 - float(defender.speed) / 280.0, 0.55, 0.9)
	return randf() < chance


func _roll_damage(attacker: Fighter, defender: Fighter, allow_crit: bool, bonus_extra: float, attack_override: float, use_general_bonus: bool = true) -> Dictionary:
	var attack := attacker.attack if attack_override < 0.0 else attack_override
	var element := attacker.element
	var penetration := clampf(attacker.penetration, 0.0, 1.0)
	var defense_coef := 1000.0 / (1000.0 + defender.defense * (1.0 - penetration))
	var dealt_coef := 1.0 + bonus_extra
	if use_general_bonus:
		dealt_coef += attacker.bonus_damage
	var element_coef := 1.0 + float(attacker.element_damage.get(element, 0.0)) + _formation_bonus(attacker)
	var resist := float(defender.element_resist.get(element, 0.0)) + defender.attribute_resist
	if element == "thunder":
		resist += float(defender.kit.get("received_thunder_resist", 0.0))
	if element == "fire":
		resist += float(defender.kit.get("received_fire_resist", 0.0))
	var resist_coef := 1.0 - resist
	var taken_coef := 1.0 + defender.damage_taken
	var crit := allow_crit and randf() < attacker.crit_rate
	var crit_coef := (1.0 + attacker.crit_damage) if crit else 1.0
	var amount := attack * defense_coef * dealt_coef * element_coef * resist_coef * taken_coef * crit_coef
	if amount < 0.0:
		amount = 0.0
	var dealt := int(round(amount))
	if amount > 0.0 and dealt < 1:
		dealt = 1
	return {"amount": dealt, "crit": crit}


func _pick_target(actor: Fighter) -> Fighter:
	var pool: Array = []
	var best := -1
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.in_queue or not fighter.alive or fighter.enemy == actor.enemy:
			continue
		if not is_instance_valid(fighter.unit):
			continue
		pool.append(fighter)
		best = maxi(best, _threat(fighter))
	if pool.is_empty():
		return null
	var total := 0.0
	var weights: Array[float] = []
	for entry in pool:
		var fighter: Fighter = entry
		var gap := best - _threat(fighter)
		var weight := 1.0 / (1.0 + float(gap) * 0.04)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for index in pool.size():
		roll -= weights[index]
		if roll <= 0.0:
			return pool[index] as Fighter
	return pool[pool.size() - 1] as Fighter


func _lowest_hp_ally(actor: Fighter) -> Fighter:
	var chosen: Fighter = null
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.in_queue or not fighter.alive or fighter.enemy != actor.enemy:
			continue
		if chosen == null or fighter.hp < chosen.hp:
			chosen = fighter
	return chosen


func _next_actor() -> Fighter:
	var chosen: Fighter = null
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.in_queue or not fighter.alive:
			continue
		if chosen == null or _acts_before(fighter, chosen):
			chosen = fighter
	return chosen


func _acts_before(candidate: Fighter, current: Fighter) -> bool:
	if candidate.ap != current.ap:
		return candidate.ap < current.ap
	if candidate.unit.unit_id != current.unit.unit_id:
		return candidate.unit.unit_id < current.unit.unit_id
	return candidate.unit.get_instance_id() < current.unit.get_instance_id()


func _reinforce_allies() -> bool:
	var board: BoardController = _host.board
	if _face_has_living_back(board, board.active_face):
		await _spin_circle(BoardController.FRONT_COUNT)
		_host._log("後衛が前に出た")
		return true
	var next := _next_living_face(board)
	if next < 0:
		return false
	board.set_active_face(next)
	_host._log("%d面に移った" % [next + 1])
	if _face_has_living_back(board, board.active_face) and not _face_has_living_front(board, board.active_face):
		await _spin_circle(BoardController.FRONT_COUNT)
		_host._log("後衛が前に出た")
	return true


func _spin_circle(steps: int) -> void:
	var wheel: CircleWheel = _host._circle_wheel
	if wheel == null:
		var board: BoardController = _host.board
		board.rotate_active_face(steps)
		return
	await wheel.spin_steps(steps)


func _next_living_face(board: BoardController) -> int:
	var count := board.get_unlocked_face_count()
	for offset in range(1, count):
		var face := (board.active_face + offset) % count
		if _face_has_living(board, face):
			return face
	return -1


func _any_living_ally() -> bool:
	var board: BoardController = _host.board
	for face in board.get_unlocked_face_count():
		if _face_has_living(board, face):
			return true
	return false


func _face_has_living(board: BoardController, face: int) -> bool:
	for slot_index in BoardController.SLOTS_PER_FACE:
		if _slot_is_living(board, face, slot_index):
			return true
	return false


func _face_has_living_front(board: BoardController, face: int) -> bool:
	for slot_index in BoardController.FRONT_COUNT:
		if _slot_is_living(board, face, slot_index):
			return true
	return false


func _face_has_living_back(board: BoardController, face: int) -> bool:
	for slot_index in range(BoardController.FRONT_COUNT, BoardController.SLOTS_PER_FACE):
		if _slot_is_living(board, face, slot_index):
			return true
	return false


func _slot_is_living(board: BoardController, face: int, slot_index: int) -> bool:
	var unit := board.get_placed_unit(face, slot_index)
	return unit != null and is_instance_valid(unit) and not unit.battle_ko


func _alive_count(enemy: bool) -> int:
	var count := 0
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.in_queue and fighter.alive and fighter.enemy == enemy:
			count += 1
	return count


func _set_guarding(fighter: Fighter, active: bool) -> void:
	fighter.guarding = active


func _approach(from: Vector3, to: Vector3, height: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dest := to
	if flat.length() > 0.62:
		dest = to - flat.normalized() * 0.62
	dest.y = height
	return dest


func _move(unit: GameUnit, dest: Vector3, duration: float) -> void:
	if not is_instance_valid(unit) or _host == null:
		return
	if _motion != null:
		_motion.kill()
	_motion = _host.create_tween()
	_motion.tween_property(unit, "global_position", dest, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _motion.finished


func _wait(seconds: float) -> void:
	if _host == null or not _host.is_inside_tree():
		return
	await _host.get_tree().create_timer(seconds).timeout


func _refresh_bar() -> void:
	if _host == null:
		return
	if _host._formation != null and _host._circle_wheel != null:
		_host._formation.refresh_widgets()
		return
	if _host._action_order_bar != null:
		_host._action_order_bar.set_entries(_host.board.get_action_order())


func _apply_synergy_stats(fighter: Fighter) -> void:
	if not fighter.kit.has("base_speed"):
		fighter.kit["base_speed"] = fighter.speed
	var bonus := SynergyTracker.bonuses_for(fighter.unit, _host.board.get_circle_units())
	var hp_rate := float(bonus["hp"])
	if hp_rate != 0.0:
		fighter.max_hp = maxi(1, int(round(float(fighter.max_hp) * (1.0 + hp_rate))))
		fighter.hp = fighter.max_hp
	fighter.attack *= 1.0 + float(bonus["attack"])
	fighter.defense *= 1.0 + float(bonus["defense"])
	fighter.crit_damage += float(bonus["crit_damage"])
	fighter.penetration = clampf(fighter.penetration + float(bonus["penetration"]), 0.0, 0.95)
	fighter.bonus_damage += float(bonus["bonus_damage"])
	fighter.attribute_resist += float(bonus["attribute_resist"])
	fighter.damage_taken += float(bonus["damage_taken"])
	fighter.kit["gauge_rate"] = float(bonus["gauge_rate"])
	var speed_rate := float(bonus["speed"])
	if speed_rate != 0.0:
		var base_speed := int(fighter.kit.get("base_speed", fighter.speed))
		fighter.kit["synergy_speed"] = int(round(float(base_speed) * speed_rate))
		_recompute_speed(fighter, true)
		fighter.ap = fighter.base_ap
		fighter.saved_ap = fighter.base_ap
		fighter.start_ap = fighter.base_ap


func _show_gauge(fighter: Fighter) -> void:
	if not is_instance_valid(fighter.unit):
		return
	if not fighter.kit.has("gauge"):
		fighter.unit.set_battle_gauge(0, 0)
		return
	fighter.unit.set_battle_gauge(int(fighter.kit.get("gauge", 0)), 100)


func _scaled_gauge(fighter: Fighter, amount: int) -> int:
	if amount <= 0:
		return 0
	var rate := float(fighter.kit.get("gauge_rate", 0.0))
	return maxi(0, int(round(float(amount) * (1.0 + rate))))


func _init_timing(fighter: Fighter, speed: int) -> void:
	fighter.speed = maxi(1, speed)
	fighter.base_ap = maxi(1, int(round(float(AP_NUMERATOR) / float(fighter.speed))))
	fighter.ap = fighter.base_ap
	fighter.saved_ap = fighter.base_ap
	fighter.start_ap = fighter.base_ap


func _recompute_speed(fighter: Fighter, keep_ap: bool) -> void:
	var speed := int(fighter.kit.get("base_speed", fighter.speed))
	speed += int(fighter.kit.get("received_speed", 0))
	if fighter.sheet_id == 2 and int(fighter.kit.get("gauge", 0)) >= 50:
		speed += int(fighter.kit.get("gauge_speed", 0))
	if fighter.sheet_id == 3 and fighter.barrier > 0:
		speed += int(fighter.kit.get("barrier_speed", 0))
	speed -= int(fighter.kit.get("ayakawa_slow", 0))
	speed += int(fighter.kit.get("synergy_speed", 0))
	speed = maxi(1, speed)
	var old := maxi(1, fighter.speed)
	fighter.speed = speed
	fighter.base_ap = maxi(1, int(round(float(AP_NUMERATOR) / float(speed))))
	if not keep_ap:
		fighter.ap = maxi(0, int(round(float(fighter.ap) * float(old) / float(speed))))
	if is_instance_valid(fighter.unit):
		fighter.unit.action_value = fighter.ap


func _threat(fighter: Fighter) -> int:
	var value := fighter.priority
	if fighter.sheet_id == 3 and fighter.barrier > 0:
		value += int(fighter.kit.get("priority_bonus", 0))
	if fighter.sheet_id == 104 and int(fighter.kit.get("gauge", 0)) >= 50:
		value += int(fighter.kit.get("gauge_threat", 0))
	return value


func _damage_log(attacker_name: String, target_name: String, raw: int, dealt: int, hp_lost: int, crit: bool, guarded: bool, kind: String = "ダメージ", cap_before: int = -1) -> String:
	var text := "%s が %s に %d の%s" % [attacker_name, target_name, dealt, kind]
	if crit:
		text += "（クリティカル）"
	var before_cap := dealt if cap_before < 0 else cap_before
	if guarded:
		text += "。ガードで %d カット（ガードなしなら %d）" % [raw - before_cap, raw]
	if cap_before > dealt:
		text += "。被ダメージ上限で %d カット" % [cap_before - dealt]
	var soaked := dealt - hp_lost
	if soaked > 0:
		text += "。バリアが %d 吸収し、HPは %d 減った" % [soaked, hp_lost]
	return text


func _describe_effect(kind: String, amount: float) -> String:
	match kind:
		"highest_speed_bonus", "highest_attack_bonus":
			return "与ダメージ %+d%%" % int(round(amount * 100.0))
		"lowest_speed_speed":
			return "速度 %+d" % int(round(amount))
		"highest_cost_fire":
			return "炎ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_absorb":
			return "吸収ダメージ %+d%%" % int(round(amount * 100.0))
		"thunder_resist":
			return "雷耐性 %+d%%" % int(round(-amount * 100.0))
		"fire_resist":
			return "炎のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		_:
			return kind


func _mitigate(defender: Fighter, amount: int) -> int:
	if amount <= 0 or not defender.guarding:
		return amount
	return maxi(0, int(round(float(amount) / 2.5)))


func _apply_damage(target: Fighter, amount: int) -> int:
	if not is_instance_valid(target.unit):
		return 0
	var left := amount
	if left > 0 and target.barrier > 0:
		var soaked := mini(target.barrier, left)
		target.barrier -= soaked
		left -= soaked
		if target.barrier <= 0:
			target.kit["force_hit"] = true
			_recompute_speed(target, false)
			_host._log("%s のバリアが割れた" % target.unit.get_display_name())
	if left > 0:
		target.hp = maxi(0, target.hp - left)
	target.unit.set_battle_hp(target.hp, target.max_hp)
	_show_gauge(target)
	if target.hp <= 0:
		target.alive = false
		target.in_queue = false
	return left


func _kit_bonus(attacker: Fighter, defender: Fighter, is_dot: bool) -> float:
	var bonus := _neighbor_bonus(attacker)
	if is_dot:
		return bonus
	if attacker.element == "fire":
		bonus += float(attacker.kit.get("fire_ramp", 0.0))
		bonus += float(attacker.kit.get("received_fire", 0.0))
	if attacker.element == "ice" and bool(attacker.kit.get("empowered", false)):
		bonus += float(attacker.kit.get("ice_empower", 0.0))
	if attacker.element == "thunder" and attacker.barrier > 0:
		bonus += float(attacker.kit.get("barrier_damage", 0.0))
	if attacker.sheet_id == 6 and attacker.element == "earth":
		if bool(attacker.kit.get("first_attack", false)):
			bonus += float(attacker.kit.get("first_bonus", 0.0))
		else:
			bonus += float(defender.kit.get("ayakawa_vuln", 0.0))
	if int(defender.layers.get("absorb", 0)) > 0:
		bonus += float(attacker.kit.get("received_absorb", 0.0))
	return bonus


func _formation_bonus(attacker: Fighter) -> float:
	if attacker.enemy or attacker.stand_slot < 0 or attacker.stand_slot >= BoardController.FRONT_COUNT:
		return 0.0
	if attacker.element.is_empty():
		return 0.0
	var elements: Array[String] = ["", "", ""]
	for entry in _side(attacker.enemy):
		var ally: Fighter = entry
		if ally.stand_slot < 0 or ally.stand_slot >= BoardController.FRONT_COUNT:
			continue
		elements[ally.stand_slot] = ally.element
	var count := 0
	var index := attacker.stand_slot
	while index >= 0 and elements[index] == attacker.element:
		count += 1
		index -= 1
	index = attacker.stand_slot + 1
	while index < BoardController.FRONT_COUNT and elements[index] == attacker.element:
		count += 1
		index += 1
	if count >= 3:
		return FORMATION_LINE
	if count == 2:
		return FORMATION_PAIR
	return 0.0


func _neighbor_bonus(attacker: Fighter) -> float:
	if attacker.stand_slot < 0:
		return 0.0
	var total := 0.0
	for other in _side(attacker.enemy):
		var ally: Fighter = other
		if ally == attacker or absi(ally.stand_slot - attacker.stand_slot) != 1:
			continue
		total += float(ally.kit.get("neighbor", 0.0))
	return total


func _pick_attack_target(actor: Fighter) -> Fighter:
	if actor.sheet_id == 4:
		var forced := _layered_target(actor)
		if forced != null:
			return forced
	return _pick_target(actor)


func _layered_target(actor: Fighter) -> Fighter:
	var need := int(actor.kit.get("layer_threshold", 3))
	var chosen: Fighter = null
	var best := -1
	for entry in _opponents(actor):
		var foe: Fighter = entry
		var count := int(foe.layers.get("absorb", 0))
		if count < need:
			continue
		if chosen == null or count > best or (count == best and foe.unit.unit_id < chosen.unit.unit_id):
			chosen = foe
			best = count
	return chosen


func _attack_packets(actor: Fighter, primary: Fighter) -> Array:
	var packets: Array = []
	var splash := false
	var extras: Array = []
	if actor.sheet_id == 6 and bool(actor.kit.get("first_attack", false)):
		splash = true
		for entry in _opponents(actor):
			var foe: Fighter = entry
			if foe != primary:
				extras.append(foe)
	elif actor.sheet_id == 1 and bool(actor.kit.get("first_attack", false)):
		splash = true
		extras = _extra_enemies(actor, primary, int(actor.kit.get("extra_targets", 1)))
	packets.append({"target": primary, "direct": true, "aoe": splash})
	for entry in extras:
		packets.append({"target": entry, "direct": false, "aoe": true})
	return packets


func _extra_enemies(actor: Fighter, primary: Fighter, count: int) -> Array:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe != primary:
			pool.append(foe)
	var chosen: Array = []
	while chosen.size() < count and not pool.is_empty():
		var pick := _weighted_fighter(pool)
		if pick == null:
			break
		chosen.append(pick)
		pool.erase(pick)
	return chosen


func _weighted_fighter(pool: Array) -> Fighter:
	if pool.is_empty():
		return null
	var best := -1
	for entry in pool:
		var fighter: Fighter = entry
		best = maxi(best, _threat(fighter))
	var total := 0.0
	var weights: Array[float] = []
	for entry in pool:
		var fighter: Fighter = entry
		var weight := 1.0 / (1.0 + float(best - _threat(fighter)) * 0.04)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for index in pool.size():
		roll -= weights[index]
		if roll <= 0.0:
			return pool[index] as Fighter
	return pool[pool.size() - 1] as Fighter


func _finish_attack_kits(actor: Fighter) -> void:
	if actor.sheet_id == 1 or actor.sheet_id == 6:
		actor.kit["first_attack"] = false


func _on_damage_dealt(actor: Fighter, target: Fighter, dealt: int, _hp_lost: int) -> void:
	if dealt <= 0:
		return
	if actor.sheet_id == 1:
		var seen: Dictionary = actor.kit.get("ramp_ids", {})
		var target_id := target.unit.get_instance_id()
		if not seen.has(target_id):
			seen[target_id] = true
			actor.kit["ramp_ids"] = seen
			var ramp := float(actor.kit.get("fire_ramp", 0.0)) + float(actor.kit.get("fire_per_hit", 0.0))
			actor.kit["fire_ramp"] = minf(float(actor.kit.get("fire_cap", ramp)), ramp)
	if actor.sheet_id == 2 and bool(actor.kit.get("empowered", false)):
		actor.kit["empowered"] = false
	if actor.sheet_id == 3:
		var cap := int(actor.kit.get("barrier_max", actor.barrier))
		if actor.barrier < cap:
			actor.barrier = cap
			_recompute_speed(actor, false)
	if actor.sheet_id == 6 and bool(actor.kit.get("first_attack", false)) and not bool(target.kit.get("ayakawa_marked", false)):
		target.kit["ayakawa_marked"] = true
		target.kit["ayakawa_vuln"] = float(actor.kit.get("earth_vuln", 0.0))
		target.kit["ayakawa_slow"] = int(actor.kit.get("slow", 0))
		_recompute_speed(target, true)


func _absorb_followup(actor: Fighter, target: Fighter) -> void:
	_add_layers(target, "absorb", 1)
	if target.alive:
		await _apply_dot(actor, target)
	if not target.alive:
		await _ko(target)


func _add_layers(target: Fighter, element: String, count: int) -> void:
	target.layers[element] = int(target.layers.get(element, 0)) + count


func _play_attack_sounds(actor: Fighter, crit: bool) -> void:
	GameAudio.play_battle_attack()
	GameAudio.play_battle_attribute(actor.element)
	if crit:
		GameAudio.play_battle_critical()


func _apply_dot(actor: Fighter, target: Fighter) -> void:
	var stacks := int(target.layers.get(actor.element, 0))
	if stacks <= 0 or not target.alive:
		return
	GameAudio.play_battle_dot(stacks)
	var power := actor.attack * float(actor.kit.get("dot_ratio", 0.05)) * float(stacks)
	var rolled := _roll_damage(actor, target, false, _neighbor_bonus(actor), power, false)
	var raw := int(rolled["amount"])
	var guarded := target.guarding and raw > 0
	var dealt := _mitigate(target, raw)
	var absorbed := _apply_damage(target, dealt)
	if dealt > 0 and is_instance_valid(target.unit):
		target.unit.popup_battle_text("継続-%d" % dealt, Color(0.75, 0.45, 0.9))
	if is_instance_valid(actor.unit) and is_instance_valid(target.unit):
		_host._log(_damage_log(actor.unit.get_display_name(), target.unit.get_display_name(), raw, dealt, absorbed, false, guarded, "継続ダメージ"))


func _on_fighter_down(dead: Fighter) -> void:
	_clear_buffs_touching(dead)
	_release_stale_debuffs()
	if _living_sheet(not dead.enemy, 4) == null:
		return
	var amount := int(dead.layers.get("absorb", 0))
	if amount <= 0:
		return
	var highest := amount
	for entry in _side(dead.enemy):
		var other: Fighter = entry
		if other == dead:
			continue
		highest = maxi(highest, int(other.layers.get("absorb", 0)))
	if amount < highest:
		return
	var receiver: Fighter = null
	var least := 0
	for entry in _side(dead.enemy):
		var other: Fighter = entry
		if other == dead:
			continue
		var count := int(other.layers.get("absorb", 0))
		if receiver == null or count < least or (count == least and other.unit.unit_id < receiver.unit.unit_id):
			receiver = other
			least = count
	if receiver == null:
		return
	_add_layers(receiver, "absorb", amount)
	var azuchi := _living_sheet(not dead.enemy, 4)
	if azuchi == null or not receiver.alive:
		return
	_apply_dot(azuchi, receiver)
	if not receiver.alive and is_instance_valid(receiver.unit) and not receiver.unit.battle_ko:
		_ko(receiver)


func _buff_target(actor: Fighter, kind: String) -> Fighter:
	match kind:
		"lowest_speed_speed":
			return _extreme(_side(actor.enemy), "speed", false)
		"highest_attack_bonus", "highest_attack_absorb":
			return _extreme(_side(actor.enemy), "attack", true)
		"highest_cost_fire":
			return _extreme(_side(actor.enemy), "cost", true)
		_:
			return _extreme(_side(actor.enemy), "speed", true)


func _extreme(pool: Array, stat: String, highest: bool) -> Fighter:
	var chosen: Fighter = null
	var chosen_value := 0.0
	for entry in pool:
		var fighter: Fighter = entry
		var value := _stat(fighter, stat)
		if chosen == null or (highest and value > chosen_value) or (not highest and value < chosen_value) or (is_equal_approx(value, chosen_value) and fighter.unit.unit_id < chosen.unit.unit_id):
			chosen = fighter
			chosen_value = value
	return chosen


func _stat(fighter: Fighter, stat: String) -> float:
	match stat:
		"attack":
			return fighter.attack
		"cost":
			return float(fighter.unit.get_cost())
		"threat":
			return float(_threat(fighter))
		_:
			return float(fighter.speed)


func _debuff_target(actor: Fighter) -> Fighter:
	var last := _fighter_by_id(int(actor.kit.get("last_target_id", -1)))
	if last != null and last.alive and last.enemy != actor.enemy:
		return last
	return _extreme(_opponents(actor), "threat", true)


func _add_debuff(actor: Fighter, target: Fighter, kind: String, amount: float) -> void:
	if not is_instance_valid(target.unit):
		return
	_apply_buff_value(target, kind, amount)
	var list: Array = actor.kit.get("debuffs", [])
	list.append({
		"target_id": target.unit.get_instance_id(),
		"kind": kind,
		"amount": amount,
	})
	actor.kit["debuffs"] = list


func _clear_debuffs_on_target(target_id: int) -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		var list: Array = fighter.kit.get("debuffs", [])
		if list.is_empty():
			continue
		var kept: Array = []
		for entry in list:
			var item: Dictionary = entry
			if int(item.get("target_id", -1)) != target_id:
				kept.append(item)
				continue
			var target := _fighter_by_id(target_id)
			if target != null:
				_apply_buff_value(target, str(item.get("kind", "")), -float(item.get("amount", 0.0)))
		fighter.kit["debuffs"] = kept


func _set_single_buff(actor: Fighter, target: Fighter, kind: String, amount: float) -> void:
	_clear_single_buff(actor)
	_apply_buff_value(target, kind, amount)
	actor.kit["buff_target_id"] = target.unit.get_instance_id()
	actor.kit["buff_kind_active"] = kind
	actor.kit["buff_amount_active"] = amount


func _apply_buff_value(target: Fighter, kind: String, amount: float) -> void:
	match kind:
		"highest_speed_bonus", "highest_attack_bonus":
			target.bonus_damage += amount
		"lowest_speed_speed":
			target.kit["received_speed"] = int(target.kit.get("received_speed", 0)) + int(round(amount))
			_recompute_speed(target, false)
		"highest_cost_fire":
			target.kit["received_fire"] = float(target.kit.get("received_fire", 0.0)) + amount
		"highest_attack_absorb":
			target.kit["received_absorb"] = float(target.kit.get("received_absorb", 0.0)) + amount
		"thunder_resist":
			target.kit["received_thunder_resist"] = float(target.kit.get("received_thunder_resist", 0.0)) - amount
		"fire_resist":
			target.kit["received_fire_resist"] = float(target.kit.get("received_fire_resist", 0.0)) - amount


func _clear_single_buff(actor: Fighter) -> void:
	var target := _fighter_by_id(int(actor.kit.get("buff_target_id", -1)))
	if target != null:
		_apply_buff_value(target, str(actor.kit.get("buff_kind_active", "")), -float(actor.kit.get("buff_amount_active", 0.0)))
	actor.kit["buff_target_id"] = -1


func _clear_copy(arita: Fighter) -> void:
	var target := _fighter_by_id(int(arita.kit.get("copy_target_id", -1)))
	if target != null:
		_apply_buff_value(target, str(arita.kit.get("copy_kind", "")), -float(arita.kit.get("copy_amount", 0.0)))
	arita.kit["copy_target_id"] = -1
	arita.kit["copy_amount"] = 0.0


func _clear_buffs_touching(dead: Fighter) -> void:
	if not is_instance_valid(dead.unit):
		return
	var dead_id := dead.unit.get_instance_id()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter == dead and fighter.uses_buff:
			_clear_single_buff(fighter)
		elif int(fighter.kit.get("buff_target_id", -1)) == dead_id:
			_clear_single_buff(fighter)
		if fighter == dead or int(fighter.kit.get("copy_target_id", -1)) == dead_id:
			_clear_copy(fighter)
	_clear_debuffs_on_target(dead_id)


func _note_arita_buff(actor: Fighter, target: Fighter, kind: String, amount: float) -> void:
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if ally.sheet_id != 5:
			continue
		ally.kit["last_buffer_id"] = actor.unit.get_instance_id()
		ally.kit["last_kind"] = kind
		ally.kit["last_target_id"] = target.unit.get_instance_id()
		ally.kit["last_amount"] = amount
		if int(ally.kit.get("gauge", 0)) >= 100:
			_arita_copy(ally)
			ally.kit["gauge"] = 0
			_show_gauge(ally)


func _arita_copy(arita: Fighter) -> void:
	_clear_copy(arita)
	var target := _fighter_by_id(int(arita.kit.get("last_target_id", -1)))
	if target == null or not target.alive:
		return
	var kind := str(arita.kit.get("last_kind", ""))
	var amount := float(arita.kit.get("last_amount", 0.0))
	_apply_buff_value(target, kind, amount)
	arita.kit["copy_target_id"] = target.unit.get_instance_id()
	arita.kit["copy_kind"] = kind
	arita.kit["copy_amount"] = amount
	_host._log("%s が %s へのバフをコピー（%s）" % [arita.unit.get_display_name(), target.unit.get_display_name(), _describe_effect(kind, amount)])


func _arita_skips(actor: Fighter) -> bool:
	if actor.sheet_id != 5 or int(actor.kit.get("gauge", 0)) < 100:
		return false
	var ally := _fighter_by_id(int(actor.kit.get("last_buffer_id", -1)))
	if ally == null or ally == actor or not ally.alive or not ally.in_queue:
		return false
	return true


func _arita_on_ap_loss(fighter: Fighter, was_buff: bool) -> void:
	if fighter.sheet_id != 5 or not fighter.alive or int(fighter.kit.get("gauge", 0)) >= 100:
		return
	fighter.kit["gauge"] = int(fighter.kit.get("gauge", 0)) + _scaled_gauge(fighter, int(fighter.kit.get("gauge_step", 10)))
	GameAudio.play_battle_gauge()
	if int(fighter.kit.get("gauge", 0)) < 100:
		_show_gauge(fighter)
		return
	if was_buff:
		_arita_copy(fighter)
		fighter.kit["gauge"] = 0
	else:
		fighter.kit["gauge"] = 100
	_show_gauge(fighter)


func _cover_for_ktrnksy(actor: Fighter, primary: Fighter) -> Fighter:
	if primary == null or not primary.alive or actor.enemy == primary.enemy:
		return primary
	var chosen: Fighter = null
	var best := -1
	for entry in _side(primary.enemy):
		var ally: Fighter = entry
		if ally.sheet_id != 104 or ally == primary or not ally.alive or ally.hp <= 0:
			continue
		if not bool(ally.kit.get("cover_armed", false)) or bool(ally.kit.get("cover_used", false)):
			continue
		var threat := _threat(ally)
		if _threat(primary) >= threat:
			continue
		if chosen == null or threat > best or (threat == best and ally.unit.unit_id < chosen.unit.unit_id):
			chosen = ally
			best = threat
	if chosen == null:
		return primary
	chosen.kit["cover_used"] = true
	chosen.kit["cover_armed"] = false
	_host._log("%s が %s の代わりに攻撃を受ける" % [chosen.unit.get_display_name(), primary.unit.get_display_name()])
	return chosen


func _ktrnksy_cap(target: Fighter, amount: int, direct: bool) -> int:
	if target.sheet_id != 104 or amount <= 0 or not target.alive or target.hp <= 0:
		return amount
	var ratio := float(target.kit.get("cap_ratio", 0.5))
	var tight := direct and bool(target.kit.get("tight_cap", false))
	if tight:
		ratio = maxf(0.0, ratio - float(target.kit.get("full_cap_cut", 0.0)))
	var capped := mini(amount, maxi(0, int(round(float(target.max_hp) * ratio))))
	if tight and amount > 0:
		target.kit["tight_cap"] = false
	return capped


func _ktrnksy_on_ally_action(actor: Fighter) -> void:
	if not is_instance_valid(actor.unit) or not _has_synergy(actor, "ギリシャ語通訳"):
		return
	var step := _greek_gauge_step(actor.enemy)
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if ally.sheet_id != 104 or not ally.alive or ally.hp <= 0:
			continue
		_ktrnksy_add_gauge(ally, step)


func _greek_gauge_step(enemy: bool) -> int:
	var count := 0
	for entry in _side(enemy):
		var ally: Fighter = entry
		if ally.alive and ally.hp > 0 and _has_synergy(ally, "ギリシャ語通訳"):
			count += 1
	if count >= 9:
		return 18
	if count >= 7:
		return 16
	if count >= 5:
		return 14
	if count >= 3:
		return 12
	return 10


func _has_synergy(fighter: Fighter, synergy_name: String) -> bool:
	if not is_instance_valid(fighter.unit):
		return false
	return synergy_name in SynergyTracker.names_of(fighter.unit.unit_id)


func _ktrnksy_add_gauge(fighter: Fighter, step: int) -> void:
	var gain := _scaled_gauge(fighter, step)
	if gain <= 0 or not is_instance_valid(fighter.unit):
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + gain
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		_host._log("%s のゲージが %d になった" % [fighter.unit.get_display_name(), gauge])
		return
	fighter.kit["gauge"] = 0
	_show_gauge(fighter)
	fighter.kit["tight_cap"] = true
	if not bool(fighter.kit.get("cover_used", false)):
		fighter.kit["cover_armed"] = true
	fighter.ap = 0
	fighter.unit.action_value = 0
	fighter.unit.popup_battle_text("ゲージ", Color(1.0, 0.72, 0.28))
	_host._log("%s のゲージが満ち、行動が回る" % fighter.unit.get_display_name())


func _kits_after_turn(actor: Fighter, was_buff: bool) -> void:
	_ktrnksy_on_ally_action(actor)
	if not actor.alive:
		return
	if actor.sheet_id == 2:
		var gauge := int(actor.kit.get("gauge", 0)) + _scaled_gauge(actor, 10)
		if was_buff:
			gauge += _scaled_gauge(actor, int(actor.kit.get("gauge_buff_extra", 0)))
		GameAudio.play_battle_gauge()
		if gauge >= 100:
			actor.kit["gauge"] = 0
			actor.kit["empowered"] = true
			_host._log("%s の次の氷攻撃が強くなる" % actor.unit.get_display_name())
		else:
			actor.kit["gauge"] = gauge
		_show_gauge(actor)
		_recompute_speed(actor, false)
	if actor.sheet_id == 5:
		_arita_on_ap_loss(actor, was_buff)


func _fighter_by_id(instance_id: int) -> Fighter:
	if instance_id < 0 or not _fighters.has(instance_id):
		return null
	var fighter: Fighter = _fighters[instance_id]
	if not is_instance_valid(fighter.unit):
		return null
	return fighter


func _side(enemy: bool) -> Array:
	var found: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy == enemy and fighter.alive and fighter.in_queue and is_instance_valid(fighter.unit):
			found.append(fighter)
	return found


func _opponents(actor: Fighter) -> Array:
	return _side(not actor.enemy)


func _living_sheet(enemy: bool, sheet_id: int) -> Fighter:
	for entry in _side(enemy):
		var fighter: Fighter = entry
		if fighter.sheet_id == sheet_id:
			return fighter
	return null
