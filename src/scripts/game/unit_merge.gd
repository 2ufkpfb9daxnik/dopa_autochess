class_name UnitMerge
extends RefCounted

const MAX_STARS := 4


static func try_merge_all(board: BoardController) -> Array[String]:
	var events: Array[String] = []
	while true:
		var message := _try_merge_once(board)
		if message.is_empty():
			break
		events.append(message)
	return events


static func _try_merge_once(board: BoardController) -> String:
	var groups: Dictionary = {}
	for unit in board.get_all_units():
		var key := _group_key(unit.unit_id, unit.stars)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(unit)
	for key in groups:
		var units: Array = groups[key]
		if units.size() < 3:
			continue
		var sample: GameUnit = units[0]
		if sample.stars >= MAX_STARS:
			continue
		var trio: Array[GameUnit] = []
		var sorted := units.duplicate()
		sorted.sort_custom(func(a: GameUnit, b: GameUnit) -> bool:
			return _anchor_priority(a) < _anchor_priority(b)
		)
		for i in 3:
			trio.append(sorted[i])
		return _merge_trio(board, trio)
	return ""


static func _merge_trio(board: BoardController, units: Array[GameUnit]) -> String:
	var anchor: GameUnit = units[0]
	var unit_id := anchor.unit_id
	var old_stars := anchor.stars
	var new_stars := old_stars + 1
	var anchor_cell := anchor.board_hex
	var anchor_bench := anchor.bench_index
	var was_on_board := anchor.is_on_board()
	for i in range(1, units.size()):
		var unit: GameUnit = units[i]
		board.remove_unit(unit)
		unit.queue_free()
	board.remove_unit(anchor)
	anchor.stars = new_stars
	anchor.clear_location()
	anchor.refresh_visuals()
	if was_on_board:
		board.place_on_board(anchor, anchor_cell, false)
	else:
		board.place_on_bench(anchor, anchor_bench, false)
	var name: String = UnitCatalog.get_unit(unit_id)["name"]
	return "%s %s → %s" % [name, _stars_text(old_stars), _stars_text(new_stars)]


static func _anchor_priority(unit: GameUnit) -> int:
	if unit.is_on_board():
		return 0
	return 100 + unit.bench_index


static func _group_key(unit_id: int, stars: int) -> String:
	return "%d_%d" % [unit_id, stars]


static func _stars_text(stars: int) -> String:
	return "★".repeat(stars)
