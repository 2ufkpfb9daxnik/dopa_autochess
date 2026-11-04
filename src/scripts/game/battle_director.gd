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
const BUFF_TIME := 0.35
const STATUS_RISE_TIME := 0.28
const STATUS_FLY_TIME := 0.38
const STATUS_FALL_TIME := 0.32
## 撃破ゲージの最大と1回分。設計書が「ここでは決めない」のため暫定。
const BREAK_MAX := 3
const BREAK_STEP := 1
const BREAK_SYNERGY := {
	"fire": "金縁の鼻眼鏡",
	"water": "東雲",
	"thunder": "ユーザー・アンノウン",
	"earth": "ディープ・アーキテクチャ",
	"ice": "ヨッパ谷への降下",
	"wind": "オレンジの種五つ",
	"absorb": "伊豆は飛鳥",
}

var _host: Node
var _fighters: Dictionary = {}
var _motion: Tween
var _relic_started := false
var _relic_blocks := 0
var _relic_actions := 0
var _relic36_done := false
var _relic32_done := false
var _relic31_left := 0
var _growth_killer: Fighter = null


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
	var break_left: Dictionary = {}
	var kit: Dictionary = {}
	var damage_taken := 0.0
	var crit_rate := 0.0
	var crit_damage := 0.0
	var relic_ids: Array[int] = []
	var relic_attack_pen := 0.0
	var relic_element_bonus := 0.0
	var relic_flat_damage := 0.0
	var relic_opening_bonus := 0.0
	var relic_opening := false
	var relic_low_bonus := 0.0
	var relic_taken_cut := 0.0
	var relic_heal_ratio := 0.0
	var relic_heal_left := 0
	var relic_layers := 0
	var relic_weaken_cut := 0.0
	var relic_weaken_left := 0
	var relic_weaken_source := 0
	var relic_mark_id := 0
	var relic_weaken_now := 0.0
	var relic_speed_step := 0
	var relic_speed_cap := 0
	var relic_speed_stack := 0
	var relic_chase_left := 0
	var relic_killed := false
	var relic_neighbor := false
	var relic_next_cut := 0.0
	var relic_fallen_bonus := 0.0
	var relic_slay_bonus := 0.0
	var relic_start_row := -1
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
	_relic_started = false
	_relic_blocks = 0
	_relic_actions = 0
	_relic36_done = false
	_relic32_done = false
	_relic31_left = 0
	var opening_done := false
	var won := false
	while _host != null and _host.is_inside_tree():
		_sync_queue()
		if not opening_done:
			opening_done = true
			await _opening_kits()
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
			await _spend_action_points(spent, actor, false)
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
		_relic_after_action(actor)
		if _host == null or not _host.is_inside_tree():
			break
		await _spend_action_points(spent, actor, was_buff)
		if actor.alive and is_instance_valid(actor.unit):
			actor.ap = actor.base_ap
			actor.unit.action_value = actor.ap
		await _kits_after_turn(actor, was_buff)
		_refresh_bar()
	var remaining := _alive_count(true)
	_relic_on_battle_end()
	finish()
	return {"won": won, "remaining": remaining}


