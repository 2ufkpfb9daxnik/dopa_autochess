class_name CharacterSheet
extends RefCounted

const ELEMENT_ORDER: PackedStringArray = ["炎", "水", "雷", "土", "氷", "風", "吸収"]
const ELEMENT_KEYS: PackedStringArray = ["fire", "water", "thunder", "earth", "ice", "wind", "absorb"]


static func make(unit_id: int, stars: int) -> Dictionary:
	var profile := CharacterText.load_profile(unit_id)
	if profile.is_empty():
		return {}
	var fields: Dictionary = profile.get("fields", {})
	var sections: Dictionary = profile.get("sections", {})
	var star := clampi(stars, 1, 4)
	var stats := StarScale.rows(_body(sections, "各種ステータス"), 4)
	var effects := StarScale.rows(_body(sections, "効果値"), 4)
	var actions := StarScale.rows(_body(sections, "行動割合"), 1)
	var attributes := StarScale.rows(_body(sections, "属性補正"), 2)
	var weight_buff := _weight(actions, "バフ/デバフ", 3)
	var sheet := {
		"element": _element_key(str(fields.get("攻撃属性", "炎"))),
		"element_damage": _element_map(attributes, 0),
		"element_resist": _element_map(attributes, 1),
		"hp": int(round(_stat(stats, "最大HP", star))),
		"attack": _stat(stats, "攻撃力", star),
		"defense": _stat(stats, "防御力", star),
		"speed": int(round(_stat(stats, "速度", star))),
		"attribute_resist": _stat(stats, "属性耐性", star) / 100.0,
		"priority": int(round(_stat(stats, "ターゲット優先度", star))),
		"crit_rate": _stat(stats, "クリティカル率", star) / 100.0,
		"crit_damage": _stat(stats, "クリティカルダメージ倍率", star) / 100.0,
		"weight_attack": _weight(actions, "攻撃", 5),
		"weight_buff": weight_buff,
		"weight_guard": _weight(actions, "ガード", 2),
		"uses_buff": weight_buff > 0,
		"buff_kind": "highest_speed_bonus",
		"buff_amount": 0.0,
		"neighbor": 0.0,
		"effects": _resolved_effects(effects, star),
	}
	_apply_binds(sheet, effects, star, [
		["バフの与ダメージ", "buff_amount", true],
		["隣の与ダメージ", "neighbor", true],
	])
	_apply_binds(sheet, effects, star, _binds_for(unit_id))
	_apply_identity(sheet, unit_id)
	return sheet


static func _body(sections: Dictionary, prefix: String) -> String:
	for key in sections.keys():
		var title := str(key)
		if title.begins_with(prefix):
			return str(sections[key])
	return ""


static func _stat(stats: Dictionary, stat_name: String, stars: int) -> float:
	var row: Variant = stats.get(stat_name, null)
	if not (row is Array):
		return 0.0
	return StarScale.resolve(stat_name, row, stars, false)


static func _weight(actions: Dictionary, action_name: String, fallback: int) -> int:
	var row: Variant = actions.get(action_name, null)
	if row is Array and row.size() > 0 and row[0] != null:
		return int(round(float(row[0])))
	return fallback


static func _resolved_effects(effects: Dictionary, stars: int) -> Dictionary:
	var resolved := {}
	for effect_name in effects.keys():
		var label := str(effect_name)
		var row: Variant = effects[effect_name]
		if row is Array:
			resolved[label] = StarScale.resolve(label, row, stars, true)
	return resolved


static func _element_key(label: String) -> String:
	var index := ELEMENT_ORDER.find(label.strip_edges())
	if index < 0:
		return "fire"
	return ELEMENT_KEYS[index]


static func _element_map(attributes: Dictionary, column: int) -> Dictionary:
	var result := {}
	for index in ELEMENT_ORDER.size():
		var row: Variant = attributes.get(ELEMENT_ORDER[index], null)
		var points := 0.0
		if row is Array and column < row.size() and row[column] != null:
			points = float(row[column])
		result[ELEMENT_KEYS[index]] = points / 100.0
	return result


static func _apply_binds(sheet: Dictionary, effects: Dictionary, stars: int, binds: Array) -> void:
	for entry in binds:
		var spec: Array = entry
		var label := str(spec[0])
		var row: Variant = effects.get(label, null)
		if not (row is Array):
			continue
		var number := StarScale.resolve(label, row, stars, true)
		var key := str(spec[1])
		if bool(spec[2]):
			sheet[key] = number / 100.0
		else:
			sheet[key] = int(round(number))


