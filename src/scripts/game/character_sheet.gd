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
		6:
			return [
				["最初の与ダメージ", "first_bonus", true],
				["土の被ダメージ", "earth_vuln", true],
				["速度の低下", "slow", false],
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
			sheet["gauge_step"] = 10
		6:
			sheet["buff_kind"] = "highest_attack_bonus"
		104:
			sheet["buff_kind"] = "fire_resist"
			sheet["uses_buff"] = false
