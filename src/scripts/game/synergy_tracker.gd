class_name SynergyTracker
extends RefCounted


static func count_synergies(units: Array) -> Dictionary:
	var counts: Dictionary = {}
	var counted_unit_ids: Dictionary = {}
	for unit in units:
		if unit == null or not unit is GameUnit:
			continue
		var unit_id: int = unit.unit_id
		if counted_unit_ids.has(unit_id):
			continue
		counted_unit_ids[unit_id] = true
		for synergy_id in UnitCatalog.get_synergies(unit_id):
			counts[synergy_id] = int(counts.get(synergy_id, 0)) + 1
	return counts


static func get_active_synergies(units: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counts := count_synergies(units)
	for synergy_id in counts.keys():
		var count: int = counts[synergy_id]
		var tier: int = SynergyCatalog.get_active_tier(count)
		if tier <= 0:
			continue
		var synergy := SynergyCatalog.get_synergy(int(synergy_id))
		result.append({
			"id": int(synergy_id),
			"name": synergy.get("name", "?"),
			"count": count,
			"tier": tier,
			"tier_threshold": SynergyCatalog.TIERS[tier - 1],
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["tier"] != b["tier"]:
			return a["tier"] > b["tier"]
		return a["count"] > b["count"]
	)
	return result


static func format_synergy_line(entry: Dictionary) -> String:
	return "%s %d (%d体)" % [entry["name"], entry["tier"], entry["count"]]