func cleanse_debuff(unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_clear_debuffs_on_target(unit.get_instance_id())
	_host.board.restore_debuffed_unit(unit)
	_refresh_unit_aura(unit)
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
	_era6_on_finish()
	_clear_battle_debuffs()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		var unit := fighter.unit
		if unit == null or not is_instance_valid(unit):
			continue
		unit.clear_status_auras()
		if unit.is_enemy:
			continue
		unit.battle_ko = false
		unit.stop_guard_hit_shake()
		unit.rotation.x = 0.0
		unit.release_battle_clip()
		unit.set_battle_walking(false)
		unit.refresh_visuals()


func _act(actor: Fighter) -> bool:
	if bool(actor.kit.get("skip_next_action", false)):
		actor.kit["skip_next_action"] = false
		if is_instance_valid(actor.unit):
			actor.unit.popup_battle_text("行動しない", Color(0.75, 0.8, 0.9))
			_host._log("%s は行動しない" % actor.unit.get_display_name())
		await _wait(0.18)
		return false
	if bool(actor.kit.get("force_guard_next", false)):
		actor.kit["force_guard_next"] = false
		actor.guarding = true
		if is_instance_valid(actor.unit):
			actor.unit.play_battle_role("guard")
			actor.unit.popup_battle_text("ガード", Color(0.62, 0.84, 1.0))
		await _wait(0.2)
		return false
	if actor.sheet_id == 88 and bool(actor.kit.get("aoe_pending", false)):
		await _miyake_release_aoe(actor)
	if _consume_action_skip(actor):
		if is_instance_valid(actor.unit):
			actor.unit.play_battle_role("idle")
			actor.unit.popup_battle_text("行動しない", Color(0.7, 0.85, 1.0))
			_host._log("%s は行動しない" % actor.unit.get_display_name())
		await _wait(0.22)
		return false
	if bool(actor.kit.get("force_attack", false)):
		actor.kit["force_attack"] = false
		actor.kit["did_force_attack"] = true
		if is_instance_valid(actor.unit):
			actor.unit.play_battle_role("attack")
		await _attack(actor)
		if actor.alive and is_instance_valid(actor.unit) and not actor.unit.battle_ko and not actor.guarding:
			actor.unit.play_battle_role("idle")
		await _wait(0.08)
		return false
	var action := _roll_action(actor)
	if not is_instance_valid(actor.unit):
		return false
	var tamba_redirect := _tamba_maybe_redirect(actor, action)
	if action != "guard":
		actor.unit.play_battle_role(action)
	match action:
		"attack":
			if tamba_redirect != null:
				await _attack(actor, false, tamba_redirect)
			else:
				await _attack(actor)
		"buff":
			if tamba_redirect != null and actor.uses_buff:
				await _play_status_transfer(actor.unit, tamba_redirect.unit, true)
				_set_single_buff(actor, tamba_redirect, str(actor.kit.get("buff_kind", "")), float(actor.kit.get("buff_amount", 0.0)))
				tamba_redirect.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
				await _wait(BUFF_TIME)
			else:
				await _support(actor)
		_:
			if tamba_redirect != null:
				actor.kit["proxy_guard_for_id"] = tamba_redirect.unit.get_instance_id()
				actor.guarding = true
				if is_instance_valid(actor.unit):
					actor.unit.play_battle_role("guard")
					actor.unit.popup_battle_text("代行ガード", Color(0.62, 0.84, 1.0))
				await _wait(0.2)
			else:
				await _guard(actor)
	if actor.alive and is_instance_valid(actor.unit) and not actor.unit.battle_ko and not actor.guarding:
		actor.unit.play_battle_role("idle")
	await _wait(0.08)
	return action == "buff"


func _attack(actor: Fighter, from_chase: bool = false, forced_target: Fighter = null) -> void:
	var forced := false
	if actor.sheet_id == 3 and bool(actor.kit.get("force_hit", false)):
		forced = true
		actor.kit["force_hit"] = false
	if actor.sheet_id == 47 and actor.element == "thunder" and int(actor.kit.get("force_hit_left", 0)) > 0:
		forced = true
		actor.kit["force_hit_left"] = int(actor.kit.get("force_hit_left", 0)) - 1
	if actor.sheet_id == 62 and bool(actor.kit.get("nagano_force_hit_armed", false)):
		forced = true
		actor.kit["nagano_force_hit_armed"] = false
	if float(actor.kit.get("outgoing_cut", 0.0)) > 0.0:
		actor.kit["outgoing_cut"] = 0.0
	var ikeda_armed := actor.sheet_id == 9 and bool(actor.kit.get("multi_armed", false))
	var inabe_charged := actor.sheet_id == 13 and bool(actor.kit.get("charged_ready", false))
	var picked := forced_target if forced_target != null else _pick_attack_target(actor)
	var primary := _cover_for_ktrnksy(actor, picked)
	var name := actor.unit.get_display_name()
	if primary == null or not is_instance_valid(primary.unit):
		_host._log("%s の攻撃は対象がいない" % name)
		await _wait(0.2)
		return
	actor.kit["last_attack_target_id"] = primary.unit.get_instance_id()
	actor.kit["did_attack"] = true
	_era6_begin_attack(actor)
	actor.kit["attack_no_crit"] = false
	actor.kit["bare_fire"] = false
	actor.kit["charged_strike"] = false
	if inabe_charged:
		actor.kit["charged_ready"] = false
		actor.kit["charged_strike"] = true
		forced = true
	if actor.sheet_id == 18 and actor.element == "fire":
		actor.kit["bare_fire"] = not _unit_has_buff(primary.unit)
	if actor.sheet_id == 88 and bool(actor.kit.get("aoe_pending", false)):
		await _miyake_release_aoe(actor)
	if actor.sheet_id == 61 and bool(actor.kit.get("extra_earth_armed", false)):
		await _torahime_extra_strike(actor)
	var opening := RelicCombat.begin_attack(actor)
	var speed_before := actor.relic_speed_stack
	var packets := _attack_packets(actor, primary)
	actor.kit["continuity_done"] = false
	actor.unit.popup_battle_text("攻撃", Color(1.0, 0.95, 0.82))
	var board: BoardController = _host.board
	var home := board.stand_position_for(actor.unit)
	var dest := _approach(actor.unit.global_position, primary.unit.global_position, home.y)
	await _move(actor.unit, dest, STEP_TIME)
	await _wait(ATTACK_HIT_TIME)
	var nawate_hit: Dictionary = {}
	for packet in packets:
		var target: Fighter = packet["target"]
		if target == null or not target.alive or not is_instance_valid(target.unit):
			continue
		var direct := bool(packet["direct"])
		await _resolve_packet(actor, target, direct, bool(packet["aoe"]), forced or opening)
		_era3_on_crit(actor)
		_era5_after_packet(actor, target, direct)
		if is_instance_valid(target.unit):
			nawate_hit[target.unit.get_instance_id()] = true
		## ナワテ: 風撃破したその攻撃で、まだ当たっていない敵へ全体範囲を足す。
		if actor.sheet_id == 67 and bool(actor.kit.get("nawate_full_aoe", false)) and direct:
			actor.kit["nawate_full_aoe"] = false
			actor.kit["nawate_aoe_crit"] = true
			for entry_n in _opponents(actor):
				var foe_n: Fighter = entry_n
				if foe_n == null or not foe_n.alive or not is_instance_valid(foe_n.unit):
					continue
				if nawate_hit.has(foe_n.unit.get_instance_id()):
					continue
				nawate_hit[foe_n.unit.get_instance_id()] = true
				await _resolve_packet(actor, foe_n, false, true, forced or opening)
				_era5_after_packet(actor, foe_n, false)
	actor.kit["tarumi_aoe_resolving"] = false
	actor.kit["nawate_aoe_crit"] = false
	actor.kit["nawate_full_aoe"] = false
	if actor.sheet_id == 61 and float(actor.kit.get("torahime_pending_earth", 0.0)) > 0.0 and not bool(actor.kit.get("extra_earth_armed", false)):
		actor.kit["torahime_pending_earth"] = 0.0
	await _era5_finish_attack(actor, primary)
	await _era6_finish_attack(actor, primary)
	if ikeda_armed:
		actor.kit["multi_armed"] = false
		await _ikeda_extra_hits(actor, primary)
	if actor.element == "absorb" and primary != null:
		await _ise_follow_attacks(actor, primary)
	actor.kit["charged_strike"] = false
	actor.kit["bare_fire"] = false
	actor.kit["attack_no_crit"] = false
	if actor.sheet_id == 16 and actor.element == "water":
		actor.kit["splash_retarget_left"] = 0
	RelicCombat.finish_attack(actor)
	if actor.relic_speed_stack != speed_before:
		_recompute_speed(actor, true)
	await _finish_attack_kits(actor)
	if actor.sheet_id == 88 and primary != null and is_instance_valid(primary.unit):
		await _miyake_store_aoe(actor, primary)
	if is_instance_valid(actor.unit) and not actor.unit.battle_ko:
		var back := board.stand_position_for(actor.unit)
		await _move(actor.unit, back, STEP_TIME)
	await _wait(ATTACK_AFTER_TIME)
	if from_chase or not actor.relic_killed or actor.relic_chase_left <= 0 or not actor.alive:
		return
	var chase := _relic_chase_target(actor)
	if chase == null:
		return
	actor.relic_chase_left -= 1
	await _attack(actor, true, chase)


func _resolve_packet(actor: Fighter, target: Fighter, direct: bool, aoe: bool, forced: bool) -> void:
	if direct and (actor.sheet_id == 3 or actor.sheet_id == 104):
		actor.kit["last_target_id"] = target.unit.get_instance_id()
	if direct and target.sheet_id == 10 and not bool(target.kit.get("first_hit_done", false)):
		_izumi_on_first_targeted(actor, target)
	if direct:
		_note_primary_target_effects(actor, target)
	var attacker_name := actor.unit.get_display_name()
	var target_name := target.unit.get_display_name()
	var connected := forced or _roll_hit(target)
	var broke := false
	if direct:
		broke = _reduce_break_gauge(actor, target)
		_era4_note_break(actor, target, broke)
		_era6_note_break(actor, target, broke)
		if broke and actor.sheet_id == 67 and actor.element == "wind" and int(actor.kit.get("aoe_charges_left", 0)) > 0:
			actor.kit["nawate_full_aoe"] = true
			actor.kit["aoe_charges_left"] = int(actor.kit.get("aoe_charges_left", 0)) - 1
	if not connected:
		if direct:
			GameAudio.play_battle_miss()
			target.unit.popup_battle_text("外れ", Color(0.9, 0.9, 0.9))
			_host._log("%s の攻撃は %s に外れた" % [attacker_name, target_name])
			_sumoto_on_miss(actor, target)
			## 命中しなくても層と継続は、攻撃ヒットと同じタイミングで出す。
			await _continuity_with_attack(actor, target)
			await _on_attack_contact(actor, target, false, 0, false)
		if direct and actor.sheet_id == 4:
			await _absorb_followup(actor, target)
		if direct and actor.sheet_id == 7:
			await _awaji_after_ice_attack(actor, target, broke)
		return
	if direct and target.sheet_id == 14 and target.alive and target.hp > 0:
		_ibaraki_before_hit(target)
	if direct and broke and actor.element == "thunder" and _sumoto_active(actor.enemy):
		actor.kit["force_crit_break"] = true
	var bonus := _kit_bonus(actor, target, false)
	var dealt := 0
	var crit := false
	var direct_crit := false
	if direct:
		var rolled := _roll_damage(actor, target, true, bonus, -1.0)
		dealt += int(rolled["amount"])
		crit = bool(rolled["crit"])
		direct_crit = crit
		if crit and actor.element == "water" and bool(actor.kit.get("tatsuno_break_armed", false)) and _has_synergy(actor, "東雲"):
			var extra := maxi(1, int(actor.kit.get("break_extra_pending", 1)))
			actor.kit["tatsuno_break_armed"] = false
			actor.kit["break_extra_pending"] = 0
			for _i in extra:
				var left_b := int(target.break_left.get("water", BREAK_MAX))
				if left_b <= 0:
					break
				target.break_left["water"] = maxi(0, left_b - BREAK_STEP)
				if int(target.break_left["water"]) <= 0:
					target.break_left["water"] = BREAK_MAX
					broke = true
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
	_play_hit_fx(actor, target)
	var absorbed := _apply_damage(target, dealt)
	var attack_ko := not target.alive
	if guarded:
		target.unit.popup_battle_text("ガード", Color(0.62, 0.84, 1.0))
	if dealt > 0:
		var color := Color(1.0, 0.86, 0.35) if crit else Color(1.0, 0.95, 0.9)
		target.unit.popup_battle_text("-%d" % dealt, color)
	_host._log(_damage_log(attacker_name, target_name, raw, dealt, absorbed, crit, guarded, "ダメージ", cap_before))
	await _on_damage_dealt(actor, target, dealt, absorbed)
	## 継続ダメージは行動のあとではなく、攻撃と同時に出す。
	if direct:
		await _continuity_with_attack(actor, target)
	await _on_attack_contact(actor, target, true, dealt, direct)
	if dealt > 0:
		await _note_hit_received(actor, target, false)
	if not target.alive:
		if actor.sheet_id == 42:
			_suita_add_gauge(actor, _bistron_gauge_step(actor.enemy))
		if actor.sheet_id == 88:
			await _miyake_add_gauge(actor, _bistron_gauge_step(actor.enemy))
	if direct and actor.sheet_id == 7:
		await _awaji_after_ice_attack(actor, target, broke)
	if direct and broke and actor.sheet_id == 14 and actor.element == "water":
		_ibaraki_on_break(actor)
	var relic_layered := false
	if direct and connected:
		var before_layers := int(target.layers.get(actor.element, 0))
		RelicCombat.on_direct_hit(actor, target, _fighters)
		relic_layered = int(target.layers.get(actor.element, 0)) > before_layers
		RelicCombat.note_front_hit(target, _fighters, _host.board)
		if direct_crit:
			var layer_bearer = RelicCombat.crit_layer_bearer(actor, _fighters, _relic31_left, _host.board)
			if layer_bearer != null:
				_relic31_left -= 1
				_add_layers(target, layer_bearer.element, int(RelicCatalog.get_relic(31).get("effects", {}).get("層", 1)))
				if target.alive:
					await _apply_dot(layer_bearer, target)
	if connected and target.relic_next_cut > 0.0:
		target.relic_next_cut = 0.0
	if target.guarding and target.alive and is_instance_valid(target.unit):
		target.unit.play_guard_hit_shake()
		await _wait(0.32)
	if actor.sheet_id == 4 and direct:
		await _absorb_followup(actor, target)
		await _ise_on_absorb_layers(actor, target)
		if not target.alive:
			RelicCombat.note_kill(actor)
			_growth_killer = null
			if attack_ko:
				_relic_on_slay(actor)
		return
	if relic_layered and target.alive:
		await _apply_dot(actor, target)
	if direct and actor.element == "absorb" and connected:
		await _ise_on_absorb_layers(actor, target)
	if not target.alive:
		_growth_killer = actor
		RelicCombat.note_kill(actor)
		if attack_ko:
			_relic_on_slay(actor)
		await _ko(target)
		return
	if dealt > 0 and not target.guarding:
		await _flinch(target)


func _support(actor: Fighter) -> void:
	var kind := str(actor.kit.get("buff_kind", "highest_speed_bonus"))
	GameAudio.play_battle_support()
	if actor.uses_buff:
		if actor.sheet_id == 48:
			await _sosaki_front_buff(actor)
		elif actor.sheet_id in [53, 58, 59] and not _is_backline(actor):
			var ally_front := _backline_style_buff_target(actor, false)
			if ally_front == null:
				ally_front = actor
			var gated_front: bool = await _era6_buff_gate(actor, ally_front, kind)
			if gated_front:
				await _wait(BUFF_TIME)
				return
			await _play_status_transfer(actor.unit, ally_front.unit, true)
			_set_single_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
			actor.kit["front_buff_active"] = true
			_refresh_unit_aura(ally_front.unit)
			ally_front.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
			_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally_front.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
			_nose_note_enemy_buff(actor, ally_front)
			await _note_arita_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
		else:
			var ally := _buff_target(actor, kind)
			if ally == null:
				ally = actor
			var gated: bool = await _era6_buff_gate(actor, ally, kind)
			if gated:
				await _wait(0.2)
			elif _tanabe_block_enemy_buff(actor, ally):
				_host._log("%s へのバフはタナベが消した" % ally.unit.get_display_name())
				await _era6_on_buff_erased(actor)
				await _wait(0.2)
			else:
				await _play_status_transfer(actor.unit, ally.unit, true)
				_set_single_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
				if actor.sheet_id == 11:
					actor.kit["front_buff_active"] = true
				_refresh_unit_aura(ally.unit)
				ally.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
				_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
				_nose_note_enemy_buff(actor, ally)
				await _note_arita_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
	else:
		if _era6_custom_debuff_ready(actor):
			await _sano_summon_debuff(actor, kind)
		elif actor.sheet_id == 51 and bool(actor.kit.get("aoe_debuff_armed", false)):
			actor.kit["aoe_debuff_armed"] = false
			await _takatsuki_aoe_debuff(actor, kind)
		else:
			var foe := _debuff_target(actor)
			if foe == null or not is_instance_valid(foe.unit):
				_host._log("%s のデバフは対象がいない" % actor.unit.get_display_name())
				await _wait(0.25)
				return
			await _play_status_transfer(actor.unit, foe.unit, false)
			_add_debuff(actor, foe, kind, float(actor.kit.get("buff_amount", 0.0)))
			_refresh_unit_aura(foe.unit)
			foe.unit.popup_battle_text("デバフ", Color(0.82, 0.55, 1.0))
			_host._log("%s が %s にデバフ（%s）" % [actor.unit.get_display_name(), foe.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
			if actor.enemy and not foe.enemy:
				_host.board.mark_debuffed_unit(foe.unit)
				_host._log("%s はデバフを受けた" % foe.unit.get_display_name())
				_release_stale_debuffs()
				_sync_queue()
	await _wait(BUFF_TIME)


func _guard(actor: Fighter) -> void:
	GameAudio.play_battle_guard()
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
	if fighter.enemy:
		GameAudio.play_battle_slay()
	else:
		GameAudio.play_battle_fall()
	unit.popup_battle_text("倒れた", Color(1.0, 0.45, 0.42))
	_host._log("%s が倒れた" % unit.get_display_name())
	await _on_fighter_down(fighter)
	_growth_killer = null
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
	await _era6_after_ko(fighter)


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
				_recompute_speed(fighter, true)
				fighter.ap = fighter.base_ap
				fighter.saved_ap = fighter.base_ap
				fighter.start_ap = fighter.base_ap
				fighter.entered_once = true
			fighter.in_queue = true
		if bool(fighter.kit.get("never_acts", false)):
			fighter.in_queue = false
		unit.action_value = fighter.ap
		unit.set_battle_hp(fighter.hp, fighter.max_hp)
		_show_gauge(fighter)
	_register_backline(board, false)
	_register_backline(board, true)
	_era2_battle_start_flags()
	_refresh_passive_kits()
	_publish_waiting_ap(board)
	if not _relic_started:
		_relic_started = true
		_relic_on_battle_start()
		_refresh_relic_speeds()
		for key in _fighters.keys():
			var relic_fighter: Fighter = _fighters[key]
			if not relic_fighter.alive or not relic_fighter.in_queue:
				continue
			relic_fighter.ap = relic_fighter.base_ap
			relic_fighter.saved_ap = relic_fighter.base_ap
			relic_fighter.start_ap = relic_fighter.base_ap
			if is_instance_valid(relic_fighter.unit):
				relic_fighter.unit.action_value = relic_fighter.ap
	_refresh_bar()


func _register_backline(board: BoardController, enemies: bool) -> void:
	for unit in board.back_units(enemies):
		var back: GameUnit = unit as GameUnit
		if back == null or back.battle_ko:
			continue
		var fighter := _fighter(back, board.slot_of_unit(back))
		fighter.enemy = enemies
		fighter.stand_slot = board.slot_of_unit(back)
		fighter.in_queue = false
		if not fighter.entered_once:
			fighter.entered_once = true
		if is_instance_valid(fighter.unit):
			fighter.unit.set_battle_hp(fighter.hp, fighter.max_hp)
			_show_gauge(fighter)


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
			await _arita_on_ap_loss(fighter, was_buff)
			_fukusaki_on_ap_loss(fighter)
			await _miyake_on_ap_loss(fighter)
			_tarumi_on_other_ap_loss(fighter, actor)
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
		var floor_n := 0
		if str(element) == "earth":
			floor_n = int(fighter.kit.get("tsurugi_persist_floor", 0))
		while count > floor_n and bank >= fighter.start_ap:
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
	RelicCombat.bind(fighter, _host)
	_init_break_gauges(fighter)
	if int(fighter.kit.get("relic_speed", 0)) != 0:
		_recompute_speed(fighter, true)
	if is_instance_valid(fighter.unit):
		fighter.unit.set_battle_hp(fighter.hp, fighter.max_hp)
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
	fighter.kit["reflect_roster"] = {}
	fighter.kit["extra_layer_used"] = false
	fighter.kit["aoe_pending"] = false
	fighter.kit["aoe_instant"] = false
	fighter.kit["force_attack"] = false
	fighter.kit["water_empowered"] = false
	fighter.kit["guard_pierce_left"] = int(fighter.kit.get("guard_pierce", 0))
	fighter.kit["opening_strike"] = false
	fighter.kit["follow_left"] = 0
	fighter.kit["opening_target_id"] = -1
	fighter.kit["multi_armed"] = false
	fighter.kit["extra_resolving"] = false
	fighter.kit["heal_used"] = false
	fighter.kit["first_hit_done"] = false
	fighter.kit["copy_taken_cut_active"] = 0.0
	if fighter.sheet_id == 8:
		fighter.kit["follow_left"] = 0
	if fighter.sheet_id == 9 or fighter.sheet_id == 13:
		fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
	if fighter.sheet_id == 12:
		fighter.kit["dot_ratio"] = _tokaido_dot_ratio(fighter.enemy)
	if fighter.sheet_id == 11:
		fighter.kit["ise_attacks_left"] = int(fighter.kit.get("extra_attacks", 1))
	if fighter.sheet_id == 16:
		fighter.kit["splash_retarget_left"] = int(fighter.kit.get("splash_retarget", 1))
	if is_instance_valid(fighter.unit):
		var flags: Dictionary = fighter.unit.kit_flags
		var swing_bonus := int(flags.get("swing_hp_bonus", 0))
		if swing_bonus > 0:
			fighter.max_hp += swing_bonus
		var merge_hp := int(flags.get("merge_hp_bonus", 0))
		if merge_hp > 0:
			fighter.max_hp += merge_hp
		fighter.hp = fighter.max_hp
		var swing_def := int(flags.get("swing_defense_bonus", 0))
		if swing_def > 0:
			fighter.defense += float(swing_def)
		if fighter.sheet_id == 10:
			var copied_uid := int(flags.get("copied_uid", -1))
			if copied_uid > 0 and fighter.unit.equipped_relic_uids.has(copied_uid):
				fighter.kit["copy_taken_cut_active"] = float(fighter.kit.get("copy_taken_cut", 0.0))
		if fighter.sheet_id == 14 and bool(flags.get("break_taken_armed", false)):
			fighter.kit["break_taken_cut_active"] = float(fighter.kit.get("break_taken_cut", 0.0))
			# resist already baked into attribute via battle flag below if needed
		if fighter.sheet_id == 16:
			fighter.kit["swing_water_bonus"] = float(flags.get("swing_water_bonus", 0.0))
		if fighter.sheet_id == 17:
			fighter.kit["otsu_pending"] = int(flags.get("otsu_pending", 0))
			fighter.kit["otsu_extra_used"] = 0
		if fighter.sheet_id == 21 or fighter.sheet_id == 26:
			fighter.kit["synth_left"] = int(flags.get("synth_charges", 0))
		if fighter.sheet_id == 23:
			fighter.kit["gem_left"] = int(flags.get("gem_charges", 0))
		if fighter.sheet_id == 26:
			fighter.kit["gem_locked"] = bool(flags.get("gem_empowered", false))
		if fighter.sheet_id == 32:
			fighter.kit["started_front"] = false
		if fighter.sheet_id == 35:
			fighter.kit["synth_bonus"] = float(flags.get("synth_bonus", 0.0))
			fighter.kit["swing_speed_bonus"] = int(flags.get("swing_speed_bonus", 0))
			fighter.kit["start_relics"] = fighter.unit.equipped_relic_uids.size()
		if fighter.sheet_id == 36:
			fighter.kit["summon_left"] = int(fighter.kit.get("summon_charges", 2))
		if fighter.sheet_id == 19:
			fighter.kit["kakogawa_left"] = 0
		if fighter.sheet_id == 25:
			fighter.kit["death_splash_left"] = 0
		if fighter.sheet_id == 29:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
		if fighter.sheet_id == 28:
			fighter.kit["gauge"] = 0
		if fighter.sheet_id == 33:
			fighter.kit["mark_moves_left"] = int(fighter.kit.get("mark_moves", 1))
		if fighter.sheet_id == 34:
			fighter.kit["ice_forced_left"] = 1
		if fighter.sheet_id == 47:
			var start_n := fighter.unit.equipped_relic_uids.size() if is_instance_valid(fighter.unit) else 0
			fighter.kit["start_relics"] = start_n
			if start_n > 0:
				fighter.kit["force_hit_left"] = int(fighter.kit.get("force_hits", 1))
				fighter.kit["priority_cut_active"] = int(fighter.kit.get("priority_cut", 0))
			var equip_hp := int(flags.get("senboku_equip_hp", 0))
			if equip_hp > 0:
				fighter.max_hp += equip_hp
				fighter.hp = fighter.max_hp
			fighter.kit["swing_thunder_bonus"] = float(flags.get("swing_thunder_bonus", 0.0))
		if fighter.sheet_id in [50, 51, 52, 54]:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
		if fighter.sheet_id == 53:
			fighter.kit["cleanse_left"] = int(fighter.kit.get("cleanse_count", 1))
			if _is_backline(fighter):
				fighter.kit["never_acts"] = true
		if fighter.sheet_id in [55, 56, 58, 59]:
			if _is_backline(fighter):
				fighter.kit["never_acts"] = true
		if fighter.sheet_id == 56:
			fighter.kit["chihaya_left"] = int(flags.get("gem_charges", 0))
		if fighter.sheet_id == 57:
			fighter.kit["first_earth_left"] = 1
			fighter.kit["dot_ratio"] = _metamorph_dot_ratio(fighter.enemy)
		if fighter.sheet_id == 58:
			fighter.kit["sign_stacks"] = clampi(int(flags.get("sign_stacks", 0)), 0, maxi(1, int(fighter.kit.get("sign_need", 4))))
		if fighter.sheet_id == 61:
			fighter.kit["gauge"] = clampi(int(flags.get("torahime_gauge", int(fighter.kit.get("gauge", 0)))), 0, 100)
			fighter.kit["extra_earth_armed"] = bool(flags.get("extra_earth_armed", false))
		if fighter.sheet_id == 62:
			fighter.kit["nagano_force_hit_armed"] = false
			fighter.kit["nagano_pen"] = 0.0
		if fighter.sheet_id in [63, 64, 65, 68]:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			if fighter.sheet_id == 64:
				fighter.kit["gauge"] = clampi(int(flags.get("nada_gauge", int(fighter.kit.get("gauge", 0)))), 0, 100)
				fighter.kit["nada_gauge_crit"] = float(flags.get("nada_gauge_crit", 0.0))
				fighter.kit["nada_first_fill"] = not bool(flags.get("nada_filled_once", false))
		if fighter.sheet_id == 67:
			fighter.kit["aoe_charges_left"] = int(fighter.kit.get("aoe_charges", 1))
		if fighter.sheet_id == 68:
			fighter.kit["nishimino_double_armed"] = bool(flags.get("nishimino_double_armed", false))
			fighter.kit["nishimino_second_bonus"] = float(flags.get("nishimino_second_bonus", 0.0))
		if fighter.sheet_id == 69:
			fighter.kit["mark_moves_left"] = int(fighter.kit.get("mark_moves", 1))
			fighter.kit["nose_mark_id"] = -1
	_era6_assign_kit(fighter)
	_recompute_speed(fighter, true)
	fighter.ap = fighter.base_ap
	fighter.saved_ap = fighter.base_ap
	fighter.start_ap = fighter.base_ap
	if fighter.sheet_id == 60:
		fighter.ap = maxi(0, fighter.ap - int(fighter.kit.get("start_ap_cut", 0)))
	if is_instance_valid(fighter.unit):
		fighter.unit.action_value = fighter.ap
		_show_gauge(fighter)


func _roll_action(fighter: Fighter) -> String:
	var roll := randi() % 10
	if roll < fighter.weight_attack:
		return "attack"
	roll -= fighter.weight_attack
	if roll < fighter.weight_buff:
		return "buff"
	return "guard"


func _roll_hit(defender: Fighter) -> bool:
	var speed := float(defender.speed)
	var bonus := int(defender.kit.get("hit_speed_bonus", 0))
	if bonus > 0:
		speed += float(bonus)
		defender.kit["hit_speed_bonus"] = 0
	var chance := clampf(1.05 - speed / 280.0, 0.55, 0.9)
	return randf() < chance


func _roll_damage(attacker: Fighter, defender: Fighter, allow_crit: bool, bonus_extra: float, attack_override: float, use_general_bonus: bool = true) -> Dictionary:
	var attack := attacker.attack if attack_override < 0.0 else attack_override
	var element := attacker.element
	var board: BoardController = _host.board if _host != null else null
	var penetration := attacker.penetration + float(attacker.kit.get("nagano_pen", 0.0))
	if use_general_bonus:
		penetration += RelicCombat.attack_penetration(attacker)
		penetration += RelicCombat.aura_pen(attacker, _fighters, board)
	penetration = clampf(penetration, 0.0, 1.0)
	var defense := defender.defense + RelicCombat.aura_defense(defender, _fighters, board)
	defense = maxf(0.0, defense - float(defender.kit.get("received_defense_cut", 0.0)))
	var defense_coef := 1000.0 / (1000.0 + defense * (1.0 - penetration))
	var dealt_coef := 1.0 + bonus_extra + RelicCombat.flat_outgoing(attacker) + attacker.relic_fallen_bonus + attacker.relic_slay_bonus
	dealt_coef += RelicCombat.aura_outgoing(attacker, _fighters, board)
	if not attacker.enemy and _host != null:
		dealt_coef += RelicEconomy.growth_outgoing(_host.session, attacker.unit)
	if use_general_bonus:
		dealt_coef += attacker.bonus_damage
	var element_coef := 1.0 + float(attacker.element_damage.get(element, 0.0)) + _formation_bonus(attacker) + RelicCombat.element_outgoing(attacker, element)
	var resist := float(defender.element_resist.get(element, 0.0)) + defender.attribute_resist + RelicCombat.aura_resist(defender, _fighters, board)
	if element == "thunder":
		resist += float(defender.kit.get("received_thunder_resist", 0.0))
	if element == "fire":
		resist += float(defender.kit.get("received_fire_resist", 0.0))
	if element == "ice":
		resist += float(defender.kit.get("received_ice_resist", 0.0))
	if element == "water":
		resist += float(defender.kit.get("received_water_resist", 0.0))
	if element == "wind":
		resist += float(defender.kit.get("received_wind_resist", 0.0))
	if element == "absorb":
		resist += float(defender.kit.get("received_absorb_resist", 0.0))
	if element == "earth":
		resist += float(defender.kit.get("received_earth_resist", 0.0))
	var resist_coef := 1.0 - resist
	var taken_coef := 1.0 + defender.damage_taken
	var can_crit := allow_crit and not bool(attacker.kit.get("attack_no_crit", false))
	if bool(defender.kit.get("block_incoming_crit", false)):
		can_crit = false
	var crit_rate := attacker.crit_rate + RelicCombat.aura_crit(attacker, _fighters, board)
	crit_rate += float(attacker.kit.get("nada_gauge_crit", 0.0)) / 100.0
	if bool(attacker.kit.get("nawate_aoe_crit", false)):
		crit_rate += float(attacker.kit.get("aoe_crit", 0.0)) / 100.0
	crit_rate += float(attacker.kit.get("hit_crit_stacks", 0.0))
	crit_rate += _era2_side_crit(attacker)
	var force_id := int(attacker.kit.get("force_crit_target_id", -1))
	var force_crit := force_id > 0 and is_instance_valid(defender.unit) and defender.unit.get_instance_id() == force_id
	var force_break_crit := bool(attacker.kit.get("force_crit_break", false))
	if force_break_crit:
		attacker.kit["force_crit_break"] = false
	if attacker.sheet_id == 52 and attacker.element == "water" and int(attacker.kit.get("gauge", 0)) >= 50:
		crit_rate += float(attacker.kit.get("gauge_crit", 0.0))
	var crit := can_crit and (force_crit or force_break_crit or randf() < crit_rate)
	attacker.kit["last_roll_crit"] = crit
	if force_crit:
		attacker.kit["force_crit_target_id"] = -1
	var crit_damage := attacker.crit_damage + float(attacker.kit.get("front_crit_damage_active", 0.0)) / 100.0
	if force_crit:
		crit_damage += float(attacker.kit.get("forced_crit_damage_bonus", 0.0)) / 100.0
	if crit and attacker.element == "ice" and attacker.sheet_id == 64:
		crit_damage += float(attacker.kit.get("ice_crit_damage", 200.0)) / 100.0
	var crit_coef := (1.0 + crit_damage) if crit else 1.0
	dealt_coef += float(defender.kit.get("mark_taken_active", 0.0))
	dealt_coef += float(defender.kit.get("kakogawa_fire_vuln", 0.0)) if element == "fire" else 0.0
	var amount := attack * defense_coef * dealt_coef * element_coef * resist_coef * taken_coef * crit_coef
	amount *= RelicCombat.named_coef(attacker, not use_general_bonus)
	if use_general_bonus:
		var taken_cut := defender.relic_taken_cut + defender.relic_next_cut + RelicCombat.aura_taken_cut(defender, _fighters, board)
		taken_cut += float(defender.kit.get("copy_taken_cut_active", 0.0))
		taken_cut += float(defender.kit.get("guard_taken_cut_active", 0.0))
		taken_cut += float(defender.kit.get("break_taken_cut_active", 0.0))
		taken_cut += float(defender.kit.get("redirect_taken_cut_active", 0.0))
		taken_cut += float(defender.kit.get("next_taken_cut_active", 0.0))
		taken_cut += float(defender.kit.get("received_taken_cut", 0.0))
		taken_cut += float(defender.kit.get("nabari_first_cut", 0.0))
		amount *= maxf(0.0, 1.0 - taken_cut)
	if not defender.enemy and _host != null:
		amount *= maxf(0.0, 1.0 - RelicEconomy.growth_taken(_host.session, defender.unit))
	amount *= _era6_damage_coef(attacker, defender, use_general_bonus)
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
	var bonus := SynergyTracker.bonuses_for(fighter.unit, _host.board.get_circle_units(), _host.session)
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
	speed += int(fighter.kit.get("sakai_speed_bonus", 0))
	if fighter.sheet_id == 2 and int(fighter.kit.get("gauge", 0)) >= 50:
		speed += int(fighter.kit.get("gauge_speed", 0))
	if fighter.sheet_id == 3 and fighter.barrier > 0:
		speed += int(fighter.kit.get("barrier_speed", 0))
	speed -= int(fighter.kit.get("ayakawa_slow", 0))
	speed += int(fighter.kit.get("synergy_speed", 0))
	speed += int(fighter.kit.get("relic_speed", 0))
	speed += RelicCombat.aura_speed(fighter, _fighters, _host.board if _host != null else null)
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
	if fighter.sheet_id == 88 and bool(fighter.kit.get("aoe_pending", false)):
		value -= int(fighter.kit.get("stealth_priority", 0))
	if fighter.sheet_id == 9 and int(fighter.kit.get("gauge", 0)) >= 1 and not bool(fighter.kit.get("multi_armed", false)):
		value += int(fighter.kit.get("priority_bonus", 0))
	value -= int(fighter.kit.get("priority_cut_active", 0))
	if fighter.sheet_id == 47:
		value -= int(fighter.kit.get("priority_cut_active", 0))
	if fighter.sheet_id == 49 and fighter.hp >= fighter.max_hp and fighter.hp > 0:
		value += int(fighter.kit.get("full_priority", 0))
	if fighter.sheet_id == 69 and int(fighter.kit.get("nose_mark_id", -1)) > 0 and fighter.hp > 0:
		value -= int(fighter.kit.get("priority_cut", 0))
	if fighter.sheet_id == 33 and not _is_backline(fighter) and fighter.hp > 0 and _gojo_has_mark(fighter.enemy):
		value -= int(fighter.kit.get("priority_cut", 0))
	value += _era6_threat_delta(fighter)
	value += RelicCombat.aura_priority(fighter, _fighters, _host.board if _host != null else null)
	return maxi(0, value)


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
		"lowest_speed_speed", "highest_attack_speed", "highest_ap_speed":
			return "速度 %+d" % int(round(amount))
		"highest_cost_fire":
			return "炎ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_absorb":
			return "吸収ダメージ %+d%%" % int(round(amount * 100.0))
		"thunder_resist":
			return "雷耐性 %+d%%" % int(round(-amount * 100.0))
		"fire_resist":
			return "炎のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"ice_resist":
			return "氷のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"ice_taken":
			return "氷被ダメージ %+d%%" % int(round(amount * 100.0))
		"defense_cut":
			return "防御力 %+d" % int(round(-amount))
		"absorb_resist":
			return "吸収のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"wind_resist":
			return "風のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"water_resist":
			return "水のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"lowest_attack_water":
			return "水与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_thunder":
			return "雷与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_crit_damage", "highest_crit_crit_damage":
			return "クリティカルダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_fire":
			return "炎与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_earth":
			return "土与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_ice", "highest_attack_ice_other":
			return "氷与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_attack_wind":
			return "風与ダメージ %+d%%" % int(round(amount * 100.0))
		"lowest_attack_bonus":
			return "攻撃力 %+d" % int(round(amount))
		"front_taken_cut":
			return "受けるダメージ %+d%%" % int(round(-amount * 100.0))
		"highest_attack_dealt_cut":
			return "与ダメージ %+d%%" % int(round(-amount * 100.0))
		"highest_crit_wind":
			return "風与ダメージ %+d%%" % int(round(amount * 100.0))
		"lowest_priority_earth":
			return "土与ダメージ %+d%%" % int(round(amount * 100.0))
		"most_earth_dot_vuln":
			return "継続ダメージ %+d%%" % int(round(amount * 100.0))
		"lowest_speed_absorb":
			return "吸収与ダメージ %+d%%" % int(round(amount * 100.0))
		"self_crit_rate":
			return "クリティカル率 %+d" % int(round(amount))
		"highest_threat_taken_cut":
			return "受けるダメージ %+d%%" % int(round(-amount * 100.0))
		"highest_thunder_thunder":
			return "雷与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_water_water":
			return "水与ダメージ %+d%%" % int(round(amount * 100.0))
		"highest_hp_wind_resist":
			return "風耐性 %+d%%" % int(round(-amount * 100.0))
		"attr_resist_cut":
			return "属性耐性 %+d%%" % int(round(-amount * 100.0))
		"lowest_hp_dot_cut":
			return "継続ダメージ %+d%%" % int(round(-amount * 100.0))
		"lowest_defense_resist":
			return "属性耐性 %+d%%" % int(round(amount * 100.0))
		_:
			return _era6_describe_effect(kind, amount)


func _mitigate(defender: Fighter, amount: int) -> int:
	if amount <= 0:
		return amount
	if not defender.guarding:
		var proxy := _tamba_proxy_guard(defender)
		if proxy == null:
			return amount
		defender = proxy
	if not defender.guarding:
		return amount
	if bool(defender.kit.get("ignore_guard", false)):
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
	if left > 0 and target.sheet_id == 24 and target.hp > 0 and left >= target.hp and not bool(target.kit.get("survive_used", false)):
		target.kit["survive_used"] = true
		target.kit["next_taken_cut_active"] = float(target.kit.get("redirect_taken_cut", 0.0))
		left = target.hp - 1
		_host._log("%s は体力1で耐えた" % target.unit.get_display_name())
	if float(target.kit.get("next_taken_cut_active", 0.0)) > 0.0 and left > 0 and target.hp - left > 0:
		pass
	elif float(target.kit.get("next_taken_cut_active", 0.0)) > 0.0 and left > 0:
		target.kit["next_taken_cut_active"] = 0.0
	if left > 0:
		target.hp = maxi(0, target.hp - left)
		if float(target.kit.get("redirect_taken_cut_active", 0.0)) > 0.0:
			target.kit["redirect_taken_cut_active"] = 0.0
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
	if attacker.sheet_id == 42 and attacker.element == "earth" and int(attacker.kit.get("gauge", 0)) >= 50:
		bonus += float(attacker.kit.get("earth_empower", 0.0))
	if attacker.sheet_id == 79 and bool(attacker.kit.get("water_empowered", false)):
		bonus += float(attacker.kit.get("water_empower", 0.0))
	if bool(attacker.kit.get("aoe_resolving", false)):
		bonus += float(attacker.kit.get("aoe_bonus", 0.0))
	if bool(attacker.kit.get("opening_strike", false)):
		bonus += float(attacker.kit.get("opening_bonus", 0.0))
	if bool(attacker.kit.get("charged_strike", false)):
		bonus += float(attacker.kit.get("charged_bonus", 0.0))
	if attacker.element == "ice":
		bonus += float(defender.kit.get("received_ice_taken", 0.0))
	if attacker.element == "fire" and bool(attacker.kit.get("bare_fire", false)):
		bonus += float(attacker.kit.get("bare_bonus", 0.0))
	if attacker.element == "water":
		bonus += float(attacker.kit.get("swing_water_bonus", 0.0))
		bonus += float(attacker.kit.get("received_water", 0.0))
	if attacker.element == "thunder":
		bonus += float(attacker.kit.get("received_thunder", 0.0))
		bonus += float(attacker.kit.get("swing_thunder_bonus", 0.0))
		bonus += float(attacker.kit.get("sosaki_self_thunder", 0.0))
		bonus += float(attacker.kit.get("sosaki_column_thunder", 0.0))
	if attacker.element == "earth":
		bonus += float(attacker.kit.get("received_earth", 0.0))
	if attacker.element == "ice":
		bonus += float(attacker.kit.get("received_ice", 0.0))
		bonus += float(attacker.kit.get("nabari_ice_empower", 0.0))
	if attacker.element == "thunder":
		bonus += float(defender.kit.get("naura_thunder_taken", 0.0))
	if attacker.element == "wind":
		bonus += float(defender.kit.get("nose_wind_taken", 0.0))
	if attacker.sheet_id == 68 and bool(attacker.kit.get("nishimino_second", false)):
		bonus += float(attacker.kit.get("nishimino_second_bonus", 0.0))
	if attacker.element == "wind":
		bonus += float(attacker.kit.get("received_wind", 0.0))
	if attacker.element == "fire":
		bonus += float(attacker.kit.get("daito_gauge_fire", 0.0))
		bonus += float(attacker.kit.get("chihaya_next_fire", 0.0))
	if attacker.element == "wind":
		bonus += float(attacker.kit.get("touin_next_wind", 0.0))
	if attacker.element == "earth":
		bonus += float(attacker.kit.get("torahime_pending_earth", 0.0))
		bonus += float(attacker.kit.get("torahime_opening_bonus", 0.0))
	if int(defender.layers.get("absorb", 0)) > 0:
		bonus += float(attacker.kit.get("received_absorb", 0.0))
	bonus += _era2_kit_bonus(attacker, defender, is_dot)
	bonus += _era6_kit_bonus(attacker, defender)
	bonus -= float(attacker.kit.get("outgoing_cut", 0.0))
	bonus -= float(attacker.kit.get("outgoing_cut_buff", 0.0))
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
	var horizontal := 0
	var index := attacker.stand_slot
	while index >= 0 and elements[index] == attacker.element:
		horizontal += 1
		index -= 1
	index = attacker.stand_slot + 1
	while index < BoardController.FRONT_COUNT and elements[index] == attacker.element:
		horizontal += 1
		index += 1
	var vertical := 0
	if _host != null and _host.board != null:
		vertical = _host.board.formation_stack_count(attacker.stand_slot, attacker.element)
	var count := maxi(horizontal, vertical)
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
	if actor.sheet_id == 8 and int(actor.kit.get("follow_left", 0)) > 0:
		var marked := _fighter_by_id(int(actor.kit.get("opening_target_id", -1)))
		if marked != null and marked.alive and marked.hp > 0 and marked.enemy != actor.enemy:
			actor.kit["follow_left"] = maxi(0, int(actor.kit.get("follow_left", 0)) - 1)
			return marked
		actor.kit["follow_left"] = 0
	if actor.sheet_id == 13 and bool(actor.kit.get("charged_ready", false)):
		var marked13 := _fighter_by_id(int(actor.kit.get("charged_target_id", -1)))
		if marked13 != null and marked13.alive and marked13.hp > 0 and marked13.enemy != actor.enemy:
			return marked13
	var forced_kawai := _fighter_by_id(int(actor.kit.get("force_target_id", -1)))
	if forced_kawai != null and forced_kawai.alive and forced_kawai.hp > 0 and forced_kawai.enemy != actor.enemy:
		actor.kit["force_target_id"] = -1
		return forced_kawai
	if actor.element == "earth":
		var marked := _tanabe_marked_target(actor)
		if marked != null:
			return marked
		var toba_t := _toba_earth_target(actor)
		if toba_t != null:
			return toba_t
	if actor.sheet_id == 61 and int(actor.kit.get("lock_left", 0)) > 0:
		var locked := _fighter_by_id(int(actor.kit.get("lock_target_id", -1)))
		if locked != null and locked.alive and locked.hp > 0 and locked.enemy != actor.enemy:
			return locked
	if actor.sheet_id == 69 and int(actor.kit.get("nose_mark_id", -1)) > 0 and actor.element == "wind":
		var marked_nose := _fighter_by_id(int(actor.kit.get("nose_mark_id", -1)))
		if marked_nose != null and marked_nose.alive and marked_nose.hp > 0 and marked_nose.enemy != actor.enemy:
			return marked_nose
	var era6_forced := _era6_forced_target(actor)
	if era6_forced != null:
		return era6_forced
	var nabari := _nabari_taunt_target(actor)
	if nabari != null:
		return nabari
	if actor.sheet_id == 32 and bool(actor.kit.get("started_front", false)):
		var facing := _kouryo_facing_target(actor)
		if facing != null:
			return facing
	var picked := _pick_target(actor)
	return _kadoma_maybe_redirect(actor, picked)


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
	elif _goshodan_splash_count(actor) > 1:
		splash = true
		extras = _goshodan_extras(actor, primary, _goshodan_splash_count(actor) - 1)
	elif actor.sheet_id == 48 and actor.element == "thunder" and _lagosu_splash_count(actor) > 1:
		splash = true
		extras = _sosaki_extras(actor, primary, _lagosu_splash_count(actor) - 1)
	elif actor.sheet_id == 54 and actor.element == "ice":
		if bool(actor.kit.get("tarumi_full_aoe", false)):
			var iced := _tarumi_ice_targets(actor, primary)
			if not iced.is_empty():
				splash = true
				extras = iced
				actor.kit["tarumi_aoe_resolving"] = true
				actor.kit["tarumi_full_aoe"] = false
		elif _signal_noise_splash_count(actor) > 1:
			splash = true
			extras = _goshodan_extras(actor, primary, _signal_noise_splash_count(actor) - 1)
	elif actor.sheet_id == 51 and actor.element == "ice" and bool(actor.kit.get("extra_ice_armed", false)):
		actor.kit["extra_ice_armed"] = false
		var need51 := maxi(1, int(actor.kit.get("extra_targets", 1)))
		var picks51 := _takatsuki_extra_targets(actor, primary, need51)
		if not picks51.is_empty():
			splash = true
			extras = picks51
	elif actor.sheet_id == 67 and actor.element == "wind" and bool(actor.kit.get("nawate_full_aoe", false)):
		actor.kit["nawate_full_aoe"] = false
		actor.kit["nawate_aoe_crit"] = true
		splash = true
		extras = []
		for entry in _opponents(actor):
			var foe: Fighter = entry
			if foe != primary and foe.alive:
				extras.append(foe)
	elif actor.sheet_id == 67 and actor.element == "wind" and _noukyo_splash_count(actor) > 1:
		splash = true
		extras = _goshodan_extras(actor, primary, _noukyo_splash_count(actor) - 1)
	extras = _era6_attack_extras(actor, primary, extras)
	extras = _era2_attack_extras(actor, primary, extras)
	if not extras.is_empty():
		splash = true
	if actor.relic_neighbor and primary.stand_slot >= 0 and primary.stand_slot < BoardController.FRONT_COUNT:
		var neighbor := _relic_neighbor(actor, primary)
		if neighbor != null and not extras.has(neighbor):
			extras.append(neighbor)
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
	if actor.sheet_id == 79:
		actor.kit["water_empowered"] = false


func _continuity_with_attack(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null or not is_instance_valid(target.unit):
		return
	if bool(actor.kit.get("continuity_done", false)):
		return
	actor.kit["continuity_done"] = true
	if actor.sheet_id == 12:
		await _itami_dot_on(actor, target)
	await _apply_randoseru_on(actor, target)
	await _era4_on_attack_contact(actor, target)
	await _era6_continuity(actor, target)


func _on_damage_dealt(actor: Fighter, target: Fighter, dealt: int, _hp_lost: int) -> void:
	if dealt <= 0:
		_era2_on_damage_dealt(actor, target, dealt)
		return
	if actor.sheet_id == 9 and bool(actor.kit.get("extra_resolving", false)):
		if not bool(target.kit.get("ikeda_water_marked", false)):
			target.kit["ikeda_water_marked"] = true
			target.kit["received_water_resist"] = float(target.kit.get("received_water_resist", 0.0)) - float(actor.kit.get("water_vuln", 0.0))
			_host._log("%s の水耐性が下がった" % target.unit.get_display_name())
	if actor.sheet_id == 10 and actor.element == "absorb" and not bool(actor.kit.get("heal_used", false)):
		actor.kit["heal_used"] = true
		var heal := int(round(float(actor.max_hp) * float(actor.kit.get("heal_ratio", 0.0))))
		if heal > 0 and is_instance_valid(actor.unit):
			actor.hp = mini(actor.max_hp, actor.hp + heal)
			actor.unit.set_battle_hp(actor.hp, actor.max_hp)
			actor.unit.popup_battle_text("+%d" % heal, Color(0.55, 0.95, 0.62))
			_host._log("%s が %d 回復した" % [actor.unit.get_display_name(), heal])
		if target.alive and is_instance_valid(target.unit):
			target.kit["outgoing_cut"] = float(actor.kit.get("next_cut", 0.0))
			_host._log("%s の次の与ダメージが下がる" % target.unit.get_display_name())
	if actor.sheet_id == 18 and actor.element == "fire":
		if _unit_has_buff(target.unit):
			_ono_cleanse(actor, target)
			actor.kit["bare_fire"] = false
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
	if actor.sheet_id == 22 and not bool(actor.kit.get("reflecting", false)):
		_katsuyama_note_dealt(actor, target)
	_era2_on_damage_dealt(actor, target, dealt)
	await _era3_after_ice_hit(actor, target)
	_era4_on_damage_dealt(actor, target, dealt)
	_era5_on_damage_dealt(actor, target, dealt)


func _absorb_followup(actor: Fighter, target: Fighter) -> void:
	_add_layers(target, "absorb", 1)
	if target.alive:
		await _apply_dot(actor, target)
	if not target.alive:
		_growth_killer = actor
		await _ko(target)


func _add_layers(target: Fighter, element: String, count: int) -> void:
	if count <= 0 or target == null:
		return
	target.layers[element] = int(target.layers.get(element, 0)) + count
	if element == "thunder":
		_otsu_try_extra_layer(target, count)


func _play_attack_sounds(actor: Fighter, crit: bool) -> void:
	GameAudio.play_battle_attack()
	GameAudio.play_battle_attribute(actor.element)
	if crit:
		GameAudio.play_battle_critical()


func _play_hit_fx(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null or not is_instance_valid(target.unit):
		return
	var parent: Node = _host.units_root if _host != null else null
	if parent == null:
		return
	## 味方へのヒットは属性アニメをユニットより手前に出す。
	AttributeHitFx.play(parent, actor.element, target.unit.global_position, not target.enemy)


func _apply_dot(actor: Fighter, target: Fighter) -> void:
	var stacks := int(target.layers.get(actor.element, 0))
	if stacks <= 0 or not target.alive:
		return
	if target.sheet_id == 49 and not bool(target.kit.get("dot_block_used", false)):
		target.kit["dot_block_used"] = true
		target.defense *= 1.0 + float(target.kit.get("dot_defense", 0.0))
		if is_instance_valid(target.unit):
			target.unit.popup_battle_text("継続無効", Color(0.7, 0.9, 1.0))
			_host._log("%s は継続ダメージを1回防いだ" % target.unit.get_display_name())
		return
	GameAudio.play_battle_dot(stacks)
	var power := actor.attack * float(actor.kit.get("dot_ratio", 0.05)) * float(stacks)
	var rolled := _roll_damage(actor, target, false, _neighbor_bonus(actor), power, false)
	var raw := int(rolled["amount"])
	var cut := float(target.kit.get("received_dot_cut", 0.0))
	var taken := float(target.kit.get("received_dot_taken", 0.0))
	if cut != 0.0 or taken != 0.0:
		raw = maxi(0, int(round(float(raw) * (1.0 - cut + taken))))
	var guarded := target.guarding and raw > 0
	var dealt := _mitigate(target, raw)
	var absorbed := _apply_damage(target, dealt)
	if dealt > 0 and is_instance_valid(target.unit):
		target.unit.popup_battle_text("継続-%d" % dealt, Color(0.75, 0.45, 0.9))
	if is_instance_valid(actor.unit) and is_instance_valid(target.unit):
		_host._log(_damage_log(actor.unit.get_display_name(), target.unit.get_display_name(), raw, dealt, absorbed, false, guarded, "継続ダメージ"))


func _relic_neighbor(actor: Fighter, primary: Fighter) -> Fighter:
	var left: Fighter = null
	var right: Fighter = null
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == primary or not foe.alive or not is_instance_valid(foe.unit):
			continue
		if foe.stand_slot < 0 or foe.stand_slot >= BoardController.FRONT_COUNT:
			continue
		if foe.stand_slot == primary.stand_slot - 1:
			left = foe
		elif foe.stand_slot == primary.stand_slot + 1:
			right = foe
	if left != null and right != null:
		return left if left.unit.unit_id <= right.unit.unit_id else right
	return left if left != null else right


func _relic_chase_target(actor: Fighter) -> Fighter:
	var chosen: Fighter = null
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if not foe.alive or not is_instance_valid(foe.unit):
			continue
		if foe.stand_slot < 0 or foe.stand_slot >= BoardController.FRONT_COUNT:
			continue
		if chosen == null:
			chosen = foe
			continue
		var threat := _threat(foe)
		var best := _threat(chosen)
		if threat > best or (threat == best and foe.unit.unit_id < chosen.unit.unit_id):
			chosen = foe
	return chosen


func _relic_on_battle_start() -> void:
	var bearer29 = RelicCombat._unique_living(_fighters, 29, false, _host.board)
	if bearer29 != null:
		var cut := RelicCombat._value(29, "次の与ダメージ") / 100.0
		for key in _fighters.keys():
			var foe: Fighter = _fighters[key]
			if not foe.enemy or not foe.alive or not is_instance_valid(foe.unit):
				continue
			if _host.board.front_slot_of(foe.unit) < 0:
				continue
			foe.relic_weaken_cut = cut
			foe.relic_weaken_left = 1
			foe.relic_weaken_source = bearer29.unit.get_instance_id()
	if RelicCombat._unique_living(_fighters, 38, false, _host.board) != null:
		_relic_blocks = int(RelicCombat._value(38, "無効の回数"))
	if RelicCombat._unique_living(_fighters, 31, false, _host.board) != null:
		_relic31_left = int(RelicCombat._value(31, "層の回数"))
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy or not is_instance_valid(fighter.unit):
			continue
		fighter.relic_start_row = RelicCombat._row(fighter.unit, _host.board).x
	RelicEconomy.note_battle_started(_host.session)
	RelicCombat.apply_front_hp_aura(_fighters, _host.board)
	_relic_opening_cut()


func _relic_opening_cut() -> void:
	## 195 タブー: 敵の最初の行動の与ダメージを下げる。
	if RelicCombat._unique_living(_fighters, 195, false, _host.board) == null:
		return
	var cut := RelicCombat._value(195, "与ダメージ") / 100.0
	for key in _fighters.keys():
		var foe: Fighter = _fighters[key]
		if not foe.enemy or not foe.alive:
			continue
		foe.relic_weaken_cut = maxf(foe.relic_weaken_cut, cut)
		foe.relic_weaken_left = maxi(foe.relic_weaken_left, 1)


func _deployed_allies() -> Array:
	var allies: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy or not is_instance_valid(fighter.unit):
			continue
		allies.append(fighter.unit)
	return allies


func _relic_on_battle_end() -> void:
	if _host == null:
		return
	var front: Array = []
	var back: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy or fighter.relic_start_row < 0 or not fighter.alive or fighter.hp <= 0:
			continue
		if not is_instance_valid(fighter.unit):
			continue
		if fighter.relic_start_row == 0:
			front.append(fighter.unit)
		elif fighter.relic_start_row == 1:
			back.append(fighter.unit)
	RelicEconomy.note_row_survivors(_host.session, front, back)


func _relic_after_action(actor: Fighter) -> void:
	RelicCombat.tick_pulses(_fighters)
	if actor != null and not actor.enemy:
		RelicCombat.note_hit_stack(actor)
	if actor == null or actor.enemy:
		return
	_relic_actions += 1
	if _relic36_done or _relic_actions < int(RelicCombat._value(36, "行動の数")):
		return
	if not RelicCombat.bearer_deployed(_fighters, _host.board, 36, false):
		return
	_relic36_done = true
	var chosen: Fighter = null
	var best := 2.0
	for key in _fighters.keys():
		var ally: Fighter = _fighters[key]
		if ally.enemy or not ally.alive or ally.hp <= 0 or not is_instance_valid(ally.unit) or ally.max_hp <= 0:
			continue
		var ratio := float(ally.hp) / float(ally.max_hp)
		if chosen == null or ratio < best or (is_equal_approx(ratio, best) and ally.unit.unit_id < chosen.unit.unit_id):
			chosen = ally
			best = ratio
	if chosen == null:
		return
	var heal := int(round(float(chosen.max_hp) * RelicCombat._value(36, "回復") / 100.0))
	chosen.hp = mini(chosen.max_hp, chosen.hp + heal)
	chosen.unit.set_battle_hp(chosen.hp, chosen.max_hp)


func _relic_on_slay(actor: Fighter) -> void:
	if actor.enemy or not RelicCombat.bearer_deployed(_fighters, _host.board, 40, false):
		return
	var step := RelicCombat._value(40, "与ダメージ") / 100.0
	var cap := RelicCombat._value(40, "与ダメージの上限") / 100.0
	for key in _fighters.keys():
		var ally: Fighter = _fighters[key]
		if ally.enemy or not ally.alive:
			continue
		ally.relic_slay_bonus = minf(cap, ally.relic_slay_bonus + step)


func _relic_on_ally_down(dead: Fighter) -> void:
	if dead.enemy:
		return
	RelicEconomy.note_ally_down(_host.session)
	if _relic32_done or not RelicCombat.bearer_deployed(_fighters, _host.board, 32, false):
		return
	_relic32_done = true
	var bonus := RelicCombat._value(32, "与ダメージ") / 100.0
	for key in _fighters.keys():
		var ally: Fighter = _fighters[key]
		if ally.enemy or not ally.alive or ally.hp <= 0:
			continue
		ally.relic_fallen_bonus += bonus


func _refresh_relic_speeds() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.alive:
			_recompute_speed(fighter, true)


func _on_fighter_down(dead: Fighter) -> void:
	RelicCombat.clear_touching(dead, _fighters)
	_relic_on_ally_down(dead)
	if dead.enemy:
		RelicEconomy.note_growth_kill(_host.session, _growth_killer.unit if _growth_killer != null and is_instance_valid(_growth_killer.unit) else null, _deployed_allies())
	if dead.sheet_id == 17:
		await _otsu_on_death(dead)
	await _era6_on_death(dead)
	await _era2_on_death(dead)
	_clear_buffs_touching(dead)
	_refresh_passive_kits()
	_refresh_relic_speeds()
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
		await _ko(receiver)


func _buff_target(actor: Fighter, kind: String) -> Fighter:
	match kind:
		"lowest_speed_speed", "lowest_speed_absorb":
			return _extreme(_side(actor.enemy), "speed", false)
		"self_crit_rate":
			return actor
		"highest_threat_taken_cut":
			return _extreme(_side(actor.enemy), "threat", true)
		"highest_thunder_thunder":
			var th_pool: Array = []
			for entry in _side(actor.enemy):
				var ally: Fighter = entry
				if ally.alive and ally.hp > 0 and ally.element == "thunder":
					th_pool.append(ally)
			if th_pool.is_empty():
				return actor
			return _extreme(th_pool, "attack", true)
		"highest_water_water":
			var w_pool: Array = []
			for entry in _side(actor.enemy):
				var ally_w: Fighter = entry
				if ally_w.alive and ally_w.hp > 0 and ally_w.element == "water":
					w_pool.append(ally_w)
			if w_pool.is_empty():
				return actor
			return _extreme(w_pool, "attack", true)
		"highest_hp_wind_resist":
			return _extreme(_opponents(actor), "hp", true)
		"lowest_hp_dot_cut":
			return _extreme(_side(actor.enemy), "hp", false)
		"lowest_defense_resist":
			return _extreme(_side(actor.enemy), "defense", false)
		"lowest_attack_water", "lowest_attack_bonus":
			return _extreme(_side(actor.enemy), "attack", false)
		"highest_attack_bonus", "highest_attack_absorb", "highest_attack_speed", "highest_attack_thunder", "highest_attack_crit_damage", "highest_attack_fire", "highest_attack_earth", "highest_attack_ice", "highest_attack_ice_other", "highest_attack_wind", "front_taken_cut":
			if kind == "highest_attack_ice_other":
				var pool: Array = []
				for entry in _side(actor.enemy):
					var ally: Fighter = entry
					if ally != actor and ally.alive and ally.hp > 0:
						pool.append(ally)
				if pool.is_empty():
					return actor
				return _extreme(pool, "attack", true)
			return _extreme(_side(actor.enemy), "attack", true)
		"highest_crit_crit_damage", "highest_crit_wind":
			return _extreme(_side(actor.enemy), "crit_rate", true)
		"lowest_priority_earth":
			return _extreme(_side(actor.enemy), "threat", false)
		"most_earth_dot_vuln":
			var layered: Array = []
			for entry in _opponents(actor):
				var foe: Fighter = entry
				if int(foe.layers.get("earth", 0)) > 0:
					layered.append(foe)
			if not layered.is_empty():
				var best: Fighter = null
				var best_n := -1
				for entry2 in layered:
					var f2: Fighter = entry2
					var n2 := int(f2.layers.get("earth", 0))
					if best == null or n2 > best_n or (n2 == best_n and f2.unit.unit_id < best.unit.unit_id):
						best = f2
						best_n = n2
				return best
			return _extreme(_opponents(actor), "threat", true)
		"highest_ap_speed":
			return _extreme(_side(actor.enemy), "ap", true)
		"highest_cost_fire":
			return _extreme(_side(actor.enemy), "cost", true)
		"highest_attack_dealt_cut":
			return _extreme(_opponents(actor), "attack", true)
		_:
			return _era6_buff_target(actor, kind)


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
		"defense":
			return fighter.defense
		"hp":
			return float(fighter.hp)
		"ap":
			return float(fighter.ap)
		"cost":
			return float(fighter.unit.get_cost())
		"threat":
			return float(_threat(fighter))
		"crit_rate":
			return float(fighter.crit_rate)
		_:
			return float(fighter.speed)


func _debuff_target(actor: Fighter) -> Fighter:
	var era6_target := _era6_debuff_target(actor)
	if era6_target != null:
		return era6_target
	if actor.sheet_id == 8:
		var opening := _fighter_by_id(int(actor.kit.get("opening_target_id", -1)))
		if opening != null and opening.alive and opening.hp > 0 and opening.enemy != actor.enemy:
			return opening
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 9:
		var hitter := _fighter_by_id(int(actor.kit.get("last_hitter_id", -1)))
		if hitter != null and hitter.alive and hitter.hp > 0 and hitter.enemy != actor.enemy:
			return hitter
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 10 or actor.sheet_id == 14 or actor.sheet_id == 15:
		var attacked := _fighter_by_id(int(actor.kit.get("last_attack_target_id", -1)))
		if attacked != null and attacked.alive and attacked.hp > 0 and attacked.enemy != actor.enemy:
			return attacked
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 12:
		var dotted := _fighter_by_id(int(actor.kit.get("last_dot_target_id", -1)))
		if dotted != null and dotted.alive and dotted.hp > 0 and dotted.enemy != actor.enemy:
			return dotted
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 13:
		return _extreme(_opponents(actor), "attack", true)
	if actor.sheet_id == 18:
		return _most_buffed_foe(actor)
	if actor.sheet_id == 49:
		var hitter49 := _fighter_by_id(int(actor.kit.get("last_hitter_id", -1)))
		if hitter49 != null and hitter49.alive and hitter49.hp > 0 and hitter49.enemy != actor.enemy:
			return hitter49
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 62:
		var last62 := _fighter_by_id(int(actor.kit.get("last_attack_target_id", -1)))
		if last62 != null and last62.alive and last62.hp > 0 and last62.enemy != actor.enemy:
			return last62
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 69:
		var marked69 := _fighter_by_id(int(actor.kit.get("nose_mark_id", -1)))
		if marked69 != null and marked69.alive and marked69.hp > 0 and marked69.enemy != actor.enemy:
			return marked69
		return _extreme(_opponents(actor), "threat", true)
	if actor.sheet_id == 67:
		return _extreme(_opponents(actor), "hp", true)
	if actor.sheet_id == 51:
		if bool(actor.kit.get("aoe_debuff_armed", false)):
			return null
		return _extreme(_opponents(actor), "attack", true)
	var last := _fighter_by_id(int(actor.kit.get("last_target_id", -1)))
	if last != null and last.alive and last.enemy != actor.enemy:
		return last
	return _extreme(_opponents(actor), "threat", true)


func _add_debuff(actor: Fighter, target: Fighter, kind: String, amount: float) -> void:
	if not is_instance_valid(target.unit):
		return
	if actor.enemy and not target.enemy and _relic_blocks > 0:
		_relic_blocks -= 1
		_host._log("%s へのデバフはレリックで無効" % target.unit.get_display_name())
		return
	var previous: Array = actor.kit.get("debuffs", [])
	for entry in previous:
		var item: Dictionary = entry
		var old := _fighter_by_id(int(item.get("target_id", -1)))
		if old != null:
			_apply_buff_value(old, str(item.get("kind", "")), -float(item.get("amount", 0.0)))
			_refresh_unit_aura(old.unit)
	_apply_buff_value(target, kind, amount)
	actor.kit["debuffs"] = [{
		"target_id": target.unit.get_instance_id(),
		"kind": kind,
		"amount": amount,
	}]


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
	var cleared := _fighter_by_id(target_id)
	if cleared != null:
		_refresh_unit_aura(cleared.unit)


func _play_status_transfer(from_unit: GameUnit, to_unit: GameUnit, is_buff: bool) -> void:
	if from_unit == null or to_unit == null or not is_instance_valid(from_unit) or not is_instance_valid(to_unit):
		return
	var parent: Node = _host.units_root if _host != null else null
	if parent == null:
		return
	from_unit.flash_status_aura(is_buff)
	await _wait(0.18)
	var start := from_unit.global_position + Vector3(0.0, 0.7, 0.0)
	var peak_from := from_unit.global_position + Vector3(0.0, 2.15, 0.0)
	var peak_to := to_unit.global_position + Vector3(0.0, 2.15, 0.0)
	var end := to_unit.global_position + Vector3(0.0, 0.7, 0.0)
	var orb := GameUnit.make_transfer_orb(is_buff)
	orb.name = "StatusTransfer"
	parent.add_child(orb)
	orb.global_position = start
	from_unit.clear_aura_flash()
	await _tween_node(orb, peak_from, STATUS_RISE_TIME)
	if not is_instance_valid(orb):
		return
	await _tween_node(orb, peak_to, STATUS_FLY_TIME)
	if not is_instance_valid(orb):
		return
	await _tween_node(orb, end, STATUS_FALL_TIME)
	if is_instance_valid(orb):
		orb.queue_free()


func _tween_node(node: Node3D, dest: Vector3, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _motion != null:
		_motion.kill()
	_motion = node.create_tween()
	_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(node, "global_position", dest, duration)
	await _motion.finished


func _refresh_unit_aura(unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	unit.set_status_auras(_unit_has_buff(unit), _unit_has_debuff(unit))


func _unit_has_buff(unit: GameUnit) -> bool:
	var unit_id := unit.get_instance_id()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if int(fighter.kit.get("buff_target_id", -1)) == unit_id:
			return true
		if int(fighter.kit.get("copy_target_id", -1)) == unit_id:
			return true
	return false


func _unit_has_debuff(unit: GameUnit) -> bool:
	var unit_id := unit.get_instance_id()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		for entry in fighter.kit.get("debuffs", []):
			var item: Dictionary = entry
			if int(item.get("target_id", -1)) == unit_id:
				return true
	return false


func _set_single_buff(actor: Fighter, target: Fighter, kind: String, amount: float) -> void:
	_clear_single_buff(actor)
	_apply_buff_value(target, kind, amount)
	actor.kit["buff_target_id"] = target.unit.get_instance_id()
	actor.kit["buff_kind_active"] = kind
	actor.kit["buff_amount_active"] = amount
	_refresh_unit_aura(target.unit)


func _apply_buff_value(target: Fighter, kind: String, amount: float) -> void:
	match kind:
		"highest_speed_bonus", "highest_attack_bonus":
			target.bonus_damage += amount
		"lowest_speed_speed", "highest_attack_speed", "highest_ap_speed":
			target.kit["received_speed"] = int(target.kit.get("received_speed", 0)) + int(round(amount))
			_recompute_speed(target, true)
		"highest_cost_fire":
			target.kit["received_fire"] = float(target.kit.get("received_fire", 0.0)) + amount
		"highest_attack_absorb":
			target.kit["received_absorb"] = float(target.kit.get("received_absorb", 0.0)) + amount
		"thunder_resist":
			target.kit["received_thunder_resist"] = float(target.kit.get("received_thunder_resist", 0.0)) - amount
		"fire_resist":
			target.kit["received_fire_resist"] = float(target.kit.get("received_fire_resist", 0.0)) - amount
		"ice_resist":
			target.kit["received_ice_resist"] = float(target.kit.get("received_ice_resist", 0.0)) - amount
		"ice_taken":
			target.kit["received_ice_taken"] = float(target.kit.get("received_ice_taken", 0.0)) + amount
		"defense_cut":
			target.kit["received_defense_cut"] = float(target.kit.get("received_defense_cut", 0.0)) + amount
		"absorb_resist":
			target.kit["received_absorb_resist"] = float(target.kit.get("received_absorb_resist", 0.0)) - amount
		"wind_resist":
			target.kit["received_wind_resist"] = float(target.kit.get("received_wind_resist", 0.0)) - amount
		"water_resist":
			target.kit["received_water_resist"] = float(target.kit.get("received_water_resist", 0.0)) - amount
		"lowest_attack_water":
			target.kit["received_water"] = float(target.kit.get("received_water", 0.0)) + amount
		"highest_attack_thunder":
			target.kit["received_thunder"] = float(target.kit.get("received_thunder", 0.0)) + amount
		"highest_attack_crit_damage", "highest_crit_crit_damage":
			target.crit_damage += amount
		"highest_attack_fire":
			target.kit["received_fire"] = float(target.kit.get("received_fire", 0.0)) + amount
		"highest_attack_earth":
			target.kit["received_earth"] = float(target.kit.get("received_earth", 0.0)) + amount
		"highest_attack_ice", "highest_attack_ice_other":
			target.kit["received_ice"] = float(target.kit.get("received_ice", 0.0)) + amount
		"highest_attack_wind":
			target.kit["received_wind"] = float(target.kit.get("received_wind", 0.0)) + amount
		"lowest_attack_bonus":
			target.attack += amount
		"front_taken_cut":
			target.kit["received_taken_cut"] = float(target.kit.get("received_taken_cut", 0.0)) + amount
		"highest_attack_dealt_cut":
			target.kit["outgoing_cut_buff"] = float(target.kit.get("outgoing_cut_buff", 0.0)) + amount
		"highest_crit_wind":
			target.kit["received_wind"] = float(target.kit.get("received_wind", 0.0)) + amount
		"lowest_priority_earth":
			target.kit["received_earth"] = float(target.kit.get("received_earth", 0.0)) + amount
		"most_earth_dot_vuln":
			target.kit["received_dot_taken"] = float(target.kit.get("received_dot_taken", 0.0)) + amount
		"lowest_speed_absorb":
			target.kit["received_absorb"] = float(target.kit.get("received_absorb", 0.0)) + amount
		"self_crit_rate":
			target.crit_rate += amount / 100.0
		"highest_threat_taken_cut":
			target.kit["received_taken_cut"] = float(target.kit.get("received_taken_cut", 0.0)) + amount
		"highest_thunder_thunder":
			target.kit["received_thunder"] = float(target.kit.get("received_thunder", 0.0)) + amount
		"highest_water_water":
			target.kit["received_water"] = float(target.kit.get("received_water", 0.0)) + amount
		"highest_hp_wind_resist":
			target.kit["received_wind_resist"] = float(target.kit.get("received_wind_resist", 0.0)) - amount
		"attr_resist_cut":
			target.attribute_resist -= amount
		"lowest_hp_dot_cut":
			target.kit["received_dot_cut"] = float(target.kit.get("received_dot_cut", 0.0)) + amount
		"lowest_defense_resist":
			target.attribute_resist += amount
		_:
			_era6_apply_buff_value(target, kind, amount)


func _clear_single_buff(actor: Fighter) -> void:
	var target := _fighter_by_id(int(actor.kit.get("buff_target_id", -1)))
	if target != null:
		_apply_buff_value(target, str(actor.kit.get("buff_kind_active", "")), -float(actor.kit.get("buff_amount_active", 0.0)))
		_refresh_unit_aura(target.unit)
	actor.kit["buff_target_id"] = -1


func _clear_copy(arita: Fighter) -> void:
	var target := _fighter_by_id(int(arita.kit.get("copy_target_id", -1)))
	if target != null:
		_apply_buff_value(target, str(arita.kit.get("copy_kind", "")), -float(arita.kit.get("copy_amount", 0.0)))
		_refresh_unit_aura(target.unit)
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
			await _arita_copy(ally)
			ally.kit["gauge"] = 0
			_show_gauge(ally)


func _arita_copy(arita: Fighter) -> void:
	_clear_copy(arita)
	var target := _fighter_by_id(int(arita.kit.get("last_target_id", -1)))
	if target == null or not target.alive:
		return
	var kind := str(arita.kit.get("last_kind", ""))
	var amount := float(arita.kit.get("last_amount", 0.0))
	if is_instance_valid(arita.unit) and is_instance_valid(target.unit):
		GameAudio.play_battle_support()
		await _play_status_transfer(arita.unit, target.unit, true)
	_apply_buff_value(target, kind, amount)
	arita.kit["copy_target_id"] = target.unit.get_instance_id()
	arita.kit["copy_kind"] = kind
	arita.kit["copy_amount"] = amount
	_refresh_unit_aura(target.unit)
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
	fighter.kit["gauge"] = int(fighter.kit.get("gauge", 0)) + _pop_music_gauge_step(fighter.enemy)
	GameAudio.play_battle_gauge()
	if int(fighter.kit.get("gauge", 0)) < 100:
		_show_gauge(fighter)
		return
	if was_buff:
		await _arita_copy(fighter)
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
	var session: GameSession = _host.session if _host != null else null
	return synergy_name in SynergyTracker.names_for_unit(fighter.unit, session)


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
	_era3_on_ally_action(actor, was_buff)
	_era5_on_ally_action(actor, was_buff)
	await _era2_after_turn(actor, was_buff)
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
		await _arita_on_ap_loss(actor, was_buff)
	_toyono_after_attack(actor)
	var pending_cut := int(actor.kit.get("pending_ap_cut", 0))
	if pending_cut > 0:
		_cut_ap(actor, pending_cut)
		actor.kit["pending_ap_cut"] = 0
	if actor.sheet_id == 79:
		var gain := _pop_music_gauge_step(actor.enemy)
		if bool(actor.kit.get("did_attack", false)):
			gain += _soar_bridge_gauge_step(actor.enemy)
		_fukusaki_add_gauge(actor, gain, true)
		if bool(actor.kit.get("did_force_attack", false)):
			_cut_ap(actor, int(actor.kit.get("self_ap_cut", 0)))
	actor.kit["did_attack"] = false
	actor.kit["did_force_attack"] = false


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


func _init_break_gauges(fighter: Fighter) -> void:
	fighter.break_left = {}
	for element in BREAK_SYNERGY.keys():
		fighter.break_left[str(element)] = BREAK_MAX


func _break_synergy_name(element: String) -> String:
	return str(BREAK_SYNERGY.get(element, ""))


func _can_break(actor: Fighter) -> bool:
	var synergy_name := _break_synergy_name(actor.element)
	if synergy_name.is_empty():
		return false
	return _has_synergy(actor, synergy_name)


func _break_damage_bonus(actor: Fighter) -> float:
	var synergy_name := _break_synergy_name(actor.element)
	if synergy_name.is_empty():
		return 0.0
	var count := _synergy_member_count(actor.enemy, synergy_name)
	if count >= 6:
		return 0.8
	if count >= 4:
		return 0.4
	return 0.0


func _reduce_break_gauge(actor: Fighter, target: Fighter) -> bool:
	if actor == null or target == null or not _can_break(actor):
		return false
	if not is_instance_valid(target.unit):
		return false
	var element := actor.element
	if element.is_empty():
		return false
	var left := int(target.break_left.get(element, BREAK_MAX))
	if left <= 0:
		return false
	left = maxi(0, left - BREAK_STEP)
	target.break_left[element] = left
	if left > 0:
		## 削られているあいだだけHP上に撃破ゲージを出す。
		_sync_break_gauge(target, element, false)
		return false
	GameAudio.play_battle_break()
	## 撃破瞬間は0で見せてからリセットして隠す。
	_sync_break_gauge(target, element, true)
	target.break_left[element] = BREAK_MAX
	if is_instance_valid(actor.unit) and is_instance_valid(target.unit):
		target.unit.popup_battle_text("撃破", Color(0.75, 0.9, 1.0))
		_host._log("%s が %s の%sを撃破した" % [actor.unit.get_display_name(), target.unit.get_display_name(), element])
	return true


func _sync_break_gauge(fighter: Fighter, element: String, just_broke: bool) -> void:
	if fighter == null or not is_instance_valid(fighter.unit):
		return
	if just_broke:
		## 空ゲージを一瞬出してから消す。
		fighter.unit.set_battle_break(0, BREAK_MAX, true, 0.35)
		return
	var left := int(fighter.break_left.get(element, BREAK_MAX))
	## 満タン（未削り／撃破後）は出さない。削り中だけ表示。
	fighter.unit.set_battle_break(left, BREAK_MAX, left < BREAK_MAX)


func _consume_action_skip(fighter: Fighter) -> bool:
	var first := int(fighter.kit.get("awaji_first_skip", 0))
	if first > 0:
		fighter.kit["awaji_first_skip"] = first - 1
		return true
	var broke_skip := int(fighter.kit.get("awaji_break_skip", 0))
	if broke_skip > 0:
		fighter.kit["awaji_break_skip"] = broke_skip - 1
		return true
	return false


func _awaji_after_ice_attack(actor: Fighter, target: Fighter, broke: bool) -> void:
	if actor.sheet_id != 7 or actor.element != "ice":
		return
	if target == null or not is_instance_valid(target.unit):
		return
	if target.alive and target.hp > 0 and not bool(actor.kit.get("first_ice_used", false)):
		actor.kit["first_ice_used"] = true
		target.kit["awaji_first_skip"] = maxi(1, int(actor.kit.get("first_skip", 1)))
		_host._log("%s の最初の氷で %s は次の行動をしない" % [actor.unit.get_display_name(), target.unit.get_display_name()])
	if not broke:
		return
	if not target.alive or target.hp <= 0:
		return
	await _awaji_break_damage(actor, target)
	if not target.alive or target.hp <= 0:
		return
	var cap := maxi(1, int(actor.kit.get("skip_cap", 1)))
	var cur := int(target.kit.get("awaji_break_skip", 0))
	if cur < cap:
		target.kit["awaji_break_skip"] = cap
		_host._log("%s は撃破で %d 回行動しない" % [target.unit.get_display_name(), cap])


func _awaji_break_damage(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null or not target.alive:
		return
	var bonus := _kit_bonus(actor, target, false) + _break_damage_bonus(actor)
	var connected := _roll_hit(target)
	if not connected:
		GameAudio.play_battle_miss()
		if is_instance_valid(target.unit):
			target.unit.popup_battle_text("外れ", Color(0.9, 0.9, 0.9))
			_host._log("%s の撃破ダメージは %s に外れた" % [actor.unit.get_display_name(), target.unit.get_display_name()])
		return
	var rolled := _roll_damage(actor, target, true, bonus, -1.0)
	var raw := int(rolled["amount"])
	var crit := bool(rolled["crit"])
	var guarded := target.guarding and raw > 0
	var dealt := _mitigate(target, raw)
	_play_attack_sounds(actor, crit)
	_play_hit_fx(actor, target)
	var absorbed := _apply_damage(target, dealt)
	if dealt > 0 and is_instance_valid(target.unit):
		var color := Color(1.0, 0.86, 0.35) if crit else Color(0.75, 0.9, 1.0)
		target.unit.popup_battle_text("撃破-%d" % dealt, color)
	if is_instance_valid(actor.unit) and is_instance_valid(target.unit):
		_host._log(_damage_log(actor.unit.get_display_name(), target.unit.get_display_name(), raw, dealt, absorbed, crit, guarded, "撃破ダメージ"))
	if dealt > 0:
		await _note_hit_received(actor, target, false)
	if not target.alive:
		_growth_killer = actor
		RelicCombat.note_kill(actor)
		_relic_on_slay(actor)
		await _ko(target)
	elif dealt > 0 and not target.guarding:
		await _flinch(target)


func _cut_ap(fighter: Fighter, amount: int) -> void:
	if amount <= 0 or fighter == null or not fighter.alive:
		return
	fighter.ap = maxi(0, fighter.ap - amount)
	if is_instance_valid(fighter.unit):
		fighter.unit.action_value = fighter.ap


func _synergy_member_count(enemy: bool, synergy_name: String) -> int:
	var count := 0
	for entry in _side(enemy):
		var ally: Fighter = entry
		if ally.alive and ally.hp > 0 and _has_synergy(ally, synergy_name):
			count += 1
	return count


func _gauge_step_table(count: int, thresholds: Array[int], values: Array[int], fallback: int) -> int:
	var chosen := fallback
	for index in thresholds.size():
		if count >= thresholds[index]:
			chosen = values[index]
	return chosen


func _oscillator_gauge_step(enemy: bool) -> int:
	var thresholds: Array[int] = [3, 5, 7, 9, 11]
	var values: Array[int] = [12, 14, 16, 18, 20]
	return _gauge_step_table(_synergy_member_count(enemy, "オシレーター・スペースシップ"), thresholds, values, 10)


func _bistron_gauge_step(enemy: bool) -> int:
	var thresholds: Array[int] = [2, 4, 6, 8]
	var values: Array[int] = [60, 70, 80, 90]
	return _gauge_step_table(_synergy_member_count(enemy, "ビストロン"), thresholds, values, 50)


func _soar_bridge_gauge_step(enemy: bool) -> int:
	var thresholds: Array[int] = [3, 5, 7, 9]
	var values: Array[int] = [18, 21, 24, 27]
	return _gauge_step_table(_synergy_member_count(enemy, "ソア橋"), thresholds, values, 15)


func _pop_music_gauge_step(enemy: bool) -> int:
	var thresholds: Array[int] = [3, 5, 7, 9]
	var values: Array[int] = [12, 14, 16, 18]
	return _gauge_step_table(_synergy_member_count(enemy, "ポップミュージック"), thresholds, values, 10)


func _randoseru_dot_ratio(enemy: bool) -> float:
	var count := _synergy_member_count(enemy, "ランドセル")
	if count >= 6:
		return 0.15
	if count >= 4:
		return 0.10
	return 0.05


func _jackpot_aoe_count(enemy: bool) -> int:
	var count := _synergy_member_count(enemy, "ジャックポット")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _note_hit_received(attacker: Fighter, target: Fighter, is_dot: bool) -> void:
	if is_dot or attacker == null or target == null:
		return
	if bool(attacker.kit.get("reflecting", false)):
		return
	if target.sheet_id == 9 and target.alive and target.hp > 0:
		_ikeda_on_hit(target, attacker)
	if target.sheet_id == 13 and target.alive and target.hp > 0:
		_inabe_on_hit(target, attacker)
	if target.sheet_id == 42 and target.alive and target.hp > 0:
		_suita_add_gauge(target, _oscillator_gauge_step(target.enemy))
	if target.sheet_id == 22 and target.alive:
		await _katsuyama_on_self_hit(attacker, target)
		return
	for entry in _side(target.enemy):
		var ally: Fighter = entry
		if ally.sheet_id == 22 and ally.alive and ally.hp > 0:
			await _katsuyama_on_ally_hit(attacker, ally)


func _katsuyama_roster(katsuyama: Fighter) -> Dictionary:
	var roster: Dictionary = katsuyama.kit.get("reflect_roster", {})
	if roster == null:
		roster = {}
		katsuyama.kit["reflect_roster"] = roster
	return roster


func _katsuyama_note_dealt(katsuyama: Fighter, target: Fighter) -> void:
	if not is_instance_valid(target.unit) or bool(katsuyama.kit.get("reflecting", false)):
		return
	var roster := _katsuyama_roster(katsuyama)
	var key := target.unit.get_instance_id()
	if not roster.has(key):
		roster[key] = 0
	katsuyama.kit["reflect_roster"] = roster


func _katsuyama_register_attacker(katsuyama: Fighter, attacker: Fighter) -> void:
	if not is_instance_valid(attacker.unit) or attacker.enemy == katsuyama.enemy:
		return
	var roster := _katsuyama_roster(katsuyama)
	var key := attacker.unit.get_instance_id()
	roster[key] = int(roster.get(key, 0)) + 1
	katsuyama.kit["reflect_roster"] = roster


func _katsuyama_on_self_hit(attacker: Fighter, katsuyama: Fighter) -> void:
	_katsuyama_register_attacker(katsuyama, attacker)
	await _katsuyama_add_gauge(katsuyama, _oscillator_gauge_step(katsuyama.enemy))


func _katsuyama_on_ally_hit(attacker: Fighter, katsuyama: Fighter) -> void:
	_katsuyama_register_attacker(katsuyama, attacker)
	await _katsuyama_add_gauge(katsuyama, int(katsuyama.kit.get("ally_hit_gauge", 0)))


func _katsuyama_add_gauge(katsuyama: Fighter, amount: int) -> void:
	if amount <= 0 or not katsuyama.alive or not is_instance_valid(katsuyama.unit):
		return
	var gauge := int(katsuyama.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		katsuyama.kit["gauge"] = gauge
		_show_gauge(katsuyama)
		return
	katsuyama.kit["gauge"] = 0
	_show_gauge(katsuyama)
	katsuyama.unit.popup_battle_text("雷返し", Color(0.85, 0.9, 1.0))
	_host._log("%s の雷が返る" % katsuyama.unit.get_display_name())
	await _katsuyama_reflect(katsuyama)


func _katsuyama_reflect(katsuyama: Fighter) -> void:
	katsuyama.kit["reflecting"] = true
	var roster := _katsuyama_roster(katsuyama)
	var cap := maxi(1, int(katsuyama.kit.get("reflect_cap", 2)))
	var plan: Array = []
	for key in roster.keys():
		var foe := _fighter_by_id(int(key))
		if foe == null or not foe.alive or foe.enemy == katsuyama.enemy:
			continue
		var hits := int(roster[key])
		if hits <= 0:
			hits = 1
		hits = mini(hits, cap)
		plan.append({"foe": foe, "hits": hits, "id": foe.unit.unit_id})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"])
	)
	if plan.is_empty():
		var fallback := _extreme(_opponents(katsuyama), "threat", true)
		if fallback != null:
			plan.append({"foe": fallback, "hits": 1, "id": fallback.unit.unit_id})
	for entry in plan:
		var foe: Fighter = entry["foe"]
		for _hit in int(entry["hits"]):
			if not katsuyama.alive or foe == null or not foe.alive:
				break
			await _resolve_packet(katsuyama, foe, true, false, false)
			if not foe.alive:
				break
	katsuyama.kit["reflect_roster"] = {}
	katsuyama.kit["reflecting"] = false


func _suita_add_gauge(suita: Fighter, amount: int) -> void:
	if amount <= 0 or not suita.alive or not is_instance_valid(suita.unit):
		return
	var gauge := int(suita.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		suita.kit["gauge"] = gauge
		_show_gauge(suita)
		return
	suita.kit["gauge"] = 0
	_show_gauge(suita)
	var cut := int(suita.kit.get("ap_cut", 0))
	if bool(suita.kit.get("did_attack", false)):
		suita.kit["pending_ap_cut"] = int(suita.kit.get("pending_ap_cut", 0)) + cut
	else:
		_cut_ap(suita, cut)
	suita.unit.popup_battle_text("早まり", Color(0.7, 0.95, 0.55))
	_host._log("%s の次の行動が早くなる" % suita.unit.get_display_name())


func _apply_randoseru_on(actor: Fighter, target: Fighter) -> void:
	if not actor.alive or not _has_synergy(actor, "ランドセル"):
		return
	if target == null or not target.alive:
		return
	var layers := 1
	if actor.sheet_id == 60 and not bool(actor.kit.get("extra_layer_used", false)):
		layers += int(actor.kit.get("extra_layers", 0))
		actor.kit["extra_layer_used"] = true
	_add_layers(target, "thunder", layers)
	var saved := float(actor.kit.get("dot_ratio", 0.05))
	actor.kit["dot_ratio"] = _randoseru_dot_ratio(actor.enemy)
	var old_element := actor.element
	actor.element = "thunder"
	if target.alive:
		await _apply_dot(actor, target)
	actor.element = old_element
	actor.kit["dot_ratio"] = saved
	actor.kit["randoseru_applied"] = true


func _toyono_after_attack(actor: Fighter) -> void:
	if actor.sheet_id != 60 or not actor.alive:
		return
	if bool(actor.kit.get("randoseru_applied", false)):
		_cut_ap(actor, int(actor.kit.get("ap_cut", 0)))
		if is_instance_valid(actor.unit):
			actor.unit.popup_battle_text("早まり", Color(0.95, 0.9, 0.45))
	actor.kit["randoseru_applied"] = false


func _fukusaki_on_ap_loss(fighter: Fighter) -> void:
	if fighter.sheet_id != 79 or not fighter.alive:
		return
	_fukusaki_add_gauge(fighter, _pop_music_gauge_step(fighter.enemy), false)


func _fukusaki_add_gauge(fukusaki: Fighter, amount: int, _from_attack: bool) -> void:
	if amount <= 0 or not fukusaki.alive or not is_instance_valid(fukusaki.unit):
		return
	if bool(fukusaki.kit.get("filling_now", false)):
		return
	var gauge := int(fukusaki.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fukusaki.kit["gauge"] = gauge
		_show_gauge(fukusaki)
		return
	fukusaki.kit["filling_now"] = true
	fukusaki.kit["gauge"] = 0
	_show_gauge(fukusaki)
	fukusaki.kit["force_attack"] = true
	fukusaki.kit["water_empowered"] = true
	fukusaki.ap = 0
	fukusaki.unit.action_value = 0
	fukusaki.unit.popup_battle_text("即攻撃", Color(0.45, 0.75, 1.0))
	_host._log("%s のゲージが満ち、すぐに攻撃する" % fukusaki.unit.get_display_name())
	var ally := _extreme_other(_side(fukusaki.enemy), fukusaki, "ap", true)
	if ally != null:
		_cut_ap(ally, int(fukusaki.kit.get("ally_ap_cut", 0)))
	fukusaki.kit["filling_now"] = false


func _extreme_other(pool: Array, skip: Fighter, stat: String, highest: bool) -> Fighter:
	var filtered: Array = []
	for entry in pool:
		var fighter: Fighter = entry
		if fighter != skip:
			filtered.append(fighter)
	return _extreme(filtered, stat, highest)


func _miyake_store_aoe(miyake: Fighter, primary: Fighter) -> void:
	if not miyake.alive or primary == null or not is_instance_valid(primary.unit):
		return
	if bool(miyake.kit.get("aoe_instant", false)):
		miyake.kit["aoe_instant"] = false
		miyake.kit["aoe_pending"] = true
		miyake.kit["aoe_primary_id"] = primary.unit.get_instance_id()
		await _miyake_release_aoe(miyake)
		return
	miyake.kit["aoe_pending"] = true
	miyake.kit["aoe_primary_id"] = primary.unit.get_instance_id()
	if is_instance_valid(miyake.unit):
		miyake.unit.popup_battle_text("範囲待機", Color(1.0, 0.7, 0.35))


func _miyake_on_ap_loss(fighter: Fighter) -> void:
	if fighter.sheet_id != 88 or not bool(fighter.kit.get("aoe_pending", false)):
		return
	await _miyake_release_aoe(fighter)


func _miyake_add_gauge(miyake: Fighter, amount: int) -> void:
	if amount <= 0 or not miyake.alive or not is_instance_valid(miyake.unit):
		return
	var gauge := int(miyake.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		miyake.kit["gauge"] = gauge
		_show_gauge(miyake)
		return
	miyake.kit["gauge"] = 0
	_show_gauge(miyake)
	if bool(miyake.kit.get("aoe_pending", false)):
		await _miyake_release_aoe(miyake)
	else:
		miyake.kit["aoe_instant"] = true
		miyake.unit.popup_battle_text("即範囲", Color(1.0, 0.55, 0.3))


func _miyake_aoe_targets(miyake: Fighter, primary_id: int) -> Array:
	var need := _jackpot_aoe_count(miyake.enemy)
	var targets: Array = []
	var primary := _fighter_by_id(primary_id)
	if primary != null and primary.alive and primary.enemy != miyake.enemy:
		targets.append(primary)
	var others: Array = []
	for entry in _opponents(miyake):
		var foe: Fighter = entry
		if foe == primary:
			continue
		others.append(foe)
	others.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	for foe in others:
		if targets.size() >= need:
			break
		targets.append(foe)
	return targets


func _miyake_release_aoe(miyake: Fighter) -> void:
	if not bool(miyake.kit.get("aoe_pending", false)):
		return
	miyake.kit["aoe_pending"] = false
	if not miyake.alive or miyake.hp <= 0:
		return
	var primary_id := int(miyake.kit.get("aoe_primary_id", -1))
	miyake.kit.erase("aoe_primary_id")
	var targets := _miyake_aoe_targets(miyake, primary_id)
	if targets.is_empty():
		return
	var pierce := int(miyake.kit.get("guard_pierce_left", 0)) > 0
	if pierce:
		miyake.kit["guard_pierce_left"] = int(miyake.kit.get("guard_pierce_left", 0)) - 1
	miyake.kit["aoe_resolving"] = true
	if is_instance_valid(miyake.unit):
		miyake.unit.popup_battle_text("範囲", Color(1.0, 0.55, 0.28))
		_host._log("%s の貯めた範囲が入る" % miyake.unit.get_display_name())
	for entry in targets:
		var foe: Fighter = entry
		if foe == null or not foe.alive:
			continue
		if pierce:
			foe.kit["ignore_guard"] = true
		await _resolve_packet(miyake, foe, false, true, false)
		foe.kit["ignore_guard"] = false
		if not miyake.alive:
			break
	miyake.kit["aoe_resolving"] = false


func _opening_kits() -> void:
	_era2_battle_start_flags()
	await _otsu_opening_layers()
	await _daito_opening_dots()
	await _era4_opening()
	await _era6_opening()
	var openers: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.alive or not fighter.in_queue or fighter.hp <= 0:
			continue
		if fighter.sheet_id != 8:
			continue
		if fighter.stand_slot < 0 or fighter.stand_slot >= BoardController.FRONT_COUNT:
			continue
		openers.append(fighter)
	openers.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	for entry in openers:
		var opener: Fighter = entry
		if not opener.alive or opener.hp <= 0:
			continue
		await _ikuno_opening(opener)


func _ikuno_opening(actor: Fighter) -> void:
	if actor == null or not actor.alive or not is_instance_valid(actor.unit):
		return
	var target := _ikuno_opening_target(actor)
	if target == null or not target.alive or not is_instance_valid(target.unit):
		_host._log("%s の開幕攻撃は対象がいない" % actor.unit.get_display_name())
		return
	actor.kit["opening_target_id"] = target.unit.get_instance_id()
	actor.kit["opening_strike"] = true
	if is_instance_valid(actor.unit):
		actor.unit.play_battle_role("attack")
		actor.unit.popup_battle_text("開幕", Color(0.7, 0.9, 1.0))
	_host._log("%s の開幕攻撃 → %s" % [actor.unit.get_display_name(), target.unit.get_display_name()])
	await _wait(ATTACK_HIT_TIME)
	actor.kit["continuity_done"] = false
	var connected := _roll_hit(target)
	var broke := _reduce_break_gauge(actor, target)
	if not connected:
		GameAudio.play_battle_miss()
		if is_instance_valid(target.unit):
			target.unit.popup_battle_text("外れ", Color(0.9, 0.9, 0.9))
		_host._log("%s の開幕攻撃は %s に外れた" % [actor.unit.get_display_name(), target.unit.get_display_name()])
		await _continuity_with_attack(actor, target)
		actor.kit["opening_strike"] = false
		actor.kit["follow_left"] = int(actor.kit.get("follow_attacks", 1))
		if is_instance_valid(actor.unit) and not actor.unit.battle_ko:
			actor.unit.play_battle_role("idle")
		await _wait(0.12)
		return
	var bonus := _kit_bonus(actor, target, false)
	var rolled := _roll_damage(actor, target, true, bonus, -1.0)
	var raw := int(rolled["amount"])
	var crit := bool(rolled["crit"])
	var guarded := target.guarding and raw > 0
	var dealt := _mitigate(target, raw)
	_play_attack_sounds(actor, crit)
	_play_hit_fx(actor, target)
	var absorbed := _apply_damage(target, dealt)
	if dealt > 0 and is_instance_valid(target.unit):
		var color := Color(1.0, 0.86, 0.35) if crit else Color(0.75, 0.9, 1.0)
		target.unit.popup_battle_text("-%d" % dealt, color)
	_host._log(_damage_log(actor.unit.get_display_name(), target.unit.get_display_name(), raw, dealt, absorbed, crit, guarded, "開幕ダメージ"))
	await _continuity_with_attack(actor, target)
	if dealt > 0 and target.alive and target.hp > 0:
		var bump := int(actor.kit.get("ap_bump", 0))
		if bump > 0:
			target.ap += bump
			if is_instance_valid(target.unit):
				target.unit.action_value = target.ap
			_host._log("%s の行動ポイントが %d 上がった" % [target.unit.get_display_name(), bump])
		await _note_hit_received(actor, target, false)
	actor.kit["opening_strike"] = false
	if target.alive and target.hp > 0:
		actor.kit["follow_left"] = int(actor.kit.get("follow_attacks", 1))
	else:
		actor.kit["follow_left"] = 0
		_growth_killer = actor
		RelicCombat.note_kill(actor)
		_relic_on_slay(actor)
		await _ko(target)
	if broke and target.alive and target.hp > 0:
		pass
	if is_instance_valid(actor.unit) and not actor.unit.battle_ko:
		actor.unit.play_battle_role("idle")
	await _wait(0.12)


func _ikuno_opening_target(actor: Fighter) -> Fighter:
	var slot := actor.stand_slot
	if slot < 0 or slot >= BoardController.FRONT_COUNT:
		return null
	var matched: Fighter = null
	var smallest: Fighter = null
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe.stand_slot < 0 or foe.stand_slot >= BoardController.FRONT_COUNT:
			continue
		if foe.stand_slot == slot:
			matched = foe
		if smallest == null or foe.unit.unit_id < smallest.unit.unit_id:
			smallest = foe
	return matched if matched != null else smallest


func _ikeda_on_hit(ikeda: Fighter, attacker: Fighter) -> void:
	if ikeda == null or not ikeda.alive or ikeda.hp <= 0 or not is_instance_valid(ikeda.unit):
		return
	if attacker != null and is_instance_valid(attacker.unit) and attacker.enemy != ikeda.enemy:
		ikeda.kit["last_hitter_id"] = attacker.unit.get_instance_id()
	var step := _oscillator_gauge_step(ikeda.enemy)
	if step <= 0:
		return
	var gauge := int(ikeda.kit.get("gauge", 0)) + step
	GameAudio.play_battle_gauge()
	if gauge >= 100:
		ikeda.kit["gauge"] = 0
		ikeda.kit["multi_armed"] = true
		_show_gauge(ikeda)
		if is_instance_valid(ikeda.unit):
			ikeda.unit.popup_battle_text("連続", Color(0.45, 0.75, 1.0))
		_host._log("%s のゲージが満ち、次の水攻撃が連続する" % ikeda.unit.get_display_name())
		return
	ikeda.kit["gauge"] = gauge
	_show_gauge(ikeda)


func _ikeda_extra_hits(actor: Fighter, primary: Fighter) -> void:
	if actor == null or primary == null:
		return
	var count := maxi(0, int(actor.kit.get("extra_hits", 1)))
	for _i in count:
		if not actor.alive or not primary.alive or primary.hp <= 0:
			break
		actor.kit["extra_resolving"] = true
		if is_instance_valid(actor.unit):
			actor.unit.popup_battle_text("追加", Color(0.45, 0.8, 1.0))
		await _resolve_packet(actor, primary, true, false, false)
		actor.kit["extra_resolving"] = false
		if not primary.alive:
			break


func _izumi_on_first_targeted(attacker: Fighter, izumi: Fighter) -> void:
	if izumi == null or attacker == null or not is_instance_valid(izumi.unit) or not is_instance_valid(attacker.unit):
		return
	if bool(izumi.kit.get("first_hit_done", false)):
		return
	izumi.kit["first_hit_done"] = true
	var resist_cut := float(izumi.kit.get("first_hit_resist", 0.0))
	var absorb_cut := float(izumi.kit.get("first_hit_absorb", 0.0))
	attacker.attribute_resist -= resist_cut
	attacker.kit["received_absorb_resist"] = float(attacker.kit.get("received_absorb_resist", 0.0)) - absorb_cut
	_host._log("%s を最初に攻撃した %s の耐性が下がった" % [izumi.unit.get_display_name(), attacker.unit.get_display_name()])


func _refresh_passive_kits() -> void:
	_refresh_ise_back_buff()
	_refresh_uda_guard()
	_refresh_otsu_buff()
	_refresh_sakai_aura()
	_refresh_tanabe_back_buff()
	_refresh_era4_back_buffs()
	_era6_refresh_passive()


func _best_sheet(enemy: bool, sheet_id: int) -> Fighter:
	var chosen: Fighter = null
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy != enemy or fighter.sheet_id != sheet_id:
			continue
		if not fighter.alive or fighter.hp <= 0 or not is_instance_valid(fighter.unit):
			continue
		if chosen == null or fighter.unit.stars > chosen.unit.stars or (fighter.unit.stars == chosen.unit.stars and fighter.unit.unit_id < chosen.unit.unit_id):
			chosen = fighter
	return chosen


func _is_backline(fighter: Fighter) -> bool:
	return fighter != null and fighter.stand_slot >= BoardController.FRONT_COUNT


func _note_primary_target_effects(actor: Fighter, target: Fighter) -> void:
	_taishi_on_targeted(actor, target)
	_era5_on_targeted(actor, target)
	if target.sheet_id == 14 and not bool(target.kit.get("first_targeted", false)):
		target.kit["first_targeted"] = true
		actor.kit["attack_no_crit"] = true
		target.kit["hit_speed_bonus"] = int(target.kit.get("hit_speed", 0))
	var uda := _best_sheet(target.enemy, 15)
	if uda != null and _is_backline(uda) and int(uda.kit.get("guard_target_id", -1)) == target.unit.get_instance_id():
		if not bool(uda.kit.get("guard_first_used", false)):
			uda.kit["guard_first_used"] = true
			actor.kit["attack_no_crit"] = true
			target.kit["hit_speed_bonus"] = int(uda.kit.get("hit_speed", 0))
	_era2_on_targeted(actor, target)
	_era6_on_targeted(actor, target)


func _on_attack_contact(actor: Fighter, target: Fighter, _connected: bool, dealt: int, direct: bool) -> void:
	_era6_on_attack_contact(actor, target, _connected)
	if direct and target.sheet_id == 12 and target.alive and target.hp > 0:
		await _itami_reflect_wind(target, actor)
	if direct and dealt > 0 and actor.sheet_id == 15 and bool(actor.kit.get("aoe_resolving", false)) == false:
		# splash cut handled below via aoe packet flag in caller? use kit flag on actor for splash packets
		pass
	if not direct and dealt >= 0 and actor.sheet_id == 15:
		_uda_on_splash(actor, target)
	if direct and actor.sheet_id == 12 and actor.alive:
		actor.kit["last_dot_target_id"] = target.unit.get_instance_id()


func _ibaraki_before_hit(ibaraki: Fighter) -> void:
	var gain := int(ibaraki.kit.get("hit_max_hp", 0))
	if gain <= 0:
		return
	ibaraki.max_hp += gain
	ibaraki.hp += gain
	if is_instance_valid(ibaraki.unit):
		ibaraki.unit.set_battle_hp(ibaraki.hp, ibaraki.max_hp)
		ibaraki.unit.popup_battle_text("HP+%d" % gain, Color(0.55, 0.9, 0.7))


func _ibaraki_on_break(ibaraki: Fighter) -> void:
	if bool(ibaraki.kit.get("break_bonus_used", false)):
		return
	ibaraki.kit["break_bonus_used"] = true
	ibaraki.kit["break_taken_cut_active"] = float(ibaraki.kit.get("break_taken_cut", 0.0))
	ibaraki.attribute_resist += float(ibaraki.kit.get("break_resist", 0.0))
	if is_instance_valid(ibaraki.unit):
		ibaraki.unit.kit_flags["break_taken_armed"] = true
		ibaraki.unit.popup_battle_text("撃破耐性", Color(0.55, 0.8, 1.0))
	_host._log("%s は水の撃破で耐性が上がった" % ibaraki.unit.get_display_name())


func _itami_reflect_wind(itami: Fighter, attacker: Fighter) -> void:
	if attacker == null or not attacker.alive or attacker.enemy == itami.enemy:
		return
	var layers := maxi(1, int(itami.kit.get("wind_layers", 4)))
	itami.kit["dot_ratio"] = _tokaido_dot_ratio(itami.enemy)
	_add_layers(attacker, "wind", layers)
	itami.kit["last_dot_target_id"] = attacker.unit.get_instance_id()
	await _apply_dot(itami, attacker)
	if not bool(itami.kit.get("resist_gained", false)):
		itami.kit["resist_gained"] = true
		itami.attribute_resist += float(itami.kit.get("resist_gain", 0.0))
		itami.kit["hit_speed_bonus"] = int(itami.kit.get("hit_speed", 0))
		_host._log("%s の属性耐性が上がった" % itami.unit.get_display_name())


func _itami_dot_on(actor: Fighter, target: Fighter) -> void:
	if target == null or not target.alive:
		return
	actor.kit["dot_ratio"] = _tokaido_dot_ratio(actor.enemy)
	_add_layers(target, "wind", 1)
	actor.kit["last_dot_target_id"] = target.unit.get_instance_id()
	await _apply_dot(actor, target)


func _inabe_on_hit(inabe: Fighter, attacker: Fighter) -> void:
	if inabe == null or not inabe.alive or inabe.hp <= 0:
		return
	if attacker != null and is_instance_valid(attacker.unit) and attacker.enemy != inabe.enemy:
		inabe.kit["last_hitter_id"] = attacker.unit.get_instance_id()
	var step := _oscillator_gauge_step(inabe.enemy)
	var gauge := int(inabe.kit.get("gauge", 0)) + step
	GameAudio.play_battle_gauge()
	if gauge >= 100:
		inabe.kit["gauge"] = 0
		inabe.kit["charged_ready"] = true
		if attacker != null and is_instance_valid(attacker.unit):
			inabe.kit["charged_target_id"] = attacker.unit.get_instance_id()
		_show_gauge(inabe)
		if is_instance_valid(inabe.unit):
			inabe.unit.popup_battle_text("次の風", Color(0.55, 0.95, 0.7))
		return
	inabe.kit["gauge"] = gauge
	_show_gauge(inabe)


func _tokaido_dot_ratio(enemy: bool) -> float:
	var count := _synergy_member_count(enemy, "東海道戦争")
	if count >= 6:
		return 0.15
	if count >= 4:
		return 0.10
	return 0.05


func _goshodan_splash_count(actor: Fighter) -> int:
	if not _has_synergy(actor, "世界はゴ冗談") and actor.sheet_id != 16:
		return 1
	var count := _synergy_member_count(actor.enemy, "世界はゴ冗談")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _goshodan_extras(actor: Fighter, primary: Fighter, need: int) -> Array:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe != primary and foe.alive:
			pool.append(foe)
	pool.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	if actor.sheet_id == 16 and actor.element == "water" and int(actor.kit.get("splash_retarget_left", 0)) > 0 and need > 0:
		actor.kit["splash_retarget_left"] = 0
		var best: Fighter = null
		for entry in pool:
			var foe: Fighter = entry
			if best == null or foe.hp > best.hp or (foe.hp == best.hp and foe.unit.unit_id < best.unit.unit_id):
				best = foe
		if best != null:
			pool.erase(best)
			pool.push_front(best)
	var chosen: Array = []
	for entry in pool:
		if chosen.size() >= need:
			break
		chosen.append(entry)
	return chosen


func _refresh_ise_back_buff() -> void:
	for key in _fighters.keys():
		var ise: Fighter = _fighters[key]
		if ise.sheet_id != 11 or not ise.alive:
			continue
		if _is_backline(ise) and ise.hp > 0:
			ise.kit["front_buff_active"] = false
			var pool: Array = []
			for ally in _side(ise.enemy):
				var other: Fighter = ally
				if other != ise and other.alive:
					pool.append(other)
			if pool.is_empty():
				pool.append(ise)
			var target := _extreme(pool, "attack", true)
			if target == null:
				target = ise
			_set_single_buff(ise, target, "highest_attack_absorb", float(ise.kit.get("buff_amount", 0.0)))
		elif not _is_backline(ise):
			if int(ise.kit.get("buff_target_id", -1)) >= 0 and not bool(ise.kit.get("front_buff_active", false)):
				_clear_single_buff(ise)


func _ise_on_absorb_layers(actor: Fighter, primary: Fighter) -> void:
	if actor == null or primary == null or actor.element != "absorb":
		return
	var ise := _best_sheet(actor.enemy, 11)
	if ise == null or not _is_backline(ise) or ise.hp <= 0:
		return
	var layers := int(primary.layers.get("absorb", 0))
	if layers <= 0:
		return
	var times := mini(layers, maxi(1, int(ise.kit.get("break_extra", 2))))
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == primary or not foe.alive or foe.hp <= 0:
			continue
		var left := int(foe.break_left.get("absorb", BREAK_MAX))
		if left <= 0:
			continue
		var reduce := mini(times, left)
		foe.break_left["absorb"] = left - reduce
		if is_instance_valid(foe.unit):
			foe.unit.popup_battle_text("撃破-%d" % reduce, Color(0.75, 0.85, 1.0))
	ise.kit["ise_extra_budget"] = int(ise.kit.get("ise_extra_budget", int(ise.kit.get("extra_attacks", 1))))


func _ise_follow_attacks(actor: Fighter, primary: Fighter) -> void:
	var ise := _best_sheet(actor.enemy, 11)
	if ise == null or not _is_backline(ise) or ise.hp <= 0:
		return
	var left := int(ise.kit.get("ise_attacks_left", int(ise.kit.get("extra_attacks", 1))))
	if left <= 0:
		return
	var layers := int(primary.layers.get("absorb", 0))
	if layers <= 0:
		return
	var times := mini(left, mini(layers, maxi(1, int(ise.kit.get("break_extra", 2)))))
	ise.kit["ise_attacks_left"] = left - times
	for _i in times:
		if not primary.alive or primary.hp <= 0:
			break
		await _resolve_packet(actor, primary, true, false, false)


func _refresh_uda_guard() -> void:
	for key in _fighters.keys():
		var uda: Fighter = _fighters[key]
		if uda.sheet_id != 15:
			continue
		var old := _fighter_by_id(int(uda.kit.get("guard_target_id", -1)))
		if old != null:
			old.kit["guard_taken_cut_active"] = 0.0
		uda.kit["guard_target_id"] = -1
		if not uda.alive or uda.hp <= 0 or not _is_backline(uda):
			continue
		var pool: Array = []
		for ally in _side(uda.enemy):
			var other: Fighter = ally
			if other != uda and other.alive and other.in_queue:
				pool.append(other)
		var target := _extreme(pool, "threat", true)
		if target == null:
			continue
		uda.kit["guard_target_id"] = target.unit.get_instance_id()
		target.kit["guard_taken_cut_active"] = float(uda.kit.get("guard_taken_cut", 0.0))


func _uda_on_splash(uda: Fighter, target: Fighter) -> void:
	var guarded := _fighter_by_id(int(uda.kit.get("guard_target_id", -1)))
	if guarded == null or not guarded.alive:
		return
	if not _is_backline(uda):
		return
	target.kit["outgoing_cut"] = float(uda.kit.get("splash_cut", 0.0))


func _refresh_otsu_buff() -> void:
	var otsu := _best_sheet(false, 17)
	var enemy_otsu := _best_sheet(true, 17)
	for bearer in [otsu, enemy_otsu]:
		if bearer == null or not bearer.alive or bearer.hp <= 0:
			continue
		var target := _extreme(_side(bearer.enemy), "attack", true)
		if target == null:
			continue
		_set_single_buff(bearer, target, "highest_attack_thunder", float(bearer.kit.get("buff_amount", 0.0)))


func _otsu_try_extra_layer(primary: Fighter, _added: int) -> void:
	var otsu := _best_sheet(not primary.enemy, 17)
	if otsu == null or otsu.hp <= 0:
		return
	var used := int(otsu.kit.get("otsu_extra_used", 0))
	var cap := maxi(1, int(otsu.kit.get("extra_cap", 2)))
	if used >= cap:
		return
	var front := _highest_attack_front(primary.enemy)
	if front == null or front == primary:
		return
	var add := maxi(1, int(otsu.kit.get("extra_layers", 1)))
	add = mini(add, cap - used)
	front.layers["thunder"] = int(front.layers.get("thunder", 0)) + add
	front.kit["otsu_marked_layers"] = int(front.kit.get("otsu_marked_layers", 0)) + add
	otsu.kit["otsu_extra_used"] = used + add


func _highest_attack_front(enemy: bool) -> Fighter:
	var pool: Array = []
	for entry in _side(enemy):
		var fighter: Fighter = entry
		if fighter.stand_slot >= 0 and fighter.stand_slot < BoardController.FRONT_COUNT:
			pool.append(fighter)
	return _extreme(pool, "attack", true)


func _otsu_opening_layers() -> void:
	for enemy_side in [false, true]:
		var otsu := _best_sheet(enemy_side, 17)
		if otsu == null or not is_instance_valid(otsu.unit):
			continue
		var pending := int(otsu.kit.get("otsu_pending", 0))
		if pending <= 0:
			continue
		var front := _highest_attack_front(otsu.enemy)
		if front == null:
			continue
		var add := mini(pending, maxi(1, int(otsu.kit.get("extra_cap", 2)) - int(otsu.kit.get("otsu_extra_used", 0))))
		if add <= 0:
			continue
		front.layers["thunder"] = int(front.layers.get("thunder", 0)) + add
		front.kit["otsu_marked_layers"] = int(front.kit.get("otsu_marked_layers", 0)) + add
		otsu.kit["otsu_extra_used"] = int(otsu.kit.get("otsu_extra_used", 0)) + add
		otsu.kit["otsu_pending"] = 0
		if is_instance_valid(otsu.unit):
			otsu.unit.kit_flags["otsu_pending"] = 0
		_host._log("%s の開始層が %s に付いた" % [otsu.unit.get_display_name(), front.unit.get_display_name()])
		await _apply_dot(otsu, front)


func _otsu_on_death(otsu: Fighter) -> void:
	var front := _highest_attack_front(otsu.enemy)
	if front == null or not front.alive:
		return
	var marked := int(front.kit.get("otsu_marked_layers", 0))
	if marked <= 0:
		return
	var hits := mini(marked, maxi(1, int(otsu.kit.get("death_hits", 2))))
	for _i in hits:
		if not front.alive or front.hp <= 0:
			break
		front.kit["otsu_marked_layers"] = maxi(0, int(front.kit.get("otsu_marked_layers", 0)) - 1)
		otsu.kit["attack_no_crit"] = true
		await _resolve_packet(otsu, front, true, false, false)
		otsu.kit["attack_no_crit"] = false


func _ono_cleanse(actor: Fighter, target: Fighter) -> void:
	var need := maxi(1, int(actor.kit.get("cleanse_count", 1)))
	var cleared := 0
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if int(fighter.kit.get("buff_target_id", -1)) != target.unit.get_instance_id():
			continue
		_clear_single_buff(fighter)
		cleared += 1
		if cleared >= need:
			break
	if cleared > 0 and is_instance_valid(target.unit):
		target.unit.popup_battle_text("バフ解除", Color(1.0, 0.7, 0.35))
		_host._log("%s が %s のバフを消した" % [actor.unit.get_display_name(), target.unit.get_display_name()])


func _most_buffed_foe(actor: Fighter) -> Fighter:
	var chosen: Fighter = null
	var best := -1
	for entry in _opponents(actor):
		var foe: Fighter = entry
		var count := 1 if _unit_has_buff(foe.unit) else 0
		if chosen == null or count > best or (count == best and foe.unit.unit_id < chosen.unit.unit_id):
			chosen = foe
			best = count
	if chosen != null and best > 0:
		return chosen
	return _extreme(_opponents(actor), "threat", true)


func _sumoto_active(enemy_side: bool) -> bool:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id != 46 or fighter.enemy != enemy_side:
			continue
		if fighter.alive and fighter.hp > 0 and is_instance_valid(fighter.unit):
			return true
	return false


func _sumoto_on_miss(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null or target.sheet_id != 46:
		return
	if not target.alive or target.hp <= 0 or not is_instance_valid(target.unit):
		return
	if bool(actor.kit.get("sumoto_taunt_done", false)):
		return
	actor.kit["sumoto_taunt_done"] = true
	actor.kit["force_target_id"] = target.unit.get_instance_id()
	_host._log("%s の次の攻撃は %s を狙う" % [actor.unit.get_display_name(), target.unit.get_display_name()])


func _era2_battle_start_flags() -> void:
	var kakogawa := _best_sheet(false, 19)
	if kakogawa != null and not _is_backline(kakogawa) and kakogawa.hp > 0:
		kakogawa.kit["kakogawa_left"] = 1
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 32 and not _is_backline(fighter) and fighter.hp > 0:
			fighter.kit["started_front"] = true
			fighter.kit["front_crit_damage_active"] = float(fighter.kit.get("front_crit_damage", 0.0))
		if fighter.sheet_id == 34:
			fighter.kit["ice_forced_left"] = 1
		if fighter.sheet_id == 29:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
	_era3_battle_start_sync()
	_era4_battle_start_sync()
	_era5_battle_start_sync()


func _era2_attack_extras(actor: Fighter, primary: Fighter, extras: Array) -> Array:
	var out: Array = extras.duplicate()
	if actor.element == "fire":
		var kago := _best_sheet(actor.enemy, 19)
		if kago != null and int(kago.kit.get("kakogawa_left", 0)) > 0:
			kago.kit["kakogawa_left"] = int(kago.kit.get("kakogawa_left", 0)) - 1
			var need := maxi(1, int(kago.kit.get("extra_targets", 1)))
			var picks := _era2_lowest_defense(actor, primary, need, out)
			for foe in picks:
				if not out.has(foe):
					out.append(foe)
				foe.kit["kakogawa_fire_vuln"] = float(kago.kit.get("splash_fire_vuln", 0.0))
	if actor.element == "thunder":
		var extra_thunder := 0
		for key in _fighters.keys():
			var kato: Fighter = _fighters[key]
			if kato.enemy != actor.enemy or kato.sheet_id != 23:
				continue
			if not _is_backline(kato) or kato.hp <= 0:
				continue
			if int(kato.kit.get("gem_left", 0)) <= 0:
				continue
			kato.kit["gem_left"] = int(kato.kit.get("gem_left", 0)) - 1
			extra_thunder += 1
		if extra_thunder > 0:
			for foe in _era2_smallest_id(actor, primary, extra_thunder, out):
				if not out.has(foe):
					out.append(foe)
	if actor.element == "wind":
		var death_extra := 0
		for key in _fighters.keys():
			var kawai: Fighter = _fighters[key]
			if kawai.enemy != actor.enemy or kawai.sheet_id != 25:
				continue
			if int(kawai.kit.get("death_splash_left", 0)) <= 0:
				continue
			kawai.kit["death_splash_left"] = int(kawai.kit.get("death_splash_left", 0)) - 1
			death_extra += 1
		if death_extra > 0:
			for foe in _era2_smallest_id(actor, primary, death_extra, out):
				if not out.has(foe):
					out.append(foe)
		var kawai_live := _best_sheet(actor.enemy, 25)
		if kawai_live != null and _is_backline(kawai_live) and kawai_live.hp > 0:
			var side := _era2_lane_neighbor(primary)
			if side != null and side != primary and not out.has(side):
				out.append(side)
				side.kit["force_target_id"] = kawai_live.unit.get_instance_id()
	if actor.element == "ice":
		var gose := _best_sheet(actor.enemy, 34)
		if gose != null and _is_backline(gose) and gose.hp > 0 and int(gose.kit.get("ice_forced_left", 0)) > 0:
			gose.kit["ice_forced_left"] = 0
			var focus := primary
			for entry in out:
				var foe: Fighter = entry
				if foe.defense > focus.defense or (is_equal_approx(foe.defense, focus.defense) and foe.unit.unit_id < focus.unit.unit_id):
					focus = foe
			actor.kit["forced_crit_damage_bonus"] = float(gose.kit.get("forced_crit_damage", 0.0))
			actor.kit["force_crit_target_id"] = focus.unit.get_instance_id()
	return out


func _era2_kit_bonus(attacker: Fighter, defender: Fighter, is_dot: bool) -> float:
	var bonus := 0.0
	if is_dot:
		return bonus
	bonus += float(attacker.kit.get("sakai_damage_bonus", 0.0))
	if attacker.sheet_id == 21 and int(attacker.kit.get("synth_left", 0)) > 0 and attacker.element == "earth" and bool(attacker.kit.get("splash_resolving", false)):
		var layers := mini(int(defender.layers.get("earth", 0)), maxi(1, int(attacker.kit.get("layer_cap", 3))))
		bonus += float(attacker.kit.get("layer_splash", 0.0)) * float(layers)
	if attacker.sheet_id == 21 and int(attacker.kit.get("synth_left", 0)) > 0 and attacker.element == "earth":
		bonus += float(attacker.kit.get("earth_empower", 0.0))
	if attacker.sheet_id == 26 and int(attacker.kit.get("synth_left", 0)) > 0 and attacker.element == "wind":
		bonus += float(attacker.kit.get("wind_self", 0.0))
	if attacker.element == "wind" and bool(attacker.kit.get("kanzaki_empowered", false)):
		bonus += float(attacker.kit.get("kanzaki_wind_bonus", 0.0))
	if attacker.sheet_id == 29 and bool(attacker.kit.get("absorb_burst", false)):
		bonus += float(attacker.kit.get("absorb_empower", 0.0))
	if attacker.sheet_id == 36 and bool(attacker.kit.get("summon_strike", false)):
		bonus += float(attacker.kit.get("summon_water", 0.0))
	return bonus


func _era2_side_crit(attacker: Fighter) -> float:
	return float(attacker.kit.get("sakai_side_crit", 0.0))


func _era2_on_damage_dealt(actor: Fighter, target: Fighter, dealt: int) -> void:
	if actor.sheet_id == 21 and actor.element == "earth" and int(actor.kit.get("synth_left", 0)) > 0 and dealt > 0:
		actor.kit["synth_left"] = int(actor.kit.get("synth_left", 0)) - 1
		actor.kit["priority_cut_active"] = int(actor.kit.get("priority_cut", 0))
		_persist_synth_left(actor)
	if actor.element == "wind" and bool(actor.kit.get("kanzaki_empowered", false)) and dealt > 0:
		actor.kit["kanzaki_empowered"] = false
		var source := _fighter_by_id(int(actor.kit.get("kanzaki_source_id", -1)))
		if source != null and source.sheet_id == 26:
			if not bool(source.kit.get("gem_locked", false)):
				source.kit["synth_left"] = maxi(0, int(source.kit.get("synth_left", 0)) - 1)
				_persist_synth_left(source)
			var gain := float(source.kit.get("resist_gain", 0.0))
			var cap := float(source.kit.get("resist_cap", 0.0))
			var now := float(source.kit.get("resist_gained", 0.0))
			var add := minf(gain, maxf(0.0, cap - now))
			source.kit["resist_gained"] = now + add
			source.attribute_resist += add
	if actor.sheet_id == 33 and actor.element == "water" and dealt > 0 and target.alive and target.hp > 0:
		if not bool(target.kit.get("gojo_marked", false)):
			target.kit["gojo_marked"] = true
			target.kit["mark_taken_active"] = float(actor.kit.get("mark_taken", 0.0))
	if actor.sheet_id == 20 and actor.element == "earth" and target.stand_slot >= BoardController.FRONT_COUNT:
		_kashiba_column_follow(actor, target)
	_era2_arm_kanzaki_wind(actor)


func _era2_arm_kanzaki_wind(actor: Fighter) -> void:
	if actor.element != "wind":
		return
	var best := _best_sheet(actor.enemy, 26)
	if best == null or int(best.kit.get("synth_left", 0)) <= 0:
		return
	actor.kit["kanzaki_empowered"] = true
	actor.kit["kanzaki_wind_bonus"] = float(best.kit.get("wind_empower", 0.0))
	actor.kit["kanzaki_source_id"] = best.unit.get_instance_id()


func _era2_on_targeted(actor: Fighter, target: Fighter) -> void:
	if target.sheet_id == 24 and target.hp > 0:
		if not bool(actor.kit.get("kadoma_resisted", false)):
			actor.kit["kadoma_resisted"] = true
			actor.attribute_resist -= float(target.kit.get("attacker_resist_cut", 0.0))
	if target.sheet_id == 30 and target.hp > 0:
		target.kit["hit_crit_stacks"] = float(target.kit.get("hit_crit_stacks", 0.0)) + float(target.kit.get("hit_crit", 0.0))
		if not bool(target.kit.get("first_resist_done", false)):
			target.kit["first_resist_done"] = true
			target.attribute_resist += float(target.kit.get("first_resist", 0.0))
			target.kit["hit_speed_bonus"] = int(target.kit.get("hit_speed", 0))


func _era2_on_death(dead: Fighter) -> void:
	_naura_on_death(dead)
	_nose_clear_mark_on_death(dead)
	if dead.sheet_id == 68:
		dead.kit["nishimino_double_armed"] = false
		dead.kit["nishimino_pending_second"] = false
		if is_instance_valid(dead.unit):
			dead.unit.kit_flags["nishimino_double_armed"] = false
	if dead.sheet_id == 19:
		var best := _best_sheet(dead.enemy, 19)
		if best == dead:
			dead.kit["kakogawa_left"] = int(dead.kit.get("kakogawa_left", 0)) + 1
	if dead.sheet_id == 25 and _is_backline(dead):
		dead.kit["death_splash_left"] = int(dead.kit.get("death_extra", 1))
	if dead.sheet_id == 27:
		await _kitazawa_death_burst(dead)
	if dead.sheet_id == 31 and _is_backline(dead):
		_kuwana_death_copy(dead)
	if bool(dead.kit.get("gojo_marked", false)):
		_gojo_transfer_mark(dead)


func _era2_after_turn(actor: Fighter, _was_buff: bool) -> void:
	if actor.sheet_id == 21 and int(actor.kit.get("priority_cut_active", 0)) > 0:
		actor.kit["priority_cut_active"] = 0
	await _kudoyama_on_ally_act(actor)
	_kinomoto_on_ap_tick(actor)
	if actor.enemy and int(actor.layers.get("water", 0)) > 0:
		await _sakurai_summon(actor)


func _kadoma_maybe_redirect(actor: Fighter, picked: Fighter) -> Fighter:
	if picked == null or actor.enemy == picked.enemy:
		return picked
	var kadoma := _best_sheet(picked.enemy, 24)
	if kadoma == null or kadoma.hp <= 0 or bool(kadoma.kit.get("redirect_used", false)):
		return picked
	if picked == kadoma:
		return picked
	if _threat(picked) >= _threat(kadoma):
		return picked
	kadoma.kit["redirect_used"] = true
	kadoma.kit["redirect_taken_cut_active"] = float(kadoma.kit.get("redirect_taken_cut", 0.0))
	_host._log("%s が攻撃を引き受けた" % kadoma.unit.get_display_name())
	return kadoma


func _kouryo_facing_target(actor: Fighter) -> Fighter:
	var slot := actor.stand_slot
	if slot < 0 or slot >= BoardController.FRONT_COUNT:
		return null
	var matched: Fighter = null
	var smallest: Fighter = null
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if not foe.alive or foe.hp <= 0 or foe.stand_slot < 0 or foe.stand_slot >= BoardController.FRONT_COUNT:
			continue
		if smallest == null or foe.unit.unit_id < smallest.unit.unit_id:
			smallest = foe
		if foe.stand_slot == slot:
			matched = foe
	return matched if matched != null else smallest


func _kashiba_column_follow(actor: Fighter, back_target: Fighter) -> void:
	if back_target.stand_slot < BoardController.FRONT_COUNT:
		return
	var best := _best_sheet(actor.enemy, 20)
	if best == null or best != actor:
		return
	var col := back_target.stand_slot - BoardController.FRONT_COUNT
	var fronts: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe.stand_slot == col and foe.alive and foe.hp > 0:
			fronts.append(foe)
	fronts.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		if _threat(a) != _threat(b):
			return _threat(a) > _threat(b)
		return a.unit.unit_id < b.unit.unit_id
	)
	var limit := maxi(1, int(actor.kit.get("column_hits", 1)))
	var hit := 0
	for entry in fronts:
		if hit >= limit:
			break
		var front: Fighter = entry
		front.kit["skip_next_action"] = true
		hit += 1


func _kitazawa_death_burst(dead: Fighter) -> void:
	var target: Fighter = null
	for entry in _opponents(dead):
		var foe: Fighter = entry
		if foe.alive and foe.hp > 0 and float(foe.kit.get("received_fire_resist", 0.0)) < 0.0:
			target = foe
			break
	if target == null:
		target = _extreme(_opponents(dead), "threat", true)
	if target == null or not target.alive:
		return
	var count := _synergy_member_count(dead.enemy, "にぎやかな未来")
	var layers := 40
	if count >= 6:
		layers = 13
	elif count >= 4:
		layers = 20
	_add_layers(target, "fire", layers)
	await _apply_dot(dead, target)


func _kuwana_death_copy(dead: Fighter) -> void:
	var source: Fighter = null
	var dest: Fighter = null
	for entry in _opponents(dead):
		var foe: Fighter = entry
		if not foe.alive or foe.hp <= 0:
			continue
		var layers := int(foe.layers.get("water", 0))
		if layers > 0 and (source == null or layers > int(source.layers.get("water", 0)) or (layers == int(source.layers.get("water", 0)) and foe.unit.unit_id < source.unit.unit_id)):
			source = foe
		if layers <= 0 and (dest == null or foe.unit.unit_id < dest.unit.unit_id):
			dest = foe
	if source == null or dest == null:
		return
	var copy := mini(int(source.layers.get("water", 0)), maxi(1, int(dead.kit.get("death_copy", 2))))
	_add_layers(dest, "water", copy)


func _gojo_has_mark(enemy_side: bool) -> bool:
	for key in _fighters.keys():
		var foe: Fighter = _fighters[key]
		if foe.enemy == enemy_side and foe.alive and foe.hp > 0 and bool(foe.kit.get("gojo_marked", false)):
			return true
	return false


func _gojo_transfer_mark(dead: Fighter) -> void:
	var gojo := _best_sheet(not dead.enemy, 33)
	if gojo == null or int(gojo.kit.get("mark_moves_left", 0)) <= 0:
		dead.kit["gojo_marked"] = false
		dead.kit["mark_taken_active"] = 0.0
		return
	var dest: Fighter = null
	for entry in _side(dead.enemy):
		var foe: Fighter = entry
		if foe == dead or not foe.alive or foe.hp <= 0 or bool(foe.kit.get("gojo_marked", false)):
			continue
		if dest == null or foe.hp > dest.hp or (foe.hp == dest.hp and foe.unit.unit_id < dest.unit.unit_id):
			dest = foe
	var amount := float(dead.kit.get("mark_taken_active", 0.0))
	dead.kit["gojo_marked"] = false
	dead.kit["mark_taken_active"] = 0.0
	if dest == null:
		return
	gojo.kit["mark_moves_left"] = int(gojo.kit.get("mark_moves_left", 0)) - 1
	dest.kit["gojo_marked"] = true
	dest.kit["mark_taken_active"] = amount


func _kudoyama_on_ally_act(actor: Fighter) -> void:
	for key in _fighters.keys():
		var kudo: Fighter = _fighters[key]
		if kudo.sheet_id != 29 or kudo.enemy != actor.enemy or kudo.hp <= 0:
			continue
		var gain := 0
		if _is_backline(kudo):
			if actor == kudo or _is_backline(actor):
				continue
			gain = 12
		else:
			if actor != kudo or actor.element != "absorb":
				continue
			gain = 12
		if gain <= 0:
			continue
		kudo.kit["gauge"] = mini(100, int(kudo.kit.get("gauge", 0)) + gain)
		_show_gauge(kudo)
		if int(kudo.kit.get("gauge", 0)) >= 100:
			kudo.kit["gauge"] = 0
			_show_gauge(kudo)
			if _is_backline(kudo):
				await _kudoyama_burst(kudo)


func _kudoyama_burst(kudo: Fighter) -> void:
	var target := _extreme(_opponents(kudo), "threat", true)
	if target == null:
		return
	kudo.kit["absorb_burst"] = true
	await _resolve_packet(kudo, target, true, false, false)
	kudo.kit["absorb_burst"] = false


func _kinomoto_on_ap_tick(actor: Fighter) -> void:
	for key in _fighters.keys():
		var kino: Fighter = _fighters[key]
		if kino.sheet_id != 28 or kino.enemy != actor.enemy or kino.hp <= 0:
			continue
		if actor == kino:
			continue
		kino.kit["gauge"] = mini(100, int(kino.kit.get("gauge", 0)) + 10)
		_show_gauge(kino)
		if int(kino.kit.get("gauge", 0)) >= 100:
			kino.kit["gauge"] = 0
			_show_gauge(kino)
			_kinomoto_copy(kino)


func _kinomoto_copy(kino: Fighter) -> void:
	var source: Fighter = null
	for entry in _opponents(kino):
		var foe: Fighter = entry
		if not foe.alive or foe.hp <= 0:
			continue
		var layers := int(foe.layers.get("water", 0))
		if layers <= 0:
			continue
		if source == null or layers > int(source.layers.get("water", 0)) or (layers == int(source.layers.get("water", 0)) and foe.unit.unit_id < source.unit.unit_id):
			source = foe
	if source == null:
		var fallback := _extreme(_opponents(kino), "threat", true)
		if fallback != null:
			_add_layers(fallback, "water", maxi(1, int(kino.kit.get("fallback_layers", 1))))
		return
	var dest: Fighter = null
	for entry in _opponents(kino):
		var foe: Fighter = entry
		if foe == source or not foe.alive or foe.hp <= 0:
			continue
		var layers := int(foe.layers.get("water", 0))
		if dest == null or layers < int(dest.layers.get("water", 0)) or (layers == int(dest.layers.get("water", 0)) and foe.unit.unit_id < dest.unit.unit_id):
			dest = foe
	if dest == null:
		return
	var copy := mini(int(source.layers.get("water", 0)), maxi(1, int(kino.kit.get("copy_layers", 1))))
	_add_layers(dest, "water", copy)
	source.kit["force_guard_next"] = true


func _sakurai_summon(acted: Fighter) -> void:
	var sakurai := _best_sheet(not acted.enemy, 36)
	if sakurai == null or sakurai.hp <= 0 or int(sakurai.kit.get("summon_left", 0)) <= 0:
		return
	var target := _era2_lane_neighbor(acted)
	if target == null:
		target = acted
	if target == null or not target.alive or target.hp <= 0:
		return
	sakurai.kit["summon_left"] = int(sakurai.kit.get("summon_left", 0)) - 1
	var power_src := _extreme(_side(sakurai.enemy), "attack", true)
	var power := power_src.attack if power_src != null else sakurai.attack
	sakurai.kit["summon_strike"] = true
	var saved_element := sakurai.element
	var saved_crit := sakurai.crit_damage
	sakurai.element = "water"
	sakurai.crit_damage += float(sakurai.kit.get("summon_crit_damage", 0.0)) / 100.0
	var bonus := _kit_bonus(sakurai, target, false)
	var rolled := _roll_damage(sakurai, target, true, bonus, power)
	var dealt := _mitigate(target, int(rolled["amount"]))
	_apply_damage(target, dealt)
	_add_layers(target, "water", 1)
	sakurai.element = saved_element
	sakurai.crit_damage = saved_crit
	sakurai.kit["summon_strike"] = false
	if is_instance_valid(target.unit) and dealt > 0:
		target.unit.popup_battle_text("-%d" % dealt, Color(0.45, 0.85, 1.0))
		_host._log("%s の召喚が %s に %d" % [sakurai.unit.get_display_name(), target.unit.get_display_name(), dealt])


func _refresh_sakai_aura() -> void:
	var touched: Array = []
	for key in _fighters.keys():
		var ally: Fighter = _fighters[key]
		ally.kit["sakai_damage_bonus"] = 0.0
		ally.kit["sakai_side_crit"] = 0.0
		if int(ally.kit.get("sakai_speed_bonus", 0)) != 0:
			ally.kit["sakai_speed_bonus"] = 0
			touched.append(ally)
	for key in _fighters.keys():
		var sakai: Fighter = _fighters[key]
		if sakai.sheet_id != 35 or not _is_backline(sakai) or sakai.hp <= 0:
			continue
		var ally_bonus := float(sakai.kit.get("ally_damage", 0.0)) + float(sakai.kit.get("synth_bonus", 0.0))
		var side_bonus := float(sakai.kit.get("side_damage", 0.0))
		var relic_n := mini(int(sakai.kit.get("start_relics", 0)), maxi(1, int(sakai.kit.get("relic_count_cap", 1))))
		side_bonus += float(sakai.kit.get("relic_damage", 0.0)) * float(relic_n)
		var side_crit := float(sakai.kit.get("side_crit", 0.0))
		var speed_bonus := int(sakai.kit.get("swing_speed_bonus", 0))
		for ally in _side(sakai.enemy):
			if ally == sakai or not ally.alive:
				continue
			ally.kit["sakai_damage_bonus"] = float(ally.kit.get("sakai_damage_bonus", 0.0)) + ally_bonus
			if absi(ally.stand_slot - sakai.stand_slot) == 1 and _is_backline(ally):
				ally.kit["sakai_damage_bonus"] = float(ally.kit.get("sakai_damage_bonus", 0.0)) + side_bonus
				ally.kit["sakai_side_crit"] = float(ally.kit.get("sakai_side_crit", 0.0)) + side_crit
				if speed_bonus > 0:
					ally.kit["sakai_speed_bonus"] = int(ally.kit.get("sakai_speed_bonus", 0)) + speed_bonus
					if not touched.has(ally):
						touched.append(ally)
	for entry in touched:
		_recompute_speed(entry as Fighter, true)


func _era2_lowest_defense(actor: Fighter, primary: Fighter, count: int, blocked: Array) -> Array:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == primary or blocked.has(foe) or not foe.alive:
			continue
		pool.append(foe)
	pool.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		if not is_equal_approx(a.defense, b.defense):
			return a.defense < b.defense
		return a.unit.unit_id < b.unit.unit_id
	)
	var chosen: Array = []
	for entry in pool:
		if chosen.size() >= count:
			break
		chosen.append(entry)
	return chosen


func _era2_smallest_id(actor: Fighter, primary: Fighter, count: int, blocked: Array) -> Array:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == primary or blocked.has(foe) or not foe.alive:
			continue
		pool.append(foe)
	pool.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	var chosen: Array = []
	for entry in pool:
		if chosen.size() >= count:
			break
		chosen.append(entry)
	return chosen


func _era2_lane_neighbor(unit: Fighter) -> Fighter:
	if unit == null or unit.stand_slot < 0:
		return null
	var front := unit.stand_slot < BoardController.FRONT_COUNT
	var base := 0 if front else BoardController.FRONT_COUNT
	var local := unit.stand_slot - base
	var candidates: Array = []
	for delta in [-1, 1]:
		var slot: int = base + local + int(delta)
		if slot < base or slot >= base + BoardController.FRONT_COUNT:
			continue
		for entry in _side(unit.enemy):
			var foe: Fighter = entry
			if foe.stand_slot == slot and foe.alive and foe.hp > 0:
				candidates.append(foe)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	return candidates[0]


func _persist_synth_left(fighter: Fighter) -> void:
	if fighter == null or not is_instance_valid(fighter.unit):
		return
	fighter.unit.kit_flags["synth_charges"] = int(fighter.kit.get("synth_left", 0))


func _era3_battle_start_sync() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.alive or fighter.hp <= 0:
			continue
		if fighter.sheet_id == 48 and not _is_backline(fighter):
			fighter.kit["sosaki_self_thunder"] = float(fighter.kit.get("self_thunder", 0.0))
			var col := fighter.stand_slot
			for ally in _side(fighter.enemy):
				var other: Fighter = ally
				if other == fighter or not other.alive or other.hp <= 0:
					continue
				if other.stand_slot == col + BoardController.FRONT_COUNT:
					other.kit["sosaki_column_thunder"] = float(other.kit.get("sosaki_column_thunder", 0.0)) + float(fighter.kit.get("column_thunder", 0.0))
					other.kit["sosaki_column_source"] = fighter.unit.get_instance_id()
					fighter.kit["sosaki_column_ally"] = other.unit.get_instance_id()
		if fighter.sheet_id == 49:
			var gain := int(round(float(fighter.max_hp) * float(fighter.kit.get("start_hp_ratio", 0.2))))
			if gain > 0:
				fighter.max_hp += gain
				fighter.hp = fighter.max_hp
				if is_instance_valid(fighter.unit):
					fighter.unit.set_battle_hp(fighter.hp, fighter.max_hp)
		if fighter.sheet_id == 50:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
			var foe := _extreme(_opponents(fighter), "threat", true)
			if foe != null and foe.alive:
				_add_layers(foe, "fire", maxi(1, int(fighter.kit.get("start_layers", 3))))
				fighter.kit["daito_opening_dot"] = foe.unit.get_instance_id()
		if fighter.sheet_id in [51, 52]:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 54:
			fighter.kit["gauge"] = 0
			_show_gauge(fighter)


func _nigiyaka_dot_ratio(enemy: bool) -> float:
	var count := _synergy_member_count(enemy, "にぎやかな未来")
	if count >= 6:
		return 0.15
	if count >= 4:
		return 0.10
	return 0.05


func _lagosu_splash_count(actor: Fighter) -> int:
	if not _has_synergy(actor, "旅のラゴス") and actor.sheet_id != 48:
		return 1
	var count := _synergy_member_count(actor.enemy, "旅のラゴス")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _signal_noise_splash_count(actor: Fighter) -> int:
	if not _has_synergy(actor, "シグナル・ノイズ") and actor.sheet_id != 54:
		return 1
	var count := _synergy_member_count(actor.enemy, "シグナル・ノイズ")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _sosaki_extras(actor: Fighter, primary: Fighter, need: int) -> Array:
	var chosen: Array = []
	var ally := _fighter_by_id(int(actor.kit.get("sosaki_column_ally", -1)))
	if ally != null and ally.alive:
		var remembered := _fighter_by_id(int(ally.kit.get("last_attack_target_id", -1)))
		if remembered != null and remembered.alive and remembered.hp > 0 and remembered != primary and remembered.enemy != actor.enemy:
			chosen.append(remembered)
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe != primary and not chosen.has(foe):
			pool.append(foe)
	pool.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	for entry in pool:
		if chosen.size() >= need:
			break
		chosen.append(entry)
	return chosen


func _sosaki_front_buff(actor: Fighter) -> void:
	_clear_sosaki_front_buffs(actor)
	var amount := float(actor.kit.get("buff_amount", 0.0))
	var ids: Array = []
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0 or _is_backline(ally):
			continue
		await _play_status_transfer(actor.unit, ally.unit, true)
		_apply_buff_value(ally, "front_taken_cut", amount)
		_refresh_unit_aura(ally.unit)
		ally.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
		ids.append(ally.unit.get_instance_id())
		_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally.unit.get_display_name(), _describe_effect("front_taken_cut", amount)])
	actor.kit["sosaki_buff_ids"] = ids
	actor.kit["sosaki_buff_amount"] = amount


func _clear_sosaki_front_buffs(actor: Fighter) -> void:
	var amount := float(actor.kit.get("sosaki_buff_amount", 0.0))
	for entry in actor.kit.get("sosaki_buff_ids", []):
		var ally := _fighter_by_id(int(entry))
		if ally != null:
			_apply_buff_value(ally, "front_taken_cut", -amount)
			_refresh_unit_aura(ally.unit)
	actor.kit["sosaki_buff_ids"] = []
	actor.kit["sosaki_buff_amount"] = 0.0


func _taishi_on_targeted(actor: Fighter, target: Fighter) -> void:
	if target == null or target.sheet_id != 49 or not target.alive:
		return
	if actor == null or actor.enemy == target.enemy:
		return
	target.kit["last_hitter_id"] = actor.unit.get_instance_id() if is_instance_valid(actor.unit) else -1
	var delay := maxi(1, int(target.kit.get("ap_delay", 40)))
	actor.kit["pending_ap_delay"] = int(actor.kit.get("pending_ap_delay", 0)) + delay
	_host._log("%s の次の行動が遅れる（+%d）" % [actor.unit.get_display_name(), delay])


func _era3_on_ally_action(actor: Fighter, was_buff: bool) -> void:
	var delay := int(actor.kit.get("pending_ap_delay", 0))
	if delay > 0:
		actor.ap += delay
		actor.kit["pending_ap_delay"] = 0
		if is_instance_valid(actor.unit):
			actor.unit.action_value = actor.ap
	var greek := _greek_gauge_step(actor.enemy)
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0:
			continue
		if ally.sheet_id == 50:
			_daito_add_gauge(ally, greek)
		if ally.sheet_id == 52:
			_tatsuno_add_gauge(ally, greek, false)
	if actor.sheet_id == 51 and actor.alive and actor.hp > 0:
		var gain := _pandora_gauge_step(actor.enemy)
		if not was_buff and bool(actor.kit.get("did_attack", false)):
			gain += _soar_bridge_gauge_step(actor.enemy)
		_takatsuki_add_gauge(actor, gain)
	if actor.sheet_id == 54 and actor.alive and actor.hp > 0:
		_tarumi_on_ap_loss(actor, false)


func _pandora_gauge_step(enemy: bool) -> int:
	var thresholds: Array[int] = [2, 4, 6, 8]
	var values: Array[int] = [12, 14, 16, 18]
	return _gauge_step_table(_synergy_member_count(enemy, "パンドラ・オートロード"), thresholds, values, 10)


func _daito_add_gauge(daito: Fighter, step: int) -> void:
	if daito == null or not daito.alive or daito.hp <= 0 or step <= 0:
		return
	var gauge := int(daito.kit.get("gauge", 0)) + _scaled_gauge(daito, step)
	GameAudio.play_battle_gauge()
	if gauge < 100:
		daito.kit["gauge"] = gauge
		_daito_refresh_gauge_fire(daito)
		_show_gauge(daito)
		return
	daito.kit["gauge"] = 0
	_daito_refresh_gauge_fire(daito)
	_show_gauge(daito)
	var gain := float(daito.kit.get("interest_gain", 0.3))
	var cap := float(daito.kit.get("interest_cap", 0.6))
	if _host != null and _host.session != null:
		var now := float(_host.session.next_interest_bonus)
		_host.session.next_interest_bonus = minf(cap, now + gain)
	daito.kit["interest_layer_armed"] = true
	if is_instance_valid(daito.unit):
		daito.unit.popup_battle_text("利息", Color(1.0, 0.75, 0.3))
	_host._log("%s のゲージが満ち、次の利息が増える" % daito.unit.get_display_name())


func _daito_refresh_gauge_fire(daito: Fighter) -> void:
	if int(daito.kit.get("gauge", 0)) >= 50:
		daito.kit["daito_gauge_fire"] = float(daito.kit.get("gauge_fire", 0.0))
	else:
		daito.kit["daito_gauge_fire"] = 0.0


func _daito_after_attack(daito: Fighter) -> void:
	if not bool(daito.kit.get("interest_layer_armed", false)):
		return
	# layers added via nigiyaka on attack elsewhere; add bonus layers here on next attack after arming, not fill attack
	pass


func _takatsuki_add_gauge(fighter: Fighter, step: int) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or step <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + _scaled_gauge(fighter, step)
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	fighter.kit["aoe_debuff_armed"] = true
	fighter.kit["extra_ice_armed"] = true
	_show_gauge(fighter)
	if is_instance_valid(fighter.unit):
		fighter.unit.popup_battle_text("全体", Color(0.55, 0.85, 1.0))
	_host._log("%s のゲージが満ち、次のデバフと氷攻撃が強化される" % fighter.unit.get_display_name())


func _takatsuki_aoe_debuff(actor: Fighter, kind: String) -> void:
	var amount := float(actor.kit.get("buff_amount", 0.0))
	# clear previous multi
	_clear_takatsuki_debuffs(actor)
	var ids: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if not foe.alive or foe.hp <= 0:
			continue
		await _play_status_transfer(actor.unit, foe.unit, false)
		_apply_buff_value(foe, kind, amount)
		_refresh_unit_aura(foe.unit)
		foe.unit.popup_battle_text("デバフ", Color(0.82, 0.55, 1.0))
		ids.append(foe.unit.get_instance_id())
		if actor.enemy and not foe.enemy:
			_host.board.mark_debuffed_unit(foe.unit)
	actor.kit["debuffs"] = []
	for tid in ids:
		actor.kit["debuffs"].append({"target_id": tid, "kind": kind, "amount": amount})
	_host._log("%s のデバフが敵全体に入った" % actor.unit.get_display_name())


func _clear_takatsuki_debuffs(actor: Fighter) -> void:
	for entry in actor.kit.get("debuffs", []):
		var item: Dictionary = entry
		var old := _fighter_by_id(int(item.get("target_id", -1)))
		if old != null:
			_apply_buff_value(old, str(item.get("kind", "")), -float(item.get("amount", 0.0)))
			_refresh_unit_aura(old.unit)
	actor.kit["debuffs"] = []


func _takatsuki_extra_targets(actor: Fighter, primary: Fighter, need: int) -> Array:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe != primary and foe.alive:
			pool.append(foe)
	pool.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		if a.hp != b.hp:
			return a.hp > b.hp
		return a.unit.unit_id < b.unit.unit_id
	)
	var chosen: Array = []
	for entry in pool:
		if chosen.size() >= need:
			break
		chosen.append(entry)
	return chosen


func _tatsuno_add_gauge(tatsuno: Fighter, step: int, from_crit: bool) -> void:
	if tatsuno == null or not tatsuno.alive or tatsuno.hp <= 0:
		return
	var gain := step
	if from_crit:
		gain = maxi(1, int(tatsuno.kit.get("crit_gauge", 4)))
	if gain <= 0:
		return
	var gauge := int(tatsuno.kit.get("gauge", 0)) + (gain if from_crit else _scaled_gauge(tatsuno, gain))
	GameAudio.play_battle_gauge()
	if gauge < 100:
		tatsuno.kit["gauge"] = gauge
		_show_gauge(tatsuno)
		return
	tatsuno.kit["gauge"] = 0
	tatsuno.kit["tatsuno_break_armed"] = true
	tatsuno.kit["break_extra_pending"] = maxi(1, int(tatsuno.kit.get("break_extra", 1)))
	_show_gauge(tatsuno)
	if is_instance_valid(tatsuno.unit):
		tatsuno.unit.popup_battle_text("撃破+", Color(0.45, 0.8, 1.0))
	_host._log("%s のゲージが満ち、次の水クリで撃破が多く減る" % tatsuno.unit.get_display_name())


func _era3_on_crit(attacker: Fighter) -> void:
	if attacker == null or not bool(attacker.kit.get("last_roll_crit", false)):
		return
	for entry in _side(attacker.enemy):
		var ally: Fighter = entry
		if ally.sheet_id == 52 and ally.alive and ally.hp > 0:
			_tatsuno_add_gauge(ally, 0, true)
	_touin_on_crit(attacker)


func _tanabe_best(enemy_side: bool) -> Fighter:
	return _best_sheet(enemy_side, 53)


func _tanabe_block_enemy_buff(buffer: Fighter, target: Fighter) -> bool:
	if buffer == null or target == null or buffer.enemy != target.enemy:
		return false
	if buffer == target:
		return false
	var tanabe := _tanabe_best(not buffer.enemy)
	if tanabe == null or not _is_backline(tanabe) or tanabe.hp <= 0:
		return false
	var left := int(tanabe.kit.get("cleanse_left", 0))
	if left <= 0:
		return false
	tanabe.kit["cleanse_left"] = left - 1
	target.kit["tanabe_marked"] = true
	target.kit["tanabe_mark_order"] = int(tanabe.kit.get("mark_seq", 0)) + 1
	tanabe.kit["mark_seq"] = int(target.kit.get("tanabe_mark_order", 0))
	# reduce earth break one step
	var br := int(target.break_left.get("earth", BREAK_MAX))
	if br > 0:
		target.break_left["earth"] = br - BREAK_STEP
		_sync_break_gauge(target, "earth", int(target.break_left["earth"]) <= 0)
	var ally := _extreme(_side(tanabe.enemy), "hp", false)
	if ally != null:
		ally.kit["next_taken_cut_active"] = float(tanabe.kit.get("ally_taken_cut", 0.0))
	if is_instance_valid(target.unit):
		target.unit.popup_battle_text("バフ無効", Color(1.0, 0.7, 0.35))
	return true


func _tanabe_marked_target(actor: Fighter) -> Fighter:
	var tanabe := _tanabe_best(actor.enemy)
	if tanabe == null or not _is_backline(tanabe) or tanabe.hp <= 0:
		return null
	var chosen: Fighter = null
	var best_order := -1
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if not bool(foe.kit.get("tanabe_marked", false)):
			continue
		if _is_backline(foe) or not foe.alive or foe.hp <= 0:
			continue
		var order := int(foe.kit.get("tanabe_mark_order", 0))
		if chosen == null or order > best_order:
			chosen = foe
			best_order = order
	return chosen


func _tanabe_buff_target(actor: Fighter, backline: bool) -> Fighter:
	var pool: Array = []
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0:
			continue
		if backline and ally == actor:
			continue
		pool.append(ally)
	if pool.is_empty():
		return actor
	return _extreme(pool, "attack", true)


func _refresh_tanabe_back_buff() -> void:
	for key in _fighters.keys():
		var tanabe: Fighter = _fighters[key]
		if tanabe.sheet_id != 53 or not tanabe.alive:
			continue
		if _is_backline(tanabe) and tanabe.hp > 0:
			tanabe.kit["never_acts"] = true
			tanabe.in_queue = false
			tanabe.kit["front_buff_active"] = false
			var target := _tanabe_buff_target(tanabe, true)
			_set_single_buff(tanabe, target, "highest_attack_earth", float(tanabe.kit.get("buff_amount", 0.0)))
		else:
			tanabe.kit["never_acts"] = false
			if int(tanabe.kit.get("buff_target_id", -1)) >= 0 and not bool(tanabe.kit.get("front_buff_active", false)):
				_clear_single_buff(tanabe)


func _tarumi_on_ap_loss(tarumi: Fighter, from_iced_enemy: bool) -> void:
	if tarumi == null or not tarumi.alive or tarumi.hp <= 0:
		return
	var step := _pop_music_gauge_step(tarumi.enemy)
	var gain := step * (2 if from_iced_enemy else 1)
	var gauge := int(tarumi.kit.get("gauge", 0)) + _scaled_gauge(tarumi, gain)
	GameAudio.play_battle_gauge()
	if gauge < 100:
		tarumi.kit["gauge"] = gauge
		_show_gauge(tarumi)
		return
	tarumi.kit["gauge"] = 0
	tarumi.kit["tarumi_full_aoe"] = true
	_show_gauge(tarumi)
	if is_instance_valid(tarumi.unit):
		tarumi.unit.popup_battle_text("範囲", Color(0.55, 0.85, 1.0))
	_host._log("%s のゲージが満ち、氷層のある敵すべてに範囲が入る" % tarumi.unit.get_display_name())


func _tarumi_ice_targets(actor: Fighter, primary: Fighter) -> Array:
	var chosen: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == primary:
			continue
		if int(foe.layers.get("ice", 0)) > 0 and foe.alive and foe.hp > 0:
			chosen.append(foe)
	return chosen


func _era3_after_ice_hit(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null:
		return
	if actor.sheet_id == 54 and actor.element == "ice" and _has_synergy(actor, "舟"):
		_add_layers(target, "ice", 1)
	if bool(actor.kit.get("tarumi_multi_hit", false)):
		return
	if bool(actor.kit.get("tarumi_aoe_resolving", false)) and actor.sheet_id == 54:
		var layers := int(target.layers.get("ice", 0))
		var cap := maxi(1, int(actor.kit.get("aoe_hits", 2)))
		var times := mini(layers, cap) if layers >= 2 else 1
		actor.kit["tarumi_multi_hit"] = true
		for _i in range(maxi(0, times - 1)):
			if not target.alive or target.hp <= 0:
				break
			await _resolve_packet(actor, target, false, true, false)
		actor.kit["tarumi_multi_hit"] = false


func _daito_opening_dots() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id != 50:
			continue
		var foe := _fighter_by_id(int(fighter.kit.get("daito_opening_dot", -1)))
		if foe == null or not foe.alive:
			continue
		fighter.kit["dot_ratio"] = _nigiyaka_dot_ratio(fighter.enemy)
		await _apply_dot(fighter, foe)


func _tarumi_on_other_ap_loss(tarumi: Fighter, actor: Fighter) -> void:
	if tarumi == null or tarumi.sheet_id != 54 or not tarumi.alive or tarumi.hp <= 0:
		return
	var iced := actor != null and actor.enemy != tarumi.enemy and int(actor.layers.get("ice", 0)) > 0
	_tarumi_on_ap_loss(tarumi, iced)


func _metamorph_dot_ratio(enemy: bool) -> float:
	var count := _synergy_member_count(enemy, "メタモルフォセス群島")
	if count >= 6:
		return 0.15
	if count >= 4:
		return 0.10
	return 0.05


func _backline_style_buff_target(actor: Fighter, exclude_self: bool) -> Fighter:
	var pool: Array = []
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0:
			continue
		if exclude_self and ally == actor:
			continue
		pool.append(ally)
	if pool.is_empty():
		return actor
	var kind := str(actor.kit.get("buff_kind", ""))
	if kind == "highest_crit_wind":
		return _extreme(pool, "crit_rate", true)
	return _extreme(pool, "attack", true)


func _refresh_era4_back_buffs() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 55:
			if _is_backline(fighter):
				fighter.kit["never_acts"] = true
				fighter.in_queue = false
				if int(fighter.kit.get("buff_target_id", -1)) >= 0:
					_clear_single_buff(fighter)
			elif fighter.alive and fighter.hp > 0:
				fighter.kit["never_acts"] = false
				var t55 := _extreme(_side(fighter.enemy), "attack", true)
				if t55 != null:
					_set_single_buff(fighter, t55, "highest_attack_thunder", float(fighter.kit.get("buff_amount", 0.0)))
		elif fighter.sheet_id == 56:
			if _is_backline(fighter):
				fighter.kit["never_acts"] = true
				fighter.in_queue = false
			else:
				fighter.kit["never_acts"] = false
			if fighter.alive and fighter.hp > 0:
				var t56 := _extreme(_side(fighter.enemy), "attack", true)
				if t56 != null:
					_set_single_buff(fighter, t56, "highest_attack_fire", float(fighter.kit.get("buff_amount", 0.0)))
		elif fighter.sheet_id == 58:
			if _is_backline(fighter) and fighter.hp > 0:
				fighter.kit["never_acts"] = true
				fighter.in_queue = false
				fighter.kit["front_buff_active"] = false
				var t58 := _backline_style_buff_target(fighter, false)
				_set_single_buff(fighter, t58, "highest_crit_wind", float(fighter.kit.get("buff_amount", 0.0)))
			else:
				fighter.kit["never_acts"] = false
				if int(fighter.kit.get("buff_target_id", -1)) >= 0 and not bool(fighter.kit.get("front_buff_active", false)):
					_clear_single_buff(fighter)
		elif fighter.sheet_id == 59:
			if _is_backline(fighter) and fighter.hp > 0:
				fighter.kit["never_acts"] = true
				fighter.in_queue = false
				fighter.kit["front_buff_active"] = false
				var t59 := _backline_style_buff_target(fighter, true)
				_set_single_buff(fighter, t59, "highest_attack_earth", float(fighter.kit.get("buff_amount", 0.0)))
			else:
				fighter.kit["never_acts"] = false
				if int(fighter.kit.get("buff_target_id", -1)) >= 0 and not bool(fighter.kit.get("front_buff_active", false)):
					_clear_single_buff(fighter)


func _tamba_best(enemy_side: bool) -> Fighter:
	return _best_sheet(enemy_side, 55)


func _tamba_maybe_redirect(actor: Fighter, _action: String) -> Fighter:
	var tamba := _tamba_best(not actor.enemy)
	if tamba == null or not _is_backline(tamba) or tamba.hp <= 0:
		return null
	if int(actor.layers.get("thunder", 0)) <= 0:
		return null
	var others := 0
	for entry in _side(actor.enemy):
		var foe: Fighter = entry
		if foe == actor or _is_backline(foe) or not foe.alive:
			continue
		if int(foe.layers.get("thunder", 0)) > 0:
			others += 1
	if others <= 0:
		return null
	if randi() % 10 >= 5:
		return null
	var best: Fighter = null
	var best_n := -1
	for entry2 in _side(actor.enemy):
		var f2: Fighter = entry2
		if f2 == actor or _is_backline(f2) or not f2.alive or f2.hp <= 0:
			continue
		var n := int(f2.layers.get("thunder", 0))
		if n <= 0:
			continue
		if best == null or n > best_n or (n == best_n and f2.unit.unit_id < best.unit.unit_id):
			best = f2
			best_n = n
	return best


func _tamba_proxy_guard(defender: Fighter) -> Fighter:
	if defender == null or not is_instance_valid(defender.unit):
		return null
	var did := defender.unit.get_instance_id()
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if int(fighter.kit.get("proxy_guard_for_id", -1)) != did:
			continue
		if fighter.alive and fighter.hp > 0 and fighter.guarding:
			fighter.kit["proxy_guard_for_id"] = -1
			return fighter
	return null


func _era4_battle_start_sync() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 57 and not _is_backline(fighter) and fighter.hp > 0:
			var foe := _extreme(_opponents(fighter), "threat", true)
			if foe != null:
				_add_layers(foe, "earth", maxi(1, int(fighter.kit.get("start_layers", 1))))
				_tsurugi_mark_persist(foe, fighter)
		if fighter.sheet_id == 61:
			_show_gauge(fighter)


func _era4_opening() -> void:
	var openers: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 61 and fighter.alive and fighter.hp > 0:
			openers.append(fighter)
	openers.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.unit_id < b.unit.unit_id
	)
	for entry in openers:
		await _torahime_opening_strike(entry as Fighter)


func _tsurugi_mark_persist(target: Fighter, tsurugi: Fighter) -> void:
	if target == null or tsurugi == null:
		return
	var cap := maxi(1, int(tsurugi.kit.get("persist_layers", 2)))
	var cur := int(target.layers.get("earth", 0))
	target.kit["tsurugi_persist_floor"] = mini(cap, cur)


func _era4_on_attack_contact(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null:
		return
	if actor.element == "earth" and actor.sheet_id == 57:
		_add_layers(target, "earth", 1)
		if int(actor.kit.get("first_earth_left", 0)) > 0 and not _is_backline(actor):
			actor.kit["first_earth_left"] = 0
			_add_layers(target, "earth", maxi(1, int(actor.kit.get("first_layers", 1))))
		if not _is_backline(actor) and actor.hp > 0:
			_tsurugi_mark_persist(target, actor)
	if actor.element == "fire":
		await _chihaya_on_fire_attack(actor, target)
	if actor.element == "wind":
		await _touin_on_wind_attack(actor, target)
	if actor.element == "earth":
		await _toba_on_earth_attack(actor, target)
	if actor.sheet_id == 61 and int(actor.kit.get("lock_left", 0)) > 0:
		if int(actor.kit.get("lock_target_id", -1)) == (target.unit.get_instance_id() if is_instance_valid(target.unit) else -2):
			actor.kit["lock_left"] = int(actor.kit.get("lock_left", 0)) - 1
	# consume next-attack buffs after a completed direct-style attack attempt
	if actor.element == "fire" and float(actor.kit.get("chihaya_next_fire", 0.0)) > 0.0 and bool(actor.kit.get("chihaya_consume_next", false)):
		actor.kit["chihaya_next_fire"] = 0.0
		actor.kit["chihaya_consume_next"] = false
	if actor.element == "wind" and float(actor.kit.get("touin_next_wind", 0.0)) > 0.0 and bool(actor.kit.get("touin_consume_next", false)):
		actor.kit["touin_next_wind"] = 0.0
		actor.kit["touin_consume_next"] = false


func _chihaya_best(side: bool) -> Fighter:
	return _best_sheet(side, 56)


func _chihaya_on_fire_attack(actor: Fighter, target: Fighter) -> void:
	var chihaya := _chihaya_best(actor.enemy)
	if chihaya == null or chihaya.hp <= 0:
		return
	# spend armed next-fire on this attack if already pending from prior spend
	if float(actor.kit.get("chihaya_next_fire", 0.0)) > 0.0:
		actor.kit["chihaya_consume_next"] = true
	var left := int(chihaya.kit.get("chihaya_left", 0))
	if left <= 0:
		return
	chihaya.kit["chihaya_left"] = left - 1
	if is_instance_valid(chihaya.unit):
		chihaya.unit.kit_flags["gem_charges"] = int(chihaya.kit.get("chihaya_left", 0))
	var extra := maxi(1, int(chihaya.kit.get("break_extra", 1)))
	if target.alive and target.hp > 0:
		for _i in extra:
			var left_b := int(target.break_left.get("fire", BREAK_MAX))
			if left_b <= 0:
				break
			target.break_left["fire"] = maxi(0, left_b - BREAK_STEP)
			if int(target.break_left["fire"]) <= 0:
				target.break_left["fire"] = BREAK_MAX
	actor.kit["chihaya_next_fire"] = float(chihaya.kit.get("next_fire", 0.0))
	actor.kit["chihaya_consume_next"] = false
	_host._log("%s の炎撃破が進み、次の炎が強くなる" % actor.unit.get_display_name())


func _touin_best(side: bool) -> Fighter:
	return _best_sheet(side, 58)


func _touin_on_crit(attacker: Fighter) -> void:
	var touin := _touin_best(attacker.enemy)
	if touin == null or not _is_backline(touin) or touin.hp <= 0:
		return
	var need := maxi(1, int(touin.kit.get("sign_need", 4)))
	var stacks := mini(need, int(touin.kit.get("sign_stacks", 0)) + 1)
	touin.kit["sign_stacks"] = stacks
	if is_instance_valid(touin.unit):
		touin.unit.kit_flags["sign_stacks"] = stacks
	if stacks >= need:
		touin.kit["sign_ready"] = true


func _touin_on_wind_attack(actor: Fighter, target: Fighter) -> void:
	var touin := _touin_best(actor.enemy)
	if touin == null or not _is_backline(touin) or touin.hp <= 0:
		return
	if float(actor.kit.get("touin_next_wind", 0.0)) > 0.0:
		actor.kit["touin_consume_next"] = true
	if not bool(touin.kit.get("sign_ready", false)):
		return
	touin.kit["sign_ready"] = false
	touin.kit["sign_stacks"] = 0
	if is_instance_valid(touin.unit):
		touin.unit.kit_flags["sign_stacks"] = 0
	var extra := maxi(1, int(touin.kit.get("break_extra", 2)))
	if target.alive and target.hp > 0:
		for _i in extra:
			var left_b := int(target.break_left.get("wind", BREAK_MAX))
			if left_b <= 0:
				break
			target.break_left["wind"] = maxi(0, left_b - BREAK_STEP)
			if int(target.break_left["wind"]) <= 0:
				target.break_left["wind"] = BREAK_MAX
	actor.kit["touin_next_wind"] = float(touin.kit.get("next_wind", 0.0))
	actor.kit["touin_consume_next"] = false
	_host._log("%s の風撃破が進み、次の風が強くなる" % actor.unit.get_display_name())


func _toba_best(side: bool) -> Fighter:
	return _best_sheet(side, 59)


func _toba_earth_target(actor: Fighter) -> Fighter:
	var toba := _toba_best(actor.enemy)
	if toba == null or not _is_backline(toba) or toba.hp <= 0:
		return null
	if bool(actor.kit.get("toba_follow_resolving", false)):
		return null
	var best: Fighter = null
	var best_n := -1
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if _is_backline(foe) or not foe.alive or foe.hp <= 0:
			continue
		var n := int(foe.kit.get("earth_break_hits", 0))
		if n <= 0:
			continue
		if best == null or n > best_n or (n == best_n and foe.unit.unit_id < best.unit.unit_id):
			best = foe
			best_n = n
	return best


func _era4_note_break(actor: Fighter, target: Fighter, broke: bool) -> void:
	if actor == null or target == null or actor.element != "earth":
		return
	if not is_instance_valid(target.unit):
		return
	target.kit["earth_break_hits"] = int(target.kit.get("earth_break_hits", 0)) + 1
	var toba := _toba_best(actor.enemy)
	if toba == null or not _is_backline(toba) or toba.hp <= 0:
		return
	# non-deep-arch allies get an extra reduce step when targeting via toba
	if not _has_synergy(actor, "ディープ・アーキテクチャ") and _toba_earth_target(actor) == target:
		var left_b := int(target.break_left.get("earth", BREAK_MAX))
		if left_b > 0 and not broke:
			target.break_left["earth"] = maxi(0, left_b - BREAK_STEP)
			if int(target.break_left["earth"]) <= 0:
				target.break_left["earth"] = BREAK_MAX
				broke = true
	if broke:
		if _host != null and _host.session != null:
			_host.session.gain_experience(maxi(1, int(toba.kit.get("break_xp", 1))))
		var left := int(toba.kit.get("extra_attack_left", int(toba.kit.get("extra_attacks", 1))))
		if left > 0 and not bool(actor.kit.get("toba_follow_resolving", false)):
			toba.kit["extra_attack_left"] = left - 1
			actor.kit["toba_pending_follow"] = true


func _toba_on_earth_attack(actor: Fighter, target: Fighter) -> void:
	var toba := _toba_best(actor.enemy)
	if toba == null:
		return
	if bool(actor.kit.get("toba_pending_follow", false)):
		actor.kit["toba_pending_follow"] = false
		var next_t := _toba_follow_target(actor, target)
		if next_t != null:
			actor.kit["toba_follow_resolving"] = true
			await _resolve_packet(actor, next_t, true, false, false)
			actor.kit["toba_follow_resolving"] = false


func _toba_follow_target(actor: Fighter, exclude: Fighter) -> Fighter:
	var best: Fighter = null
	var best_n := -1
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe == exclude or _is_backline(foe) or not foe.alive or foe.hp <= 0:
			continue
		var n := int(foe.kit.get("earth_break_hits", 0))
		if best == null or n > best_n or (n == best_n and foe.unit.unit_id < best.unit.unit_id):
			best = foe
			best_n = n
	return best


func _torahime_pick_back(actor: Fighter) -> Fighter:
	var pool: Array = []
	for entry in _opponents(actor):
		var foe: Fighter = entry
		if foe.alive and foe.hp > 0 and _is_backline(foe):
			pool.append(foe)
	if pool.is_empty():
		for entry2 in _opponents(actor):
			var f2: Fighter = entry2
			if f2.alive and f2.hp > 0 and not _is_backline(f2):
				pool.append(f2)
	return _extreme(pool, "threat", true)


func _torahime_opening_strike(actor: Fighter) -> void:
	var target := _torahime_pick_back(actor)
	if target == null:
		return
	actor.kit["torahime_opening_bonus"] = float(actor.kit.get("opening_earth", 0.4))
	if is_instance_valid(actor.unit):
		actor.unit.play_battle_role("attack")
		actor.unit.popup_battle_text("開幕", Color(0.85, 0.7, 0.4))
	await _wait(ATTACK_HIT_TIME)
	actor.kit["continuity_done"] = false
	await _resolve_packet(actor, target, true, false, false)
	actor.kit["torahime_opening_bonus"] = 0.0
	actor.kit["lock_target_id"] = target.unit.get_instance_id() if target.alive and target.hp > 0 else -1
	actor.kit["lock_left"] = 1 if int(actor.kit.get("lock_target_id", -1)) > 0 else 0
	if is_instance_valid(actor.unit) and not actor.unit.battle_ko:
		actor.unit.play_battle_role("idle")
	await _wait(0.1)


func _torahime_extra_strike(actor: Fighter) -> void:
	actor.kit["extra_earth_armed"] = false
	if is_instance_valid(actor.unit):
		actor.unit.kit_flags["extra_earth_armed"] = false
	var target := _torahime_pick_back(actor)
	if target == null:
		return
	actor.kit["torahime_opening_bonus"] = float(actor.kit.get("opening_earth", 0.4))
	if is_instance_valid(actor.unit):
		actor.unit.popup_battle_text("追加土", Color(0.85, 0.7, 0.4))
	await _resolve_packet(actor, target, true, false, false)
	actor.kit["torahime_opening_bonus"] = 0.0
	# pending buff remains for the following normal attack in same action
	actor.kit["torahime_pending_earth"] = float(actor.kit.get("pending_earth", 0.2))


func _era4_on_damage_dealt(actor: Fighter, target: Fighter, dealt: int) -> void:
	if actor == null or dealt <= 0:
		return
	if actor.sheet_id == 61 and target != null and not target.alive:
		_torahime_on_kill(actor)
	if actor.sheet_id == 61 and float(actor.kit.get("torahime_pending_earth", 0.0)) > 0.0 and not bool(actor.kit.get("extra_earth_armed", false)):
		# clear pending after the normal attack that followed the extra strike
		if not bool(actor.kit.get("torahime_opening_bonus", false)):
			pass


func _torahime_on_kill(actor: Fighter) -> void:
	if actor == null or not actor.alive or actor.hp <= 0:
		return
	var gain := _bistron_gauge_step(actor.enemy)
	var gauge := int(actor.kit.get("gauge", 0)) + gain
	GameAudio.play_battle_gauge()
	if gauge < 100:
		actor.kit["gauge"] = gauge
		if is_instance_valid(actor.unit):
			actor.unit.kit_flags["torahime_gauge"] = gauge
		_show_gauge(actor)
		return
	actor.kit["gauge"] = 0
	actor.kit["extra_earth_armed"] = true
	actor.kit["torahime_pending_earth"] = float(actor.kit.get("pending_earth", 0.2))
	if is_instance_valid(actor.unit):
		actor.unit.kit_flags["torahime_gauge"] = 0
		actor.unit.kit_flags["extra_earth_armed"] = true
		actor.unit.popup_battle_text("追加準備", Color(0.85, 0.7, 0.4))
	_show_gauge(actor)
	_host._log("%s のゲージが満ち、次の攻撃前に土がもう1回入る" % actor.unit.get_display_name())


func _toba_round_xp_total(board: BoardController) -> int:
	var total := 0
	var best: GameUnit = null
	for unit in board.get_circle_units():
		if unit == null or unit.unit_id != 59 or unit.is_enemy:
			continue
		if best == null or unit.stars > best.stars or (unit.stars == best.stars and unit.unit_id < best.unit_id):
			best = unit
	if best == null:
		return 0
	var sheet := CharacterSheet.make(best.unit_id, best.stars)
	return maxi(1, int(sheet.get("round_xp", 1)))


func _era5_battle_start_sync() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 63:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 65:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 68:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 64:
			_show_gauge(fighter)


func _era5_on_targeted(actor: Fighter, target: Fighter) -> void:
	if target == null or actor == null or actor.enemy == target.enemy:
		return
	if target.sheet_id == 62 and target.alive and target.hp > 0:
		var pen := float(target.kit.get("pen_per_hit", 0.1))
		target.kit["nagano_pen"] = minf(1.0, float(target.kit.get("nagano_pen", 0.0)) + pen)
		_cut_ap(target, maxi(1, int(target.kit.get("ap_cut", 40))))
		target.kit["nagano_force_hit_armed"] = true
		## 狙った相手がナガノのとき、その攻撃全体（範囲端含む）はクリティカルしない。
		actor.kit["attack_no_crit"] = true
	if target.sheet_id == 66 and target.alive and target.hp > 0:
		if not bool(actor.kit.get("nabari_first_done", false)):
			actor.kit["nabari_first_done"] = true
			target.kit["nabari_first_cut"] = float(target.kit.get("first_taken_cut", 0.3))
			if not bool(target.kit.get("nabari_ice_armed", false)):
				target.kit["nabari_ice_armed"] = true
				target.kit["nabari_ice_empower"] = float(target.kit.get("ice_empower", 0.2))
			if not bool(target.kit.get("nabari_ap_zero_used", false)) and target.hp > 0:
				target.kit["nabari_ap_zero_used"] = true
				target.ap = 0
				if is_instance_valid(target.unit):
					target.unit.action_value = 0
					target.unit.popup_battle_text("割込", Color(0.7, 0.9, 1.0))


func _nabari_taunt_target(actor: Fighter) -> Fighter:
	if actor == null:
		return null
	if bool(actor.kit.get("nabari_first_done", false)):
		return null
	var nabari := _best_sheet(not actor.enemy, 66)
	if nabari == null or nabari.hp <= 0:
		return null
	return nabari


func _era5_on_ally_action(actor: Fighter, was_buff: bool) -> void:
	# nagahama damage gauge handled on hit; kill gauge on damage
	var greek := _greek_gauge_step(actor.enemy)
	var pandora := _pandora_gauge_step(actor.enemy)
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0:
			continue
		if ally.sheet_id == 65:
			var gain := greek
			if ally == actor:
				gain += pandora
			_naura_add_gauge(ally, gain, false)
		if ally.sheet_id == 68 and ally == actor and not _is_backline(ally):
			_nishimino_add_gauge(ally, pandora)
	if actor.sheet_id == 64 and bool(actor.kit.get("did_attack", false)):
		_nada_add_gauge(actor, _soar_bridge_gauge_step(actor.enemy), false)


func _nagahama_add_gauge(fighter: Fighter, amount: int) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	fighter.kit["nagahama_extra_layers"] = true
	_show_gauge(fighter)
	if is_instance_valid(fighter.unit):
		fighter.unit.popup_battle_text("多層", Color(0.75, 0.55, 1.0))
	_host._log("%s のゲージが満ち、次の吸収で層が多く付く" % fighter.unit.get_display_name())


func _nada_add_gauge(fighter: Fighter, amount: int, from_crit: bool) -> void:
	if fighter == null or amount <= 0:
		return
	# gauge persists even at 0 hp
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		if is_instance_valid(fighter.unit):
			fighter.unit.kit_flags["nada_gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	var add := float(fighter.kit.get("gauge_crit", 25.0))
	if bool(fighter.kit.get("nada_first_fill", true)):
		add *= 2.0
		fighter.kit["nada_first_fill"] = false
		if is_instance_valid(fighter.unit):
			fighter.unit.kit_flags["nada_filled_once"] = true
	var base := fighter.crit_rate * 100.0
	var now := float(fighter.kit.get("nada_gauge_crit", 0.0))
	var room := maxf(0.0, 100.0 - base - now)
	fighter.kit["nada_gauge_crit"] = now + minf(add, room)
	if is_instance_valid(fighter.unit):
		fighter.unit.kit_flags["nada_gauge"] = 0
		fighter.unit.kit_flags["nada_gauge_crit"] = float(fighter.kit.get("nada_gauge_crit", 0.0))
		fighter.unit.popup_battle_text("会心+", Color(1.0, 0.85, 0.4))
	_show_gauge(fighter)
	_host._log("%s のゲージが満ち、クリティカル率が上がった" % fighter.unit.get_display_name())


func _naura_add_gauge(fighter: Fighter, amount: int, after_crit: bool) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	_show_gauge(fighter)
	_naura_break_reduce(fighter, maxi(1, int(fighter.kit.get("break_extra", 2))), true)
	if is_instance_valid(fighter.unit):
		fighter.unit.popup_battle_text("撃破-", Color(0.9, 0.85, 0.4))


func _naura_break_reduce(naura: Fighter, times: int, prefer_last: bool) -> void:
	var target: Fighter = null
	if prefer_last:
		target = _fighter_by_id(int(naura.kit.get("last_attack_target_id", -1)))
	if target == null or not target.alive or target.hp <= 0 or target.enemy == naura.enemy:
		target = _extreme(_opponents(naura), "threat", true)
	if target == null:
		return
	for _i in times:
		var left_b := int(target.break_left.get("thunder", BREAK_MAX))
		if left_b <= 0:
			break
		target.break_left["thunder"] = maxi(0, left_b - BREAK_STEP)
		if int(target.break_left["thunder"]) <= 0:
			target.break_left["thunder"] = BREAK_MAX


func _naura_on_death(dead: Fighter) -> void:
	if dead == null or dead.sheet_id != 65:
		return
	var times := maxi(1, int(dead.kit.get("death_break", 2)))
	var taken := float(dead.kit.get("death_thunder_taken", 0.15))
	for entry in _opponents(dead):
		var foe: Fighter = entry
		if _is_backline(foe) or not foe.alive or foe.hp <= 0:
			continue
		for _i in times:
			var left_b := int(foe.break_left.get("thunder", BREAK_MAX))
			if left_b <= 0:
				break
			foe.break_left["thunder"] = maxi(0, left_b - BREAK_STEP)
			if int(foe.break_left["thunder"]) <= 0:
				foe.break_left["thunder"] = BREAK_MAX
		var prev := float(foe.kit.get("naura_thunder_taken", 0.0))
		if taken >= prev:
			foe.kit["naura_thunder_taken"] = taken
			foe.kit["naura_thunder_taken_once"] = true


func _nishimino_add_gauge(fighter: Fighter, amount: int) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	var bonus := float(fighter.kit.get("second_base", 0.4))
	var relics := 0
	if _host != null and _host.session != null:
		relics = mini(maxi(1, int(fighter.kit.get("relic_cap", 2))), _host.session.relics.size())
	bonus += float(fighter.kit.get("relic_ratio", 0.15)) * float(relics)
	fighter.kit["nishimino_double_armed"] = true
	fighter.kit["nishimino_second_bonus"] = bonus
	if is_instance_valid(fighter.unit):
		fighter.unit.kit_flags["nishimino_double_armed"] = true
		fighter.unit.kit_flags["nishimino_second_bonus"] = bonus
		fighter.unit.popup_battle_text("二連", Color(0.45, 0.75, 1.0))
	_show_gauge(fighter)


func _noukyo_splash_count(actor: Fighter) -> int:
	if not _has_synergy(actor, "農協月へ行く") and actor.sheet_id != 67:
		return 1
	var count := _synergy_member_count(actor.enemy, "農協月へ行く")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _nose_note_enemy_buff(buffer: Fighter, target: Fighter) -> void:
	if buffer == null or target == null or buffer == target:
		return
	# enemy team buffs their ally: nose on opposing side remembers target
	for entry in _side(not buffer.enemy):
		var nose: Fighter = entry
		if nose.sheet_id != 69 or not nose.alive or nose.hp <= 0:
			continue
		if int(nose.kit.get("mark_moves_left", 0)) <= 0:
			continue
		nose.kit["nose_mark_id"] = target.unit.get_instance_id() if is_instance_valid(target.unit) else -1
		_host._log("%s が %s を覚えた" % [nose.unit.get_display_name(), target.unit.get_display_name()])


func _nose_clear_mark_on_death(dead: Fighter) -> void:
	if dead == null or not is_instance_valid(dead.unit):
		return
	var dead_id := dead.unit.get_instance_id()
	for entry in _side(not dead.enemy):
		var nose: Fighter = entry
		if nose.sheet_id != 69:
			continue
		if int(nose.kit.get("nose_mark_id", -1)) == dead_id:
			nose.kit["nose_mark_id"] = -1


func _era5_after_packet(actor: Fighter, target: Fighter, direct: bool) -> void:
	if actor == null or target == null:
		return
	if actor.sheet_id == 63 and actor.element == "absorb" and bool(actor.kit.get("nagahama_extra_layers", false)) and direct:
		actor.kit["nagahama_extra_layers"] = false
		var extra := maxi(1, int(actor.kit.get("extra_layers", 1)))
		_add_layers(target, "absorb", extra)
		# paprika base layer already via continuity; side target highest hp front
		var side: Fighter = null
		var best_hp := -1
		for entry in _opponents(actor):
			var foe: Fighter = entry
			if foe == target or _is_backline(foe) or not foe.alive or foe.hp <= 0:
				continue
			if side == null or foe.hp > best_hp or (foe.hp == best_hp and foe.unit.unit_id < side.unit.unit_id):
				side = foe
				best_hp = foe.hp
		if side != null:
			_add_layers(side, "absorb", maxi(1, int(actor.kit.get("side_layers", 1))))
	if actor.sheet_id == 69 and actor.element == "wind" and direct:
		var mid := int(actor.kit.get("nose_mark_id", -1))
		if mid > 0 and is_instance_valid(target.unit) and target.unit.get_instance_id() == mid:
			# only clear on actual damage - checked in damage dealt
			pass
	if actor.sheet_id == 68 and actor.element == "water" and direct and bool(actor.kit.get("nishimino_double_armed", false)):
		actor.kit["nishimino_pending_second"] = true


func _era5_on_damage_dealt(actor: Fighter, target: Fighter, dealt: int) -> void:
	if actor == null:
		return
	if actor.sheet_id == 63 and dealt > 0 and target != null and not target.alive:
		_nagahama_add_gauge(actor, _bistron_gauge_step(actor.enemy))
	if target != null and target.sheet_id == 63 and dealt > 0 and target.alive:
		_nagahama_add_gauge(target, _oscillator_gauge_step(target.enemy))
	if actor.sheet_id == 64:
		if dealt > 0 and target != null and not target.alive:
			_nada_add_gauge(actor, _bistron_gauge_step(actor.enemy), false)
		if dealt > 0 and bool(actor.kit.get("last_roll_crit", false)):
			_nada_add_gauge(actor, maxi(1, int(actor.kit.get("crit_gauge", 10))), true)
	if actor.sheet_id == 65 and dealt > 0 and bool(actor.kit.get("last_roll_crit", false)) and actor.element == "thunder":
		_naura_add_gauge(actor, maxi(1, int(actor.kit.get("crit_gauge", 6))), true)
	if dealt > 0 and target != null and bool(target.kit.get("naura_thunder_taken_once", false)) and actor.element == "thunder":
		target.kit["naura_thunder_taken"] = 0.0
		target.kit["naura_thunder_taken_once"] = false
	if actor.sheet_id == 69 and actor.element == "wind" and dealt > 0:
		var mid := int(actor.kit.get("nose_mark_id", -1))
		if mid > 0 and is_instance_valid(target.unit) and target.unit.get_instance_id() == mid:
			actor.kit["nose_mark_id"] = -1
			actor.kit["mark_moves_left"] = maxi(0, int(actor.kit.get("mark_moves_left", 0)) - 1)
			if not bool(target.kit.get("nose_wind_marked", false)):
				target.kit["nose_wind_marked"] = true
				target.kit["nose_wind_taken"] = float(actor.kit.get("wind_taken", 0.15))
	if actor.sheet_id == 66 and bool(actor.kit.get("nabari_first_cut_clear", false)):
		pass
	# clear nabari first cut after the redirected first attack resolves damage path via attacker flag
	if bool(actor.kit.get("nabari_first_done", false)) and float(target.kit.get("nabari_first_cut", 0.0)) > 0.0 if target != null else false:
		if target.sheet_id == 66:
			target.kit["nabari_first_cut"] = 0.0


func _era5_finish_attack(actor: Fighter, primary: Fighter) -> void:
	if actor == null or actor.sheet_id != 68:
		return
	if not bool(actor.kit.get("nishimino_pending_second", false)):
		return
	actor.kit["nishimino_pending_second"] = false
	actor.kit["nishimino_double_armed"] = false
	if is_instance_valid(actor.unit):
		actor.unit.kit_flags["nishimino_double_armed"] = false
	var foe := _extreme(_opponents(actor), "hp", true)
	if foe == null:
		return
	actor.kit["nishimino_second"] = true
	await _resolve_packet(actor, foe, true, false, false)
	actor.kit["nishimino_second"] = false


# ---------------------------------------------------------------------------
# 037 サヤマ / 038 サノ / 039 サバエ / 040 サンダ / 041 シマガワ / 043 スサミ / 044 スズカ / 045 スマ
## 未適用・置き換え:
## - サノの召喚物は別ユニットを出さず、倒れたサノのユニットを召喚物として起こし直す（氷色の膜で見分ける）。
##   ビアンカ・オーバースタディの召喚物はゲームに無いので、「それとは別に残る」は対象がない。
## - サノを継続ダメージで倒したときの「層を最後に与えた敵」は記録が無いので、倒した攻撃の主
##   （分からないときは直前にサノを攻撃した敵）で代用する。
## - スマの「笑うなが消したバフ」は、笑うな自体が汎用には未実装なので、タナベがバフを消したときだけ数える。
## - サヤマの吸収耐性の低下・味方の受けるダメージの低下、サバエの層持ちからの軽減、シマガワ/スズカ/スマの
##   バフの継続ダメージ分は、属性耐性の式に足さず最終ダメージへの倍率で近似している。
## - にぎやかな未来の「攻撃したあと対象に炎の層を1つ」（battle.md の継続シナジー）は、ここで炎のメンバー全員に入れる。
## - 範囲シナジー（狂気の沙汰も金次第・カーテンコール・シグナル・ノイズ）の4人以上の与ダメージ上昇は書き写さない。

func _era6_assign_kit(fighter: Fighter) -> void:
	match fighter.sheet_id:
		38:
			fighter.kit["sano_summoned"] = false
			fighter.kit["sano_summon_active"] = false
			fighter.kit["sano_summon_pending"] = false
			fighter.kit["sano_last_hitter_id"] = -1
			fighter.kit["sano_summon_hitter_id"] = -1
		39:
			fighter.kit["sabae_fire_active"] = false
			fighter.kit["sabae_opened"] = false
		40:
			fighter.kit["sanda_mark_id"] = -1
			fighter.kit["sanda_fresh"] = false
			fighter.kit["sanda_defense_applied"] = 0.0
		41:
			fighter.kit["swaps_left"] = int(fighter.kit.get("swap_count", 1))
			fighter.kit["shima_mark_id"] = -1
			fighter.kit["shima_mark_seq"] = 0
		43:
			fighter.kit["rotate_left"] = int(fighter.kit.get("rotate_count", 1))
			fighter.kit["susami_kept_id"] = -1
			fighter.kit["susami_rotate_target"] = -1
		44:
			fighter.kit["suzuka_deaths_left"] = int(fighter.kit.get("death_count", 1))
			fighter.kit["layer_break_left"] = int(fighter.kit.get("layer_break_count", 1))
		45:
			fighter.kit["erase_left"] = int(fighter.kit.get("erase_count", 3))
			fighter.kit["reserve_left"] = int(fighter.kit.get("reserve_cap", 1))


func _era6_living_all(enemy: bool) -> Array:
	## 後衛も含めた、体力が0より大きい片側の全員。
	var found: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy != enemy or not fighter.alive or fighter.hp <= 0:
			continue
		if not is_instance_valid(fighter.unit) or fighter.unit.battle_ko:
			continue
		found.append(fighter)
	return found


func _era6_sorted(pool: Array) -> Array:
	var out: Array = pool.duplicate()
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		if a.unit.unit_id != b.unit.unit_id:
			return a.unit.unit_id < b.unit.unit_id
		return a.unit.get_instance_id() < b.unit.get_instance_id()
	)
	return out


func _era6_is_live_foe(actor: Fighter, other: Fighter) -> bool:
	return other != null and other.alive and other.hp > 0 and other.enemy != actor.enemy and is_instance_valid(other.unit)


func _era6_is_live_front_foe(actor: Fighter, other: Fighter) -> bool:
	return _era6_is_live_foe(actor, other) and other.in_queue and not _is_backline(other)


func _era6_range_total(enemy: bool, synergy_name: String) -> int:
	var count := _synergy_member_count(enemy, synergy_name)
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _era6_clear_own_debuffs(actor: Fighter) -> void:
	var list: Array = actor.kit.get("debuffs", [])
	if list.is_empty():
		return
	actor.kit["debuffs"] = []
	for entry in list:
		var item: Dictionary = entry
		var target := _fighter_by_id(int(item.get("target_id", -1)))
		if target != null:
			_apply_buff_value(target, str(item.get("kind", "")), -float(item.get("amount", 0.0)))
			_refresh_unit_aura(target.unit)
	_release_stale_debuffs()


## 撃破ゲージを times 回だけ進める（撃破ダメージとは呼ばない）。減った回数を返す。途中で0になったら止める。
func _era6_step_break(target: Fighter, element: String, times: int) -> int:
	if target == null or not target.alive or target.hp <= 0 or not is_instance_valid(target.unit):
		return 0
	var reduced := 0
	for _i in maxi(0, times):
		var left := int(target.break_left.get(element, BREAK_MAX))
		if left <= 0:
			break
		left = maxi(0, left - BREAK_STEP)
		reduced += 1
		if left <= 0:
			GameAudio.play_battle_break()
			_sync_break_gauge(target, element, true)
			target.break_left[element] = BREAK_MAX
			target.unit.popup_battle_text("撃破", Color(0.75, 0.9, 1.0))
			_host._log("%s の%sの撃破ゲージが0になった" % [target.unit.get_display_name(), element])
			break
		target.break_left[element] = left
		_sync_break_gauge(target, element, false)
	return reduced


## 行動にならない1回の攻撃。属性を一時的に差し替え、命中・ガードは通常どおり見る。
func _era6_side_strike(attacker: Fighter, target: Fighter, element: String, label: String, allow_break: bool) -> Dictionary:
	var result := {"connected": false, "dealt": 0, "broke": false}
	if attacker == null or target == null or not is_instance_valid(attacker.unit) or not is_instance_valid(target.unit):
		return result
	if not target.alive or target.hp <= 0:
		return result
	var saved_element := attacker.element
	attacker.element = element
	var attacker_name := attacker.unit.get_display_name()
	var target_name := target.unit.get_display_name()
	var connected := _roll_hit(target)
	if allow_break:
		result["broke"] = _reduce_break_gauge(attacker, target)
	if not connected:
		attacker.element = saved_element
		GameAudio.play_battle_miss()
		target.unit.popup_battle_text("外れ", Color(0.9, 0.9, 0.9))
		_host._log("%s の%sは %s に外れた" % [attacker_name, label, target_name])
		await _wait(0.12)
		return result
	result["connected"] = true
	var bonus := _kit_bonus(attacker, target, false)
	var rolled := _roll_damage(attacker, target, true, bonus, -1.0)
	var raw := int(rolled["amount"])
	var crit := bool(rolled["crit"])
	var guarded := target.guarding and raw > 0
	var dealt := _mitigate(target, raw)
	_play_attack_sounds(attacker, crit)
	_play_hit_fx(attacker, target)
	attacker.element = saved_element
	var absorbed := _apply_damage(target, dealt)
	result["dealt"] = dealt
	if guarded:
		target.unit.popup_battle_text("ガード", Color(0.62, 0.84, 1.0))
	if dealt > 0:
		var color := Color(1.0, 0.86, 0.35) if crit else Color(1.0, 0.95, 0.9)
		target.unit.popup_battle_text("-%d" % dealt, color)
	_host._log(_damage_log(attacker_name, target_name, raw, dealt, absorbed, crit, guarded, label))
	await _wait(0.22)
	if not target.alive:
		_growth_killer = attacker
		RelicCombat.note_kill(attacker)
		await _ko(target)
	return result


func _era6_kit_bonus(attacker: Fighter, defender: Fighter) -> float:
	var bonus := 0.0
	match attacker.element:
		"absorb":
			bonus += float(attacker.kit.get("era6_absorb_dmg", 0.0))
		"fire":
			bonus += float(attacker.kit.get("era6_fire_dmg", 0.0))
		"wind":
			bonus += float(attacker.kit.get("era6_wind_dmg", 0.0))
	if attacker.sheet_id == 37 and bool(attacker.kit.get("sayama_death_strike", false)):
		bonus += float(attacker.kit.get("death_bonus", 0.3))
	if attacker.sheet_id == 39 and attacker.element == "fire" and bool(attacker.kit.get("sabae_fire_active", false)):
		bonus += float(attacker.kit.get("fire_empower", 0.15))
	bonus -= float(attacker.kit.get("sano_dealt_cut", 0.0))
	if attacker.sheet_id == 40 and attacker.element == "earth" and defender != null and is_instance_valid(defender.unit):
		if not bool(attacker.kit.get("sanda_fresh", false)) and int(attacker.kit.get("sanda_mark_id", -1)) == defender.unit.get_instance_id():
			bonus += float(attacker.kit.get("mark_bonus", 0.15))
	return bonus


func _era6_damage_coef(attacker: Fighter, defender: Fighter, general: bool) -> float:
	var coef := 1.0
	if attacker == null or defender == null:
		return coef
	if not general:
		## 継続ダメージ: シマガワ/スズカ/スマのバフは継続にも入る。
		match attacker.element:
			"absorb":
				coef *= 1.0 + float(attacker.kit.get("era6_absorb_dmg", 0.0))
			"fire":
				coef *= 1.0 + float(attacker.kit.get("era6_fire_dmg", 0.0))
			"wind":
				coef *= 1.0 + float(attacker.kit.get("era6_wind_dmg", 0.0))
	## サバエ: 炎の層を持つ敵からの攻撃と継続ダメージを軽減する。
	if defender.sheet_id == 39 and defender.hp > 0 and attacker.enemy != defender.enemy and int(attacker.layers.get("fire", 0)) > 0:
		coef *= maxf(0.0, 1.0 - float(defender.kit.get("layered_taken_cut", 0.2)))
	if general:
		if attacker.element == "absorb":
			coef *= 1.0 + float(defender.kit.get("sayama_absorb_cut", 0.0))
		coef *= maxf(0.0, 1.0 - float(defender.kit.get("sayama_ally_cut", 0.0)))
		if defender.sheet_id == 38 and bool(defender.kit.get("sano_summon_active", false)):
			coef *= maxf(0.0, 1.0 - float(defender.kit.get("summon_taken_cut", 0.2)))
	return coef


func _era6_threat_delta(fighter: Fighter) -> int:
	if fighter == null or not is_instance_valid(fighter.unit) or fighter.hp <= 0:
		return 0
	var fid := fighter.unit.get_instance_id()
	var delta := 0
	for key in _fighters.keys():
		var sanda: Fighter = _fighters[key]
		if sanda.sheet_id != 40 or sanda.enemy == fighter.enemy:
			continue
		if not sanda.alive or sanda.hp <= 0 or not sanda.in_queue or _is_backline(sanda):
			continue
		if int(sanda.kit.get("sanda_mark_id", -1)) == fid:
			delta += int(sanda.kit.get("mark_priority", 0))
	return delta


func _era6_describe_effect(kind: String, amount: float) -> String:
	match kind:
		"earth_resist":
			return "土のダメージ耐性 %+d%%" % int(round(-amount * 100.0))
		"shimagawa_absorb":
			return "吸収与ダメージ %+d%%" % int(round(amount * 100.0))
		"suzuka_fire":
			return "炎与ダメージ %+d%%" % int(round(amount * 100.0))
		"suma_wind":
			return "風与ダメージ %+d%%" % int(round(amount * 100.0))
		"susami_mark":
			return "スサミの氷の狙い"
	return kind


func _era6_apply_buff_value(target: Fighter, kind: String, amount: float) -> void:
	match kind:
		"earth_resist":
			target.kit["received_earth_resist"] = float(target.kit.get("received_earth_resist", 0.0)) - amount
		"shimagawa_absorb":
			target.kit["era6_absorb_dmg"] = float(target.kit.get("era6_absorb_dmg", 0.0)) + amount
		"suzuka_fire":
			target.kit["era6_fire_dmg"] = float(target.kit.get("era6_fire_dmg", 0.0)) + amount
		"suma_wind":
			target.kit["era6_wind_dmg"] = float(target.kit.get("era6_wind_dmg", 0.0)) + amount


func _era6_buff_target(actor: Fighter, kind: String) -> Fighter:
	match kind:
		"shimagawa_absorb", "suzuka_fire":
			return _extreme(_side(actor.enemy), "attack", true)
		"suma_wind":
			var chosen: Fighter = null
			for entry in _side(actor.enemy):
				var ally: Fighter = entry
				if ally == actor or ally.hp <= 0:
					continue
				if chosen == null or ally.crit_damage > chosen.crit_damage or (is_equal_approx(ally.crit_damage, chosen.crit_damage) and ally.unit.unit_id < chosen.unit.unit_id):
					chosen = ally
			return chosen if chosen != null else actor
	return _extreme(_side(actor.enemy), "speed", true)


func _era6_debuff_target(actor: Fighter) -> Fighter:
	match actor.sheet_id:
		37:
			return _extreme(_opponents(actor), "attack", true)
		38:
			var key := "sano_summon_hitter_id" if bool(actor.kit.get("sano_summon_active", false)) else "sano_last_hitter_id"
			var hitter := _fighter_by_id(int(actor.kit.get(key, -1)))
			if _era6_is_live_foe(actor, hitter):
				return hitter
			return _extreme(_opponents(actor), "threat", true)
		39:
			var last := _fighter_by_id(int(actor.kit.get("last_attack_target_id", -1)))
			if _era6_is_live_foe(actor, last):
				return last
			return _extreme(_opponents(actor), "threat", true)
		40:
			var mark := _fighter_by_id(int(actor.kit.get("sanda_mark_id", -1)))
			if _era6_is_live_foe(actor, mark):
				return mark
			return _extreme(_opponents(actor), "threat", true)
		43:
			var kept := _fighter_by_id(int(actor.kit.get("susami_kept_id", -1)))
			if _era6_is_live_front_foe(actor, kept):
				return kept
			return _extreme(_opponents(actor), "hp", true)
	return null


func _era6_custom_debuff_ready(actor: Fighter) -> bool:
	return actor.sheet_id == 38 and bool(actor.kit.get("sano_summon_active", false))


## サノの召喚物のデバフ。サノが残したデバフとは別に1つ持つ。
func _sano_summon_debuff(actor: Fighter, kind: String) -> void:
	var foe := _era6_debuff_target(actor)
	if foe == null or not is_instance_valid(foe.unit):
		_host._log("%s の召喚物のデバフは対象がいない" % actor.unit.get_display_name())
		await _wait(0.25)
		return
	var amount := float(actor.kit.get("buff_amount", 0.0))
	await _play_status_transfer(actor.unit, foe.unit, false)
	var kept: Array = []
	for entry in actor.kit.get("debuffs", []):
		var item: Dictionary = entry
		if not bool(item.get("summon", false)):
			kept.append(item)
			continue
		var old := _fighter_by_id(int(item.get("target_id", -1)))
		if old != null:
			_apply_buff_value(old, str(item.get("kind", "")), -float(item.get("amount", 0.0)))
			_refresh_unit_aura(old.unit)
	_apply_buff_value(foe, kind, amount)
	kept.append({"target_id": foe.unit.get_instance_id(), "kind": kind, "amount": amount, "summon": true})
	actor.kit["debuffs"] = kept
	_refresh_unit_aura(foe.unit)
	foe.unit.popup_battle_text("デバフ", Color(0.82, 0.55, 1.0))
	_host._log("%s の召喚物が %s にデバフ（%s）" % [actor.unit.get_display_name(), foe.unit.get_display_name(), _describe_effect(kind, amount)])
	if actor.enemy and not foe.enemy:
		_host.board.mark_debuffed_unit(foe.unit)
		_release_stale_debuffs()
		_sync_queue()


func _era6_sabae_taunter(enemy_side: bool) -> Fighter:
	var chosen: Fighter = null
	for entry in _side(enemy_side):
		var fighter: Fighter = entry
		if fighter.sheet_id != 39 or fighter.hp <= 0:
			continue
		if chosen == null or fighter.unit.stars > chosen.unit.stars or (fighter.unit.stars == chosen.unit.stars and fighter.unit.get_instance_id() < chosen.unit.get_instance_id()):
			chosen = fighter
	return chosen


func _era6_susami_debuff_target(susami: Fighter) -> Fighter:
	for entry in susami.kit.get("debuffs", []):
		var item: Dictionary = entry
		if str(item.get("kind", "")) == "susami_mark":
			return _fighter_by_id(int(item.get("target_id", -1)))
	return null


func _era6_forced_target(actor: Fighter) -> Fighter:
	## サンダ: 前衛での土の攻撃は、覚えた敵を狙い続ける（アンジップ）。
	if actor.sheet_id == 40 and actor.element == "earth" and not _is_backline(actor):
		var mark := _fighter_by_id(int(actor.kit.get("sanda_mark_id", -1)))
		if _era6_is_live_front_foe(actor, mark):
			return mark
	## スサミ: デバフの対象が前衛で生きていれば、氷の通常の攻撃はその敵。
	if actor.sheet_id == 43 and actor.element == "ice":
		var marked := _era6_susami_debuff_target(actor)
		if _era6_is_live_front_foe(actor, marked):
			return marked
	## シマガワ: 入れ替わりのあと、味方の吸収の通常の攻撃が1回だけ少ない前衛を狙う。
	if actor.element == "absorb":
		var holder := _best_sheet(actor.enemy, 41)
		if holder != null:
			var seq := int(holder.kit.get("shima_mark_seq", 0))
			if seq > 0 and int(actor.kit.get("shima_used_seq", 0)) != seq:
				actor.kit["shima_used_seq"] = seq
				var low := _fighter_by_id(int(holder.kit.get("shima_mark_id", -1)))
				if _era6_is_live_front_foe(actor, low):
					return low
	## サバエ: 炎の層を持つ敵は、優先度に関係なくサバエを狙う。
	if int(actor.layers.get("fire", 0)) > 0:
		var sabae := _era6_sabae_taunter(not actor.enemy)
		if sabae != null:
			return sabae
	return null


func _era6_attack_extras(actor: Fighter, primary: Fighter, extras: Array) -> Array:
	if not extras.is_empty() or primary == null:
		return extras
	match actor.sheet_id:
		40:
			if actor.element == "earth":
				var need40 := _era6_range_total(actor.enemy, "狂気の沙汰も金次第") - 1
				if need40 > 0:
					return _era2_smallest_id(actor, primary, need40, extras)
		41:
			if actor.element == "absorb":
				var need41 := _era6_range_total(actor.enemy, "カーテンコール") - 1
				if need41 > 0:
					var picks := _era2_smallest_id(actor, primary, need41, extras)
					if picks.size() < need41:
						## 前衛が足りないときだけ後衛で埋める。
						var backs: Array = []
						for entry in _era6_living_all(not actor.enemy):
							var foe: Fighter = entry
							if foe != primary and _is_backline(foe) and not picks.has(foe):
								backs.append(foe)
						for entry in _era6_sorted(backs):
							if picks.size() >= need41:
								break
							picks.append(entry)
					return picks
		43:
			if actor.element == "ice":
				var need43 := _signal_noise_splash_count(actor) - 1
				if need43 > 0:
					var out: Array = []
					var kept := _fighter_by_id(int(actor.kit.get("susami_kept_id", -1)))
					if kept != primary and _era6_is_live_front_foe(actor, kept):
						out.append(kept)
					for foe in _era2_smallest_id(actor, primary, need43 - out.size(), out):
						out.append(foe)
					return out
	return extras


func _era6_continuity(actor: Fighter, target: Fighter) -> void:
	## にぎやかな未来: 炎で攻撃したあと、対象に炎の継続ダメージを1層与える（命中しなくても）。
	if actor == null or target == null or not actor.alive or actor.element != "fire":
		return
	if not target.alive or target.hp <= 0 or not _has_synergy(actor, "にぎやかな未来"):
		return
	_add_layers(target, "fire", 1)
	var saved := float(actor.kit.get("dot_ratio", 0.05))
	actor.kit["dot_ratio"] = _nigiyaka_dot_ratio(actor.enemy)
	await _apply_dot(actor, target)
	actor.kit["dot_ratio"] = saved


func _era6_begin_attack(actor: Fighter) -> void:
	actor.kit["era6_hit_ids"] = {}
	actor.kit["susami_rotate_target"] = -1
	var snapshot := {}
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		snapshot[key] = int(fighter.layers.get("fire", 0))
	actor.kit["era6_fire_snapshot"] = snapshot


func _era6_layered_fire(actor: Fighter) -> Array:
	var snapshot: Dictionary = actor.kit.get("era6_fire_snapshot", {})
	var found: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy == actor.enemy:
			continue
		if int(fighter.layers.get("fire", 0)) > int(snapshot.get(key, 0)):
			found.append(fighter)
	return found


func _era6_note_break(actor: Fighter, target: Fighter, broke: bool) -> void:
	if broke and actor.sheet_id == 43 and actor.element == "ice" and is_instance_valid(target.unit):
		actor.kit["susami_rotate_target"] = target.unit.get_instance_id()


func _era6_on_attack_contact(actor: Fighter, target: Fighter, connected: bool) -> void:
	if actor == null or target == null or actor.enemy == target.enemy or not connected:
		return
	if not is_instance_valid(target.unit):
		return
	var hits: Dictionary = actor.kit.get("era6_hit_ids", {})
	hits[target.unit.get_instance_id()] = true
	actor.kit["era6_hit_ids"] = hits
	## スマ: 前衛での風の攻撃が当たると、その敵の次のバフを消す予約が1つ残る。
	if actor.sheet_id == 45 and actor.element == "wind" and not _is_backline(actor) and actor.hp > 0:
		var left := int(actor.kit.get("reserve_left", 0))
		if left > 0:
			actor.kit["reserve_left"] = left - 1
			target.kit["suma_reserve"] = int(target.kit.get("suma_reserve", 0)) + 1
			_host._log("%s が %s の次のバフを消す予約を残した" % [actor.unit.get_display_name(), target.unit.get_display_name()])


func _era6_on_targeted(actor: Fighter, target: Fighter) -> void:
	if actor == null or target == null or actor.enemy == target.enemy:
		return
	if not is_instance_valid(actor.unit) or not is_instance_valid(target.unit):
		return
	## サバエの開始時の層を受けた敵の最初の攻撃は、サバエへの命中が下がる。
	if bool(actor.kit.get("sabae_evade_pending", false)):
		actor.kit["sabae_evade_pending"] = false
		if target.sheet_id == 39 and target.hp > 0:
			target.kit["hit_speed_bonus"] = int(target.kit.get("hit_speed_bonus", 0)) + int(actor.kit.get("sabae_evade_speed", 0))
	if target.sheet_id == 38:
		var key := "sano_summon_hitter_id" if bool(target.kit.get("sano_summon_active", false)) else "sano_last_hitter_id"
		target.kit[key] = actor.unit.get_instance_id()
	if actor.sheet_id == 40 and actor.element == "earth" and not _is_backline(actor) and actor.hp > 0:
		_sanda_remember(actor, target)


func _sanda_remember(sanda: Fighter, target: Fighter) -> void:
	var tid := target.unit.get_instance_id()
	if int(sanda.kit.get("sanda_mark_id", -1)) == tid:
		sanda.kit["sanda_fresh"] = false
		return
	_sanda_forget(sanda)
	var cut := float(sanda.kit.get("mark_defense_cut", 0))
	target.kit["received_defense_cut"] = float(target.kit.get("received_defense_cut", 0.0)) + cut
	sanda.kit["sanda_defense_applied"] = cut
	sanda.kit["sanda_mark_id"] = tid
	sanda.kit["sanda_fresh"] = true
	_host._log("%s が %s を覚えた" % [sanda.unit.get_display_name(), target.unit.get_display_name()])


func _sanda_forget(sanda: Fighter) -> void:
	var old := _fighter_by_id(int(sanda.kit.get("sanda_mark_id", -1)))
	if old != null:
		old.kit["received_defense_cut"] = float(old.kit.get("received_defense_cut", 0.0)) - float(sanda.kit.get("sanda_defense_applied", 0.0))
	sanda.kit["sanda_defense_applied"] = 0.0
	sanda.kit["sanda_mark_id"] = -1
	sanda.kit["sanda_fresh"] = false


func _era6_finish_attack(actor: Fighter, _primary: Fighter) -> void:
	if actor == null:
		return
	var layered := _era6_layered_fire(actor)
	if not layered.is_empty():
		_sabae_after_fire(actor)
		_suzuka_on_layers(actor, layered)
	if actor.sheet_id == 41 and actor.element == "absorb":
		_shimagawa_swap(actor)
	if actor.sheet_id == 43:
		await _susami_try_rotate(actor)
	actor.kit["era6_hit_ids"] = {}


func _sabae_after_fire(actor: Fighter) -> void:
	if actor.sheet_id != 39 or actor.element != "fire" or bool(actor.kit.get("sabae_fire_active", false)):
		return
	actor.kit["sabae_fire_active"] = true
	actor.kit["received_speed"] = int(actor.kit.get("received_speed", 0)) + int(actor.kit.get("after_speed", 0))
	_recompute_speed(actor, true)
	if is_instance_valid(actor.unit):
		actor.unit.popup_battle_text("加速", Color(1.0, 0.7, 0.4))
		_host._log("%s の速度と炎の与ダメージが上がった" % actor.unit.get_display_name())


func _suzuka_on_layers(actor: Fighter, layered: Array) -> void:
	var suzuka := _best_sheet(actor.enemy, 44)
	if suzuka == null or suzuka.hp <= 0 or not _is_backline(suzuka):
		return
	if int(suzuka.kit.get("layer_break_left", 0)) <= 0:
		return
	var reduced := 0
	for entry in _era6_living_all(not actor.enemy):
		var foe: Fighter = entry
		if layered.has(foe):
			continue
		reduced += _era6_step_break(foe, "fire", 1)
	if reduced > 0:
		suzuka.kit["layer_break_left"] = int(suzuka.kit.get("layer_break_left", 0)) - 1
		_host._log("%s が層の付かなかった敵の炎の撃破を進めた" % suzuka.unit.get_display_name())


func _shimagawa_swap(actor: Fighter) -> void:
	if _best_sheet(actor.enemy, 41) != actor or int(actor.kit.get("swaps_left", 0)) <= 0:
		return
	var hits: Dictionary = actor.kit.get("era6_hit_ids", {})
	var hi: Fighter = null
	var lo: Fighter = null
	for key in hits.keys():
		var foe := _fighter_by_id(int(key))
		if not _era6_is_live_front_foe(actor, foe):
			continue
		if hi == null or foe.hp > hi.hp or (foe.hp == hi.hp and foe.unit.unit_id < hi.unit.unit_id):
			hi = foe
		if lo == null or foe.hp < lo.hp or (foe.hp == lo.hp and foe.unit.unit_id < lo.unit.unit_id):
			lo = foe
	if hi == null or lo == null or hi == lo or hi.hp == lo.hp:
		return
	var hi_hp := hi.hp
	var lo_hp := lo.hp
	lo.hp = mini(lo.max_hp, hi_hp)
	hi.hp = lo_hp
	actor.kit["swaps_left"] = int(actor.kit.get("swaps_left", 0)) - 1
	for entry in [hi, lo]:
		var foe: Fighter = entry
		foe.unit.set_battle_hp(foe.hp, foe.max_hp)
		foe.unit.popup_battle_text("入れ替え", Color(0.75, 0.55, 1.0))
	_host._log("%s の吸収で %s と %s の体力が入れ替わった" % [actor.unit.get_display_name(), hi.unit.get_display_name(), lo.unit.get_display_name()])
	var low := lo
	if hi.hp < lo.hp or (hi.hp == lo.hp and hi.unit.unit_id < lo.unit.unit_id):
		low = hi
	actor.kit["shima_mark_id"] = low.unit.get_instance_id()
	actor.kit["shima_mark_seq"] = int(actor.kit.get("shima_mark_seq", 0)) + 1


func _susami_try_rotate(actor: Fighter) -> void:
	var target_id := int(actor.kit.get("susami_rotate_target", -1))
	actor.kit["susami_rotate_target"] = -1
	if target_id < 0 or not actor.alive or actor.hp <= 0:
		return
	if int(actor.kit.get("rotate_left", 0)) <= 0:
		return
	var target := _fighter_by_id(target_id)
	if target == null or not target.alive or target.hp <= 0 or target.enemy == actor.enemy:
		return
	await _susami_rotate(actor, target)


## スサミ: 撃破した敵の位置で向きを決め、相手のサークルを1つ分回す。
## サークルの順は 0(前左)→1(前中)→2(前右)→3(後右)→4(後中)→5(後左)→0。
func _susami_rotate(actor: Fighter, target: Fighter) -> void:
	var board: BoardController = _host.board
	var slot := board.slot_of_unit(target.unit)
	if slot < 0:
		return
	var steps := -1 if (slot == 2 or slot == 3) else 1
	var was_back: Dictionary = {}
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.enemy != target.enemy or not is_instance_valid(fighter.unit):
			continue
		was_back[key] = not fighter.in_queue
	actor.kit["rotate_left"] = int(actor.kit.get("rotate_left", 0)) - 1
	if target.enemy:
		board.rotate_enemy_slots(steps)
	else:
		await _spin_circle(steps)
	_sync_queue()
	var ratio := float(actor.kit.get("enter_ap_ratio", 0.2))
	for key in was_back.keys():
		var fighter: Fighter = _fighters.get(key, null)
		if fighter == null or not bool(was_back[key]) or not fighter.in_queue or not fighter.alive:
			continue
		fighter.ap = int(round(float(fighter.base_ap) * (1.0 + ratio)))
		fighter.saved_ap = fighter.ap
		if is_instance_valid(fighter.unit):
			fighter.unit.action_value = fighter.ap
	if target.in_queue and not _is_backline(target):
		actor.kit["susami_kept_id"] = target.unit.get_instance_id()
	if is_instance_valid(target.unit):
		target.unit.popup_battle_text("回転", Color(0.6, 0.85, 1.0))
	_host._log("%s の氷の撃破で、相手のサークルが%sに1つ回った" % [actor.unit.get_display_name(), "右まわり" if steps > 0 else "左まわり"])
	_refresh_passive_kits()
	_refresh_bar()


func _era6_opening() -> void:
	var sabaes: Array = []
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 39 and fighter.alive and fighter.hp > 0 and not bool(fighter.kit.get("sabae_opened", false)):
			sabaes.append(fighter)
	for entry in _era6_sorted(sabaes):
		var sabae: Fighter = entry
		sabae.kit["sabae_opened"] = true
		var foes := _era6_sorted(_opponents(sabae))
		if foes.is_empty():
			continue
		var layers := maxi(1, int(sabae.kit.get("start_layers", 2)))
		for foe_entry in foes:
			var foe: Fighter = foe_entry
			_add_layers(foe, "fire", layers)
			foe.kit["sabae_evade_pending"] = true
			foe.kit["sabae_evade_speed"] = int(sabae.kit.get("start_speed", 30))
		_host._log("%s が敵すべてに炎の層を %d 付けた" % [sabae.unit.get_display_name(), layers])
		var saved := float(sabae.kit.get("dot_ratio", 0.05))
		sabae.kit["dot_ratio"] = _nigiyaka_dot_ratio(sabae.enemy)
		for foe_entry in foes:
			var foe: Fighter = foe_entry
			if not foe.alive or foe.hp <= 0:
				continue
			await _apply_dot(sabae, foe)
			if not foe.alive and is_instance_valid(foe.unit) and not foe.unit.battle_ko:
				_growth_killer = sabae
				await _ko(foe)
		sabae.kit["dot_ratio"] = saved


func _era6_refresh_passive() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if not fighter.alive or fighter.hp <= 0 or not is_instance_valid(fighter.unit):
			continue
		match fighter.sheet_id:
			41, 44, 45:
				## 体力があるあいだは常に入るバフ。対象が変わると移る。
				var kind := str(fighter.kit.get("buff_kind", ""))
				var target := _era6_buff_target(fighter, kind)
				if target == null:
					target = fighter
				if int(fighter.kit.get("buff_target_id", -1)) != target.unit.get_instance_id() or str(fighter.kit.get("buff_kind_active", "")) != kind:
					_set_single_buff(fighter, target, kind, float(fighter.kit.get("buff_amount", 0.0)))
			43:
				var marked := _era6_susami_debuff_target(fighter)
				if marked != null and (not marked.alive or marked.hp <= 0 or not marked.in_queue or _is_backline(marked)):
					_era6_clear_own_debuffs(fighter)


func _era6_on_death(dead: Fighter) -> void:
	if dead == null or not is_instance_valid(dead.unit):
		return
	var dead_id := dead.unit.get_instance_id()
	for key in _fighters.keys():
		var sanda: Fighter = _fighters[key]
		if sanda.sheet_id == 40 and sanda != dead and int(sanda.kit.get("sanda_mark_id", -1)) == dead_id:
			_sanda_forget(sanda)
	match dead.sheet_id:
		37:
			await _sayama_on_death(dead)
		38:
			_sano_on_death(dead)
		39, 43:
			_era6_clear_own_debuffs(dead)
		40:
			_sanda_forget(dead)
			_era6_clear_own_debuffs(dead)
		45:
			_suma_on_death(dead)
	await _suzuka_on_enemy_death(dead)


func _sayama_on_death(dead: Fighter) -> void:
	## 朝のガスパール: 敵の前衛すべてに吸収の攻撃を1回ずつ（IDが小さい順）。
	var foes := _era6_sorted(_opponents(dead))
	if not foes.is_empty():
		_host._log("%s が倒され、敵の前衛に吸収の攻撃が入る" % dead.unit.get_display_name())
	var resist_cut := float(dead.kit.get("death_absorb_cut", 0.15))
	dead.kit["sayama_death_strike"] = true
	for entry in foes:
		var foe: Fighter = entry
		if not foe.alive or foe.hp <= 0:
			continue
		var res: Dictionary = await _era6_side_strike(dead, foe, "absorb", "倒されたときの攻撃", false)
		if bool(res.get("connected", false)) and int(res.get("dealt", 0)) > 0 and foe.alive and foe.hp > 0 and not bool(foe.kit.get("sayama_absorb_marked", false)):
			foe.kit["sayama_absorb_marked"] = true
			foe.kit["sayama_absorb_cut"] = float(foe.kit.get("sayama_absorb_cut", 0.0)) + resist_cut
	dead.kit["sayama_death_strike"] = false
	var ally_cut := float(dead.kit.get("death_ally_cut", 0.1))
	for entry in _side(dead.enemy):
		var ally: Fighter = entry
		if ally == dead or ally.hp <= 0:
			continue
		ally.kit["sayama_ally_cut"] = float(ally.kit.get("sayama_ally_cut", 0.0)) + ally_cut
	_era6_clear_own_debuffs(dead)


func _sano_on_death(dead: Fighter) -> void:
	if bool(dead.kit.get("sano_summon_active", false)) or bool(dead.kit.get("sano_summoned", false)):
		## 召喚物が倒れた。もう1体は残らない。
		dead.kit["sano_summon_active"] = false
		_era6_clear_own_debuffs(dead)
		return
	dead.kit["sano_summoned"] = true
	dead.kit["sano_summon_pending"] = true
	dead.kit["sano_death_hp"] = dead.max_hp
	dead.kit["sano_death_attack"] = dead.attack
	dead.kit["sano_death_threat"] = _threat(dead)
	var killer: Fighter = _growth_killer
	if killer == null or killer.enemy == dead.enemy or not is_instance_valid(killer.unit):
		killer = _fighter_by_id(int(dead.kit.get("sano_last_hitter_id", -1)))
	if killer == null or killer.enemy == dead.enemy or not killer.alive or killer.hp <= 0:
		return
	killer.kit["sano_dealt_cut"] = float(killer.kit.get("sano_dealt_cut", 0.0)) + float(dead.kit.get("killer_dealt_cut", 0.18))
	var delay := int(dead.kit.get("ap_delay", 120))
	if killer.in_queue:
		killer.ap += delay
		killer.unit.action_value = killer.ap
	else:
		killer.saved_ap += delay
	killer.unit.popup_battle_text("遅れ", Color(0.7, 0.85, 1.0))
	_host._log("%s の与ダメージが下がり、次の行動が遅れる" % killer.unit.get_display_name())


func _era6_after_ko(fighter: Fighter) -> void:
	if fighter == null or not bool(fighter.kit.get("sano_summon_pending", false)):
		return
	fighter.kit["sano_summon_pending"] = false
	var unit := fighter.unit
	if _host == null or not _host.is_inside_tree() or not is_instance_valid(unit):
		return
	var hp := maxi(1, int(round(float(fighter.kit.get("sano_death_hp", fighter.max_hp)) * float(fighter.kit.get("summon_hp", 0.5)))))
	fighter.max_hp = hp
	fighter.hp = hp
	fighter.attack = float(fighter.kit.get("sano_death_attack", fighter.attack)) * float(fighter.kit.get("summon_attack", 0.3))
	fighter.priority = int(fighter.kit.get("sano_death_threat", fighter.priority)) + int(fighter.kit.get("summon_priority", 40))
	fighter.layers = {}
	fighter.dot_bank = {}
	_init_break_gauges(fighter)
	fighter.barrier = 0
	fighter.guarding = false
	fighter.alive = true
	fighter.kit["sano_summon_active"] = true
	fighter.kit["sano_summon_hitter_id"] = -1
	unit.battle_ko = false
	unit.defeat_playing = false
	unit.release_battle_clip()
	unit.rotation.x = 0.0
	var board: BoardController = _host.board
	fighter.in_queue = board.front_slot_of(unit) >= 0 and not bool(fighter.kit.get("never_acts", false))
	fighter.ap = fighter.base_ap
	fighter.saved_ap = fighter.base_ap
	unit.action_value = fighter.ap
	board.refresh_presentation()
	unit.set_battle_hp(fighter.hp, fighter.max_hp)
	_show_gauge(fighter)
	_era6_tint_summon(unit)
	unit.play_battle_role("idle")
	unit.popup_battle_text("召喚", Color(0.6, 0.9, 1.0))
	_host._log("%s のいた位置に氷の召喚物が残った（体力 %d）" % [unit.get_display_name(), hp])
	_refresh_passive_kits()
	_refresh_bar()


func _era6_on_finish() -> void:
	## サノの召喚物の膜を外す（敵ユニットは refresh_visuals を通らずに消えるため）。
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 38 and bool(fighter.kit.get("sano_summoned", false)) and is_instance_valid(fighter.unit) and fighter.unit.model_root != null:
			_era6_overlay(fighter.unit.model_root, null)


func _era6_tint_summon(unit: GameUnit) -> void:
	## 戦闘後の refresh_visuals が material_overlay を外すので、ここで付けた膜は残らない。
	if unit == null or unit.model_root == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_era6_overlay(unit.model_root, mat)


func _era6_overlay(node: Node, mat: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_overlay = mat
	for child in node.get_children():
		_era6_overlay(child, mat)


func _suzuka_on_enemy_death(dead: Fighter) -> void:
	var layers := int(dead.layers.get("fire", 0))
	if layers <= 0:
		return
	var suzuka := _best_sheet(not dead.enemy, 44)
	if suzuka == null or suzuka.hp <= 0:
		return
	var left := int(suzuka.kit.get("suzuka_deaths_left", 0))
	if left <= 0:
		return
	suzuka.kit["suzuka_deaths_left"] = left - 1
	var times := mini(layers, maxi(1, int(suzuka.kit.get("death_break_cap", 3))))
	for entry in _era6_living_all(dead.enemy):
		var foe: Fighter = entry
		if foe == dead:
			continue
		_era6_step_break(foe, "fire", times)
	_host._log("%s が倒れ、%s が残りの敵の炎の撃破を %d 回進めた" % [dead.unit.get_display_name(), suzuka.unit.get_display_name(), times])
	var strikers := _era6_sorted(_side(suzuka.enemy))
	if strikers.is_empty():
		return
	for index in times:
		var target := _extreme(_side(dead.enemy), "threat", true)
		if target == null:
			break
		var striker: Fighter = strikers[index % strikers.size()]
		if not striker.alive or striker.hp <= 0:
			continue
		await _era6_side_strike(striker, target, "fire", "炎の追撃", true)


func _suma_on_death(dead: Fighter) -> void:
	if _best_sheet(dead.enemy, 45) != null:
		return
	for key in _fighters.keys():
		var foe: Fighter = _fighters[key]
		if foe.enemy == dead.enemy:
			continue
		foe.kit["suma_reserve"] = 0
		foe.kit["suma_redirect_pending"] = false


## スマ: 相手が仲間へ出すバフ（予約があれば自分へのバフも）を消し、出した敵へ風の攻撃。
## バフを消された敵の次のバフは、こちらの体力が最も低い味方に入る。処理したら true。
func _era6_buff_gate(buffer: Fighter, target: Fighter, kind: String) -> bool:
	if buffer == null or target == null or not is_instance_valid(buffer.unit) or not is_instance_valid(target.unit):
		return false
	var suma := _best_sheet(not buffer.enemy, 45)
	if suma == null or suma.hp <= 0:
		return false
	if bool(buffer.kit.get("suma_redirect_pending", false)):
		buffer.kit["suma_redirect_pending"] = false
		buffer.kit["suma_redirect_done"] = true
		var dest := _extreme(_side(suma.enemy), "hp", false)
		if dest != null and is_instance_valid(dest.unit):
			var amount := float(buffer.kit.get("buff_amount", 0.0))
			await _play_status_transfer(buffer.unit, dest.unit, true)
			_set_single_buff(buffer, dest, kind, amount)
			dest.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
			_host._log("%s のバフが %s に入った（%s）" % [buffer.unit.get_display_name(), dest.unit.get_display_name(), _describe_effect(kind, amount)])
			return true
	var left := int(suma.kit.get("erase_left", 0))
	if left <= 0:
		return false
	var reserve := int(buffer.kit.get("suma_reserve", 0))
	if target == buffer and reserve <= 0:
		return false
	if reserve > 0:
		buffer.kit["suma_reserve"] = reserve - 1
	suma.kit["erase_left"] = left - 1
	target.unit.popup_battle_text("バフ無効", Color(1.0, 0.7, 0.35))
	_host._log("%s へのバフは %s が消した" % [target.unit.get_display_name(), suma.unit.get_display_name()])
	_suma_arm_redirect(buffer)
	await _suma_strike(suma, buffer)
	return true


func _era6_on_buff_erased(buffer: Fighter) -> void:
	## タナベ（笑うな）が消したバフも、スマの回数が残っていれば同じ風の攻撃に入る。
	if buffer == null:
		return
	var suma := _best_sheet(not buffer.enemy, 45)
	if suma == null or suma.hp <= 0:
		return
	var left := int(suma.kit.get("erase_left", 0))
	if left <= 0:
		return
	suma.kit["erase_left"] = left - 1
	_suma_arm_redirect(buffer)
	await _suma_strike(suma, buffer)


func _suma_arm_redirect(buffer: Fighter) -> void:
	if bool(buffer.kit.get("suma_redirect_pending", false)) or bool(buffer.kit.get("suma_redirect_done", false)):
		return
	buffer.kit["suma_redirect_pending"] = true


func _suma_strike(suma: Fighter, buffer: Fighter) -> void:
	if buffer == null or not buffer.alive or buffer.hp <= 0:
		return
	var striker: Fighter = null
	for entry in _era6_living_all(suma.enemy):
		var ally: Fighter = entry
		if ally == suma:
			continue
		if striker == null or ally.attack > striker.attack or (is_equal_approx(ally.attack, striker.attack) and ally.unit.unit_id < striker.unit.unit_id):
			striker = ally
	if striker == null:
		striker = suma
	var res: Dictionary = await _era6_side_strike(striker, buffer, "wind", "風の攻撃", true)
	if bool(res.get("connected", false)) and buffer.alive and buffer.hp > 0:
		_era6_step_break(buffer, "wind", maxi(1, int(suma.kit.get("break_extra", 1))))
