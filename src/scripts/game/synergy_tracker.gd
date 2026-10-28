class_name SynergyTracker
extends RefCounted


static func names_of(unit_id: int) -> PackedStringArray:
	var profile := CharacterText.load_profile(unit_id)
	var fields: Dictionary = profile.get("fields", {})
	var raw := str(fields.get("シナジー", "")).strip_edges()
	if not raw.is_empty():
		return _split_names(raw)
	var lines := UnitCatalog.get_synergy_lines(unit_id)
	if lines.is_empty():
		return PackedStringArray()
	return lines.split("\n")


static func count_synergies(units: Array) -> Dictionary:
	var counts: Dictionary = {}
	var counted_unit_ids: Dictionary = {}
	for unit in units:
		if unit == null or not unit is GameUnit:
			continue
		var typed: GameUnit = unit
		if typed.is_enemy or typed.unit_id <= 0:
			continue
		if counted_unit_ids.has(typed.unit_id):
			continue
		counted_unit_ids[typed.unit_id] = true
		for synergy_name in names_of(typed.unit_id):
			counts[synergy_name] = int(counts.get(synergy_name, 0)) + 1
	return counts


static func list_synergies(units: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counts := count_synergies(units)
	for synergy_name in counts.keys():
		var count: int = int(counts[synergy_name])
		var data := SynergyCatalog.get_by_name(str(synergy_name))
		var stages: int = SynergyCatalog.stage_count(str(synergy_name))
		var tier: int = SynergyCatalog.reached_index(str(synergy_name), count)
		result.append({
			"name": str(synergy_name),
			"count": count,
			"stage_count": stages,
			"tier": tier,
			"active": tier > 0,
			"summary": str(data.get("summary", "")),
			"stages": data.get("stages", []),
			"color": SynergyCatalog.color_of(str(synergy_name)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["active"]) != bool(b["active"]):
			return bool(a["active"])
		if int(a["tier"]) != int(b["tier"]):
			return int(a["tier"]) > int(b["tier"])
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return str(a["name"]) < str(b["name"])
	)
	return result


static func get_active_synergies(units: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in list_synergies(units):
		if bool(entry["active"]):
			result.append(entry)
	return result


static func bonuses_for(unit: GameUnit, circle_units: Array) -> Dictionary:
	var totals := {
		"hp": 0.0,
		"attack": 0.0,
		"defense": 0.0,
		"speed": 0.0,
		"crit_damage": 0.0,
		"penetration": 0.0,
		"bonus_damage": 0.0,
		"gauge_rate": 0.0,
		"attribute_resist": 0.0,
		"damage_taken": 0.0,
	}
	if unit == null:
		return totals
	var counts := count_synergies(circle_units)
	if unit.is_enemy:
		for synergy_name in counts.keys():
			var effect := SynergyCatalog.active_effect(str(synergy_name), int(counts[synergy_name]))
			var bonus := SynergyCatalog.stat_bonus(effect)
			totals["attribute_resist"] = float(totals["attribute_resist"]) + float(bonus["enemy_resist"])
			totals["damage_taken"] = float(totals["damage_taken"]) + float(bonus["enemy_taken"])
		return totals
	for synergy_name in names_of(unit.unit_id):
		var effect := SynergyCatalog.active_effect(synergy_name, int(counts.get(synergy_name, 0)))
		var bonus := SynergyCatalog.stat_bonus(effect)
		for key in ["hp", "attack", "defense", "speed", "crit_damage", "penetration", "bonus_damage", "gauge_rate"]:
			totals[key] = float(totals[key]) + float(bonus[key])
	return totals


static func _split_names(raw: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for part in raw.replace("、", ",").split(","):
		var synergy_name := part.strip_edges()
		if not synergy_name.is_empty():
			names.append(synergy_name)
	return names
