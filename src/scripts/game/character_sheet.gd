class_name CharacterSheet
extends RefCounted

const SCALE := [1.0, 1.2, 1.5, 1.7]
const ELEMENTS := ["fire", "water", "thunder", "earth", "ice", "wind", "absorb"]


static func make(unit_id: int, stars: int) -> Dictionary:
	var rank := clampi(stars, 1, 4)
	match unit_id:
		1:
			return _akashi(rank)
		2:
			return _asahi(rank)
		3:
			return _ashiya(rank)
		4:
			return _azuchi(rank)
		5:
			return _arita(rank)
		6:
			return _ayakawa(rank)
	return {}


static func _akashi(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [123, -1, -1, -1]),
		"attack": _num(stars, [102, -1, -1, -1]),
		"defense": _num(stars, [242, -1, -1, -1]),
		"speed": _int(stars, [144, -1, -1, -1]),
		"attribute_resist": _pct(stars, [6, -1, -1, -1]),
		"priority": 107,
		"crit_rate": _pct(stars, [-7, -1, -1, -1]),
		"crit_damage": _pct(stars, [-3, -1, -1, -1]),
		"weight_attack": 5,
		"weight_buff": 3,
		"weight_guard": 2,
		"uses_buff": true,
		"element": "fire",
		"element_damage": _elements([0, 21, -24, 26, -27, -24, 28]),
		"element_resist": _elements([0, 24, -19, 19, -32, -24, 32]),
		"buff_kind": "highest_speed_bonus",
		"buff_amount": _pct(stars, [12, 14, 18, 20]),
		"neighbor": _pct(stars, [4, 5, 6, 7]),
		"fire_per_hit": _pct(stars, [8, 10, 12, 14]),
		"fire_cap": _pct(stars, [40, -1, -1, -1]),
		"extra_targets": _int(stars, [1, 1, 2, 2]),
	}


static func _asahi(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [47, -1, -1, -1]),
		"attack": _num(stars, [28, -1, -1, -1]),
		"defense": _num(stars, [248, -1, -1, -1]),
		"speed": _int(stars, [118, -1, -1, -1]),
		"attribute_resist": _pct(stars, [-5, -1, -1, -1]),
		"priority": 107,
		"crit_rate": _pct(stars, [6, -1, -1, -1]),
		"crit_damage": _pct(stars, [-9, -1, -1, -1]),
		"weight_attack": 4,
		"weight_buff": 4,
		"weight_guard": 2,
		"uses_buff": true,
		"element": "ice",
		"element_damage": _elements([-22, -35, 18, 31, 0, 26, -18]),
		"element_resist": _elements([-23, -24, 20, 35, 0, 20, -28]),
		"buff_kind": "lowest_speed_speed",
		"buff_amount": _num(stars, [10, -1, -1, -1]),
		"gauge": _int(stars, [40, -1, -1, -1]),
		"gauge_buff_extra": _int(stars, [10, -1, -1, -1]),
		"ice_empower": _pct(stars, [20, -1, -1, -1]),
		"gauge_speed": _int(stars, [12, 14, 18, 20]),
	}


static func _ashiya(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [279, -1, -1, -1]),
		"attack": _num(stars, [240, -1, -1, -1]),
		"defense": _num(stars, [243, -1, -1, -1]),
		"speed": _int(stars, [152, -1, -1, -1]),
		"attribute_resist": _pct(stars, [8, -1, -1, -1]),
		"priority": 147,
		"crit_rate": _pct(stars, [9, -1, -1, -1]),
		"crit_damage": _pct(stars, [-4, -1, -1, -1]),
		"weight_attack": 5,
		"weight_buff": 2,
		"weight_guard": 3,
		"uses_buff": false,
		"element": "thunder",
		"element_damage": _elements([-20, 19, 0, 30, 26, -37, -18]),
		"element_resist": _elements([-19, 26, 0, 20, 29, -38, -18]),
		"buff_kind": "thunder_resist",
		"buff_amount": _pct(stars, [24, 29, 36, 41]),
		"barrier_max": _int(stars, [80, -1, -1, -1]),
		"priority_bonus": _int(stars, [30, -1, -1, -1]),
		"barrier_damage": _pct(stars, [20, -1, -1, -1]),
		"barrier_speed": _int(stars, [24, 29, 36, 41]),
	}