static func _binds_for(unit_id: int) -> Array:
	match unit_id:
		1:
			return [
				["炎の与ダメージ", "fire_per_hit", true],
				["上昇の上限", "fire_cap", true],
				["範囲の追加", "extra_targets", false],
			]
		2:
			return [
				["開始時のゲージ", "gauge", false],
				["バフ時のゲージ", "gauge_buff_extra", false],
				["氷の与ダメージ", "ice_empower", true],
				["ゲージ中の速度", "gauge_speed", false],
				["バフの速度", "buff_amount", false],
			]
		3:
			return [
				["バリア", "barrier_max", false],
				["狙われやすさ", "priority_bonus", false],
				["与ダメージ", "barrier_damage", true],
				["バリア中の速度", "barrier_speed", false],
				["雷のダメージ耐性", "buff_amount", true],
			]
		4:
			return [
				["狙う層", "layer_threshold", false],
				["追加の層", "extra_layers", false],
			]
		5:
			return [
				["バフの炎ダメージ", "buff_amount", true],
			]
		7:
			return [
				["行動しない回数", "skip_cap", false],
				["最初の行動", "first_skip", false],
				["デバフの氷耐性", "buff_amount", true],
			]
		8:
			return [
				["開幕の与ダメージ", "opening_bonus", true],
				["行動ポイント", "ap_bump", false],
				["次の攻撃", "follow_attacks", false],
				["デバフの氷ダメージ", "buff_amount", true],
			]
		9:
			return [
				["開始時のゲージ", "gauge", false],
				["追加の回数", "extra_hits", false],
				["デバフの防御力", "buff_amount", false],
				["水のダメージ耐性", "water_vuln", true],
				["優先度の上昇", "priority_bonus", false],
			]
		10:
			return [
				["受けるダメージ", "copy_taken_cut", true],
				["回復", "heal_ratio", true],
				["与ダメージ", "next_cut", true],
				["属性耐性", "first_hit_resist", true],
				["被弾時の吸収耐性", "first_hit_absorb", true],
				["デバフの吸収耐性", "buff_amount", true],
				["スウィングの体力", "swing_hp", false],
				["スウィングの装備", "swing_cap", false],
			]
		11:
			return [
				["1回の減少", "break_extra", false],
				["追加の攻撃", "extra_attacks", false],
				["バフの吸収ダメージ", "buff_amount", true],
			]
		12:
			return [
				["風の層数", "wind_layers", false],
				["属性耐性", "resist_gain", true],
				["命中時の速度", "hit_speed", false],
				["風のダメージ耐性", "buff_amount", true],
			]
		13:
			return [
				["開始時のゲージ", "gauge", false],
				["満ちたあとの与ダメージ", "charged_bonus", true],
				["デバフの風耐性", "buff_amount", true],
			]
		14:
			return [
				["被弾時の最大体力", "hit_max_hp", false],
				["受けるダメージ", "break_taken_cut", true],
				["属性耐性", "break_resist", true],
				["命中時の速度", "hit_speed", false],
				["水のダメージ耐性", "buff_amount", true],
				["スウィングの防御力", "swing_defense", false],
				["スウィングの装備", "swing_cap", false],
			]
		15:
			return [
				["受けるダメージ", "guard_taken_cut", true],
				["命中時の速度", "hit_speed", false],
				["与ダメージ", "splash_cut", true],
				["雷のダメージ耐性", "buff_amount", true],
			]
		16:
			return [
				["同種合成の回数", "pair_merges", false],
				["範囲を変える回数", "splash_retarget", false],
				["体力の上昇", "merge_hp", false],
				["バフの水与ダメージ", "buff_amount", true],
				["スウィングの水ダメージ", "swing_water", true],
				["スウィングの装備", "swing_cap", false],
			]
		17:
			return [
				["追加の層", "extra_layers", false],
				["追加の上限", "extra_cap", false],
				["数えるレリック", "relic_count_cap", false],
				["倒れたときの攻撃", "death_hits", false],
				["バフの雷ダメージ", "buff_amount", true],
			]
		18:
			return [
				["消す数", "cleanse_count", false],
				["無料更新", "free_rerolls", false],
				["炎の与ダメージ", "bare_bonus", true],
				["デバフの炎耐性", "buff_amount", true],
			]
		19:
			return [
				["選ぶ体数", "extra_targets", false],
				["範囲の炎ダメージ", "splash_fire_vuln", true],
				["バフの炎ダメージ", "buff_amount", true],
			]
		20:
			return [
				["入る前衛", "column_hits", false],
				["バフの土ダメージ", "buff_amount", true],
			]
		21:
			return [
				["残る回数", "synth_charges", false],
				["層1つの範囲ダメージ", "layer_splash", true],
				["数える層", "layer_cap", false],
				["狙われにくさ", "priority_cut", false],
				["土の与ダメージ", "earth_empower", true],
			]
		23:
			return [
				["残る回数", "gem_charges", false],
				["バフの雷ダメージ", "buff_amount", true],
			]
		24:
			return [
				["属性耐性", "attacker_resist_cut", true],
				["受けるダメージ", "redirect_taken_cut", true],
				["土のダメージ耐性", "buff_amount", true],
			]
		25:
			return [
				["倒れたあとの体数", "death_extra", false],
				["バフの風ダメージ", "buff_amount", true],
			]
		26:
			return [
				["残る回数", "synth_charges", false],
				["風の攻撃", "wind_empower", true],
				["回数中の風の与ダメージ", "wind_self", true],
				["属性耐性", "resist_gain", true],
				["属性耐性の上限", "resist_cap", true],
				["風の与ダメージ", "buff_amount", true],
			]
		27:
			return [
				["炎のダメージ耐性", "buff_amount", true],
			]
		28:
			return [
				["コピーする層", "copy_layers", false],
				["層が無いとき", "fallback_layers", false],
				["ガードになる行動", "force_guard", false],
				["バフの水ダメージ", "buff_amount", true],
			]
		29:
			return [
				["開始時のゲージ", "gauge", false],
				["吸収の与ダメージ", "absorb_empower", true],
				["吸収の回復", "absorb_heal", true],
				["戻るゲージ", "gauge_refund", false],
				["バフの吸収の与ダメージ", "buff_amount", true],
			]
		30:
			return [
				["被弾時のクリティカル率", "hit_crit", true],
				["属性耐性", "first_resist", true],
				["命中時の速度", "hit_speed", false],
				["受けるダメージ", "guard_taken_cut", true],
				["行動の遅れ", "ap_delay", false],
				["バフの防御力", "buff_amount", false],
			]
		31:
			return [
				["コピーする層", "copy_layers", false],
				["倒れたあとの層", "death_copy", false],
				["バフの水ダメージ", "buff_amount", true],
			]
		32:
			return [
				["宝石ポイント", "gem_mult", false],
				["クリティカルダメージ", "front_crit_damage", false],
				["デバフの吸収ダメージ", "buff_amount", true],
			]
		33:
			return [
				["当たったあとの受けるダメージ", "mark_taken", true],
				["優先度の低下", "priority_cut", false],
				["上昇の移動", "mark_moves", false],
				["デバフの受けるダメージ", "buff_amount", true],
			]
		34:
			return [
				["クリティカルダメージ", "forced_crit_damage", false],
				["バフの氷ダメージ", "buff_amount", true],
			]
		35:
			return [
				["味方の与ダメージ", "ally_damage", true],
				["左右の与ダメージ", "side_damage", true],
				["レリックの与ダメージ", "relic_damage", true],
				["数えるレリック", "relic_count_cap", false],
				["左右のクリティカル率", "side_crit", true],
				["合成の与ダメージ", "synth_damage", true],
				["合成の上限", "synth_cap", true],
				["スウィングの速度", "swing_speed", false],
				["スウィングの装備", "swing_cap", false],
			]
		36:
			return [
				["召喚の回数", "summon_charges", false],
				["召喚の水ダメージ", "summon_water", true],
				["召喚のクリティカルダメージ", "summon_crit_damage", false],
				["バフの水ダメージ", "buff_amount", true],
			]
		6:
			return [
				["最初の与ダメージ", "first_bonus", true],
				["土の被ダメージ", "earth_vuln", true],
				["速度の低下", "slow", false],
			]
		22:
			return [
				["味方の被弾", "ally_hit_gauge", false],
				["返る回数", "reflect_cap", false],
				["バフの継続ダメージ", "buff_amount", true],
			]
		42:
			return [
				["開始時のゲージ", "gauge", false],
				["行動の早まり", "ap_cut", false],
				["土の与ダメージ", "earth_empower", true],
				["バフの速度", "buff_amount", false],
			]
		60:
			return [
				["行動の早まり", "ap_cut", false],
				["開始時の早まり", "start_ap_cut", false],
				["追加の層", "extra_layers", false],
				["与ダメージ", "buff_amount", true],
			]
		79:
			return [
				["水の与ダメージ", "water_empower", true],
				["攻撃後の早まり", "self_ap_cut", false],
				["味方の早まり", "ally_ap_cut", false],
				["バフの速度", "buff_amount", false],
			]
		88:
			return [
				["範囲の与ダメージ", "aoe_bonus", true],
				["ガード無効の回数", "guard_pierce", false],
				["狙われにくさ", "stealth_priority", false],
				["バフの属性耐性", "buff_amount", true],
				["隣の与ダメージ", "neighbor", true],
			]
		104:
			return [
				["上限", "cap_ratio", true],
				["満ちたときの上限", "full_cap_cut", true],
				["狙われやすさ", "gauge_threat", false],
				["開始時のゲージ", "gauge", false],
				["炎のダメージ耐性", "buff_amount", true],
			]
	return []


