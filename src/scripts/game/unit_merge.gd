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
		var sample: GameUnit = units[0]
		if sample.stars >= MAX_STARS:
			continue
		var session := _session_of(board)
		var oumi_pair := sample.unit_id == 16 and _oumi_pair_ready(board, sample)
		var relic_pair := session != null and RelicEconomy.pair_merge_ready(session) and sample.stars + 1 < MAX_STARS
		var pair := oumi_pair or relic_pair
		var need := 2 if pair else 3
		if units.size() < need:
			continue
		var trio: Array[GameUnit] = []
		var sorted := units.duplicate()
		sorted.sort_custom(func(a: GameUnit, b: GameUnit) -> bool:
			return _anchor_priority(a) < _anchor_priority(b)
		)
		for i in need:
			trio.append(sorted[i])
		return _merge_trio(board, trio, pair, oumi_pair)
	return ""


static func _merge_trio(board: BoardController, units: Array[GameUnit], pair: bool, oumi_pair: bool = false) -> String:
	var anchor: GameUnit = units[0]
	var unit_id := anchor.unit_id
	var old_stars := anchor.stars
	var new_stars := old_stars + 1
	var anchor_face := anchor.circle_face
	var anchor_slot := anchor.circle_slot
	var anchor_bench := anchor.bench_index
	var was_on_board := anchor.is_on_board()
	for i in range(1, units.size()):
		var unit: GameUnit = units[i]
		unit.equipped_relic_uids.clear()
		board.remove_unit(unit)
		unit.queue_free()
	board.remove_unit(anchor)
	anchor.stars = new_stars
	anchor.clear_location()
	anchor.refresh_visuals()
	if was_on_board:
		board.place_on_circle(anchor, anchor_face, anchor_slot, false)
	else:
		board.place_on_bench(anchor, anchor_bench, false)
	var name: String = UnitCatalog.get_unit(unit_id)["name"]
	var session := _session_of(board)
	if session != null:
		var cost := int(UnitCatalog.get_unit(unit_id)["cost"])
		RelicEconomy.note_same_merge(session, unit_id, new_stars, cost)
		RelicEconomy.note_equipped_star(session, anchor)
		if oumi_pair:
			_oumi_note_pair(board, anchor)
		elif pair:
			RelicEconomy.note_pair_merge(session)
	return "%s %s → %s" % [name, _stars_text(old_stars), _stars_text(new_stars)]


static func _deployed_oumi(board: BoardController) -> GameUnit:
	var chosen: GameUnit = null
	for unit in board.get_circle_units():
		if unit == null or unit.unit_id != 16 or unit.is_enemy:
			continue
		if chosen == null or unit.stars > chosen.stars or (unit.stars == chosen.stars and unit.unit_id < chosen.unit_id):
			chosen = unit
	return chosen


static func _oumi_pair_ready(board: BoardController, sample: GameUnit) -> bool:
	if sample == null or sample.unit_id != 16 or sample.stars >= MAX_STARS:
		return false
	var deployed := _deployed_oumi(board)
	if deployed == null:
		return false
	_oumi_ensure_charges(deployed)
	return int(deployed.kit_flags.get("pair_merge_left", 0)) > 0


static func _oumi_ensure_charges(unit: GameUnit) -> void:
	if unit == null:
		return
	if unit.kit_flags.has("pair_merge_left"):
		return
	var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
	unit.kit_flags["pair_merge_left"] = int(sheet.get("pair_merges", 1))


static func _oumi_note_pair(board: BoardController, anchor: GameUnit) -> void:
	var deployed := _deployed_oumi(board)
	if deployed == null:
		deployed = anchor if anchor != null and anchor.unit_id == 16 and anchor.is_on_board() else null
	if deployed == null:
		return
	_oumi_ensure_charges(deployed)
	deployed.kit_flags["pair_merge_left"] = maxi(0, int(deployed.kit_flags.get("pair_merge_left", 0)) - 1)
	if anchor == null or anchor.unit_id != 16:
		return
	var sheet := CharacterSheet.make(anchor.unit_id, anchor.stars)
	var bonus := int(sheet.get("merge_hp", 0))
	if bonus > 0:
		anchor.kit_flags["merge_hp_bonus"] = int(anchor.kit_flags.get("merge_hp_bonus", 0)) + bonus
	# Cap may rise with stars when the deployed Oumi itself ranked up.
	if deployed == anchor:
		var new_cap := int(sheet.get("pair_merges", 1))
		var old_cap_sheet := CharacterSheet.make(anchor.unit_id, maxi(1, anchor.stars - 1))
		var old_cap := int(old_cap_sheet.get("pair_merges", 1))
		var gain := maxi(0, new_cap - old_cap)
		if gain > 0:
			deployed.kit_flags["pair_merge_left"] = int(deployed.kit_flags.get("pair_merge_left", 0)) + gain


static func _anchor_priority(unit: GameUnit) -> int:
	if unit.is_on_board():
		return unit.circle_face * 10 + unit.circle_slot
	return 100 + unit.bench_index


static func _group_key(unit_id: int, stars: int) -> String:
	return "%d_%d" % [unit_id, stars]


static func _stars_text(stars: int) -> String:
	return "★".repeat(stars)


static func _session_of(board: BoardController) -> GameSession:
	if board == null or board.get_parent() == null:
		return null
	return board.get_parent().get("session") as GameSession