static func _azuchi(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [291, -1, -1, -1]),
		"attack": _num(stars, [222, -1, -1, -1]),
		"defense": _num(stars, [243, -1, -1, -1]),
		"speed": _int(stars, [165, -1, -1, -1]),
		"attribute_resist": _pct(stars, [-10, -1, -1, -1]),
		"priority": 92,
		"crit_rate": _pct(stars, [7, -1, -1, -1]),
		"crit_damage": _pct(stars, [-7, -1, -1, -1]),
		"weight_attack": 6,
		"weight_buff": 2,
		"weight_guard": 2,
		"uses_buff": true,
		"element": "absorb",
		"element_damage": _elements([25, 25, -28, -27, -20, 25, 0]),
		"element_resist": _elements([19, 21, -23, -21, -31, 35, 0]),
		"buff_kind": "highest_attack_absorb",
		"buff_amount": _pct(stars, [15, 18, 23, 26]),
		"layer_threshold": _int(stars, [3, 3, 2, 2]),
		"extra_layers": _int(stars, [1, 1, 2, 2]),
		"dot_ratio": 0.05,
	}


static func _arita(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [48, -1, -1, -1]),
		"attack": _num(stars, [55, -1, -1, -1]),
		"defense": _num(stars, [258, -1, -1, -1]),
		"speed": _int(stars, [111, -1, -1, -1]),
		"attribute_resist": _pct(stars, [8, -1, -1, -1]),
		"priority": 91,
		"crit_rate": _pct(stars, [0, -1, -1, -1]),
		"crit_damage": _pct(stars, [7, -1, -1, -1]),
		"weight_attack": 5,
		"weight_buff": 4,
		"weight_guard": 1,
		"uses_buff": true,
		"element": "fire",
		"element_damage": _elements([0, -26, -20, 31, 23, 21, -29]),
		"element_resist": _elements([0, -29, -26, 31, 20, 24, -20]),
		"buff_kind": "highest_cost_fire",
		"buff_amount": _pct(stars, [12, 14, 18, 20]),
		"neighbor": _pct(stars, [4, 5, 6, 7]),
		"gauge_step": 10,
	}


static func _ayakawa(stars: int) -> Dictionary:
	return {
		"hp": _int(stars, [189, -1, -1, -1]),
		"attack": _num(stars, [146, -1, -1, -1]),
		"defense": _num(stars, [258, -1, -1, -1]),
		"speed": _int(stars, [141, -1, -1, -1]),
		"attribute_resist": _pct(stars, [-8, -1, -1, -1]),
		"priority": 104,
		"crit_rate": _pct(stars, [6, -1, -1, -1]),
		"crit_damage": _pct(stars, [-3, -1, -1, -1]),
		"weight_attack": 5,
		"weight_buff": 3,
		"weight_guard": 2,
		"uses_buff": true,
		"element": "earth",
		"element_damage": _elements([28, -28, -26, 0, 29, -21, 18]),
		"element_resist": _elements([21, -25, -24, 0, 36, -26, 18]),
		"buff_kind": "highest_attack_bonus",
		"buff_amount": _pct(stars, [15, 18, 23, 26]),
		"neighbor": _pct(stars, [4, 5, 6, 7]),
		"first_bonus": _pct(stars, [30, -1, -1, -1]),
		"earth_vuln": _pct(stars, [20, -1, -1, -1]),
		"slow": _int(stars, [20, -1, -1, -1]),
	}


static func _num(stars: int, row: Array) -> float:
	var index := clampi(stars, 1, 4) - 1
	var value := float(row[index])
	if value < 0.0:
		value = float(row[0]) * SCALE[index]
	return value


static func _int(stars: int, row: Array) -> int:
	return int(round(_num(stars, row)))


static func _pct(stars: int, row: Array) -> float:
	return _num(stars, row) / 100.0


static func _elements(percents: Array) -> Dictionary:
	var result := {}
	for index in ELEMENTS.size():
		result[ELEMENTS[index]] = float(percents[index]) / 100.0
	return result
