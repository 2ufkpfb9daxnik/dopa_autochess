class_name UnitCatalog
extends RefCounted

const UNITS: Array[Dictionary] = [
	{"id": 0, "name": "見習い", "cost": 1, "color": Color(0.92, 0.25, 0.25), "synergies": [0]},
	{"id": 1, "name": "槍兵", "cost": 2, "color": Color(0.95, 0.55, 0.12), "synergies": [0, 3]},
	{"id": 2, "name": "魔術師", "cost": 3, "color": Color(0.22, 0.48, 0.95), "synergies": [1]},
	{"id": 3, "name": "重装兵", "cost": 4, "color": Color(0.28, 0.78, 0.38), "synergies": [2, 5]},
	{"id": 4, "name": "暗殺者", "cost": 5, "color": Color(0.58, 0.28, 0.88), "synergies": [4, 6]},
	{"id": 5, "name": "竜騎士", "cost": 6, "color": Color(0.95, 0.86, 0.22), "synergies": [3, 7]},
	{"id": 6, "name": "覇王", "cost": 7, "color": Color(0.18, 0.18, 0.24), "synergies": [6, 0]},
]


static func get_unit(unit_id: int) -> Dictionary:
	return UNITS[unit_id]


static func get_synergies(unit_id: int) -> Array:
	var data := get_unit(unit_id)
	return data.get("synergies", [])


static func get_synergy_names(unit_id: int) -> String:
	var names: PackedStringArray = []
	for synergy_id in get_synergies(unit_id):
		names.append(SynergyCatalog.get_synergy_name(int(synergy_id)))
	return " ".join(names)


static func get_unit_ids_by_cost(cost: int) -> Array[int]:
	var ids: Array[int] = []
	for unit in UNITS:
		if int(unit["cost"]) == cost:
			ids.append(int(unit["id"]))
	return ids


static func get_nearest_cost_with_units(target_cost: int) -> int:
	if get_unit_ids_by_cost(target_cost).size() > 0:
		return target_cost
	for delta in range(1, ShopOdds.MAX_COST + 1):
		if target_cost - delta >= 1 and get_unit_ids_by_cost(target_cost - delta).size() > 0:
			return target_cost - delta
		if get_unit_ids_by_cost(target_cost + delta).size() > 0:
			return target_cost + delta
	return int(UNITS[0]["cost"])


static func random_unit_id_for_level(level: int) -> int:
	var cost := ShopOdds.roll_cost(level)
	var pool := get_unit_ids_by_cost(cost)
	if pool.is_empty():
		pool = get_unit_ids_by_cost(get_nearest_cost_with_units(cost))
	return pool[randi_range(0, pool.size() - 1)]


static func random_unit_id() -> int:
	return random_unit_id_for_level(1)
