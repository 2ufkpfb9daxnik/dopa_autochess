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


static func names_for_unit(unit: GameUnit, host_session: GameSession = null) -> PackedStringArray:
	if unit == null:
		return PackedStringArray()
	var names := names_of(unit.unit_id)
	if host_session == null or unit.equipped_relic_uids.is_empty():
		return names
	var seen := {}
	for synergy_name in names:
		seen[synergy_name] = true
	for uid in unit.equipped_relic_uids:
		var data := RelicCatalog.get_relic(host_session.relic_id_of(int(uid)))
		var synergy_name := str(data.get("synergy", "")).strip_edges()
		if synergy_name.is_empty() or seen.has(synergy_name):
			continue
		seen[synergy_name] = true
		names.append(synergy_name)
	return names


static func unit_has_synergy(unit: GameUnit, synergy_name: String, host_session: GameSession = null, exclude_uid: int = -1) -> bool:
	if unit == null or synergy_name.is_empty():
		return false
	for owned in names_of(unit.unit_id):
		if str(owned) == synergy_name:
			return true
	if host_session == null:
		return false
	for uid in unit.equipped_relic_uids:
		if int(uid) == exclude_uid:
			continue
		var data := RelicCatalog.get_relic(host_session.relic_id_of(int(uid)))
		if str(data.get("synergy", "")).strip_edges() == synergy_name:
			return true
	return false


static func count_synergies(units: Array, host_session: GameSession = null) -> Dictionary:
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
		for synergy_name in names_for_unit(typed, host_session):
			counts[synergy_name] = int(counts.get(synergy_name, 0)) + 1
	return counts


static func list_synergies(units: Array, host_session: GameSession = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counts := count_synergies(units, host_session)
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


static func get_active_synergies(units: Array, host_session: GameSession = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in list_synergies(units, host_session):
		if bool(entry["active"]):
			result.append(entry)
	return result


static func bonuses_for(unit: GameUnit, circle_units: Array, host_session: GameSession = null) -> Dictionary:
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
	var counts := count_synergies(circle_units, host_session)
	if unit.is_enemy:
		for synergy_name in counts.keys():
			var effect := SynergyCatalog.active_effect(str(synergy_name), int(counts[synergy_name]))
			var bonus := SynergyCatalog.stat_bonus(effect)
			totals["attribute_resist"] = float(totals["attribute_resist"]) + float(bonus["enemy_resist"])
			totals["damage_taken"] = float(totals["damage_taken"]) + float(bonus["enemy_taken"])
		return totals
	for synergy_name in names_for_unit(unit, host_session):
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