static func _apply_identity(sheet: Dictionary, unit_id: int) -> void:
	match unit_id:
		2:
			sheet["buff_kind"] = "lowest_speed_speed"
		3:
			sheet["buff_kind"] = "thunder_resist"
			sheet["uses_buff"] = false
		4:
			sheet["buff_kind"] = "highest_attack_absorb"
			sheet["dot_ratio"] = 0.05
		5:
			sheet["buff_kind"] = "highest_cost_fire"
			sheet["gauge"] = 0
		7:
			sheet["buff_kind"] = "ice_resist"
			sheet["uses_buff"] = false
		8:
			sheet["buff_kind"] = "ice_taken"
			sheet["uses_buff"] = false
		9:
			sheet["buff_kind"] = "defense_cut"
			sheet["uses_buff"] = false
		10:
			sheet["buff_kind"] = "absorb_resist"
			sheet["uses_buff"] = false
		11:
			sheet["buff_kind"] = "highest_attack_absorb"
		12:
			sheet["buff_kind"] = "wind_resist"
			sheet["uses_buff"] = false
		13:
			sheet["buff_kind"] = "wind_resist"
			sheet["uses_buff"] = false
		14:
			sheet["buff_kind"] = "water_resist"
			sheet["uses_buff"] = false
		15:
			sheet["buff_kind"] = "thunder_resist"
			sheet["uses_buff"] = false
		16:
			sheet["buff_kind"] = "lowest_attack_water"
		17:
			sheet["buff_kind"] = "highest_attack_thunder"
		18:
			sheet["buff_kind"] = "fire_resist"
			sheet["uses_buff"] = false
		19:
			sheet["buff_kind"] = "highest_attack_fire"
		20:
			sheet["buff_kind"] = "highest_attack_earth"
		21:
			sheet["buff_kind"] = "highest_attack_earth"
			sheet["uses_buff"] = false
		23:
			sheet["buff_kind"] = "highest_attack_thunder"
		24:
			sheet["buff_kind"] = "earth_resist"
			sheet["uses_buff"] = false
		25:
			sheet["buff_kind"] = "highest_attack_wind"
		26:
			sheet["buff_kind"] = "highest_attack_wind"
			sheet["uses_buff"] = false
		27:
			sheet["buff_kind"] = "fire_resist"
			sheet["uses_buff"] = false
		28:
			sheet["buff_kind"] = "highest_attack_water"
			sheet["gauge"] = 0
		29:
			sheet["buff_kind"] = "highest_attack_absorb"
			sheet["uses_buff"] = false
		30:
			sheet["buff_kind"] = "highest_defense"
		31:
			sheet["buff_kind"] = "highest_attack_water"
		32:
			sheet["buff_kind"] = "absorb_taken"
			sheet["uses_buff"] = false
		33:
			sheet["buff_kind"] = "taken_vuln"
			sheet["uses_buff"] = false
		34:
			sheet["buff_kind"] = "highest_attack_ice"
		35:
			sheet["buff_kind"] = "highest_attack_bonus"
			sheet["uses_buff"] = false
			sheet["weight_attack"] = 0
			sheet["weight_buff"] = 0
			sheet["weight_guard"] = 0
			sheet["never_acts"] = true
		36:
			sheet["buff_kind"] = "highest_attack_water"
		6:
			sheet["buff_kind"] = "highest_attack_bonus"
		22:
			sheet["buff_kind"] = "lowest_hp_dot_cut"
			sheet["gauge"] = 0
		42:
			sheet["buff_kind"] = "highest_attack_speed"
		60:
			sheet["buff_kind"] = "highest_attack_bonus"
		79:
			sheet["buff_kind"] = "highest_ap_speed"
			sheet["gauge"] = 0
		88:
			sheet["buff_kind"] = "lowest_defense_resist"
			sheet["gauge"] = 0
		104:
			sheet["buff_kind"] = "fire_resist"
			sheet["uses_buff"] = false
