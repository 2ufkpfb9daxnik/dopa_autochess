class_name EnemySpawn
extends RefCounted

const COUNT_BY_STRENGTH: Dictionary = {
	RouteChoice.Strength.WEAK: Vector2i(2, 4),
	RouteChoice.Strength.MEDIUM: Vector2i(3, 6),
	RouteChoice.Strength.STRONG: Vector2i(5, 8),
	RouteChoice.Strength.ELITE: Vector2i(6, 10),
	RouteChoice.Strength.BOSS: Vector2i(8, 13),
}

const STARS_BY_STRENGTH: Dictionary = {
	RouteChoice.Strength.WEAK: Vector2i(1, 1),
	RouteChoice.Strength.MEDIUM: Vector2i(1, 2),
	RouteChoice.Strength.STRONG: Vector2i(2, 2),
	RouteChoice.Strength.ELITE: Vector2i(2, 3),
	RouteChoice.Strength.BOSS: Vector2i(3, 4),
}


static func spawn_for_battle(
	board: BoardController,
	units_root: Node3D,
	round_number: int,
	route: Dictionary
) -> int:
	board.clear_enemy_units()
	var strength: int = int(route.get("strength", RouteChoice.Strength.MEDIUM))
	var count_range: Vector2i = COUNT_BY_STRENGTH.get(strength, Vector2i(3, 5))
	var count := randi_range(count_range.x, count_range.y)
	count = mini(count, HexMath.COLS * HexMath.ROWS)
	var shop_level := clampi(round_number, 1, ShopOdds.TABLE_LEVELS)
	var star_range: Vector2i = STARS_BY_STRENGTH.get(strength, Vector2i(1, 2))
	for cell in _pick_random_cells(count):
		var unit_id := UnitCatalog.random_unit_id_for_level(shop_level)
		var stars := randi_range(star_range.x, star_range.y)
		var unit := GameUnit.create(unit_id, stars)
		unit.is_enemy = true
		units_root.add_child(unit)
		board.place_enemy_unit(unit, cell)
	return count


static func _pick_random_cells(count: int) -> Array[Vector2i]:
	var all_cells: Array[Vector2i] = []
	for row in HexMath.ROWS:
		for col in HexMath.COLS:
			all_cells.append(Vector2i(col, row))
	all_cells.shuffle()
	return all_cells.slice(0, count)
