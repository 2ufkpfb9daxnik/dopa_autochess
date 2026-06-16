class_name HexMath
extends RefCounted

const HEX_SIZE := 0.85
const COLS := 9
const ROWS := 5
const BENCH_COLS := 3
const BENCH_ROWS := 5
const BENCH_SIZE := BENCH_COLS * BENCH_ROWS

const HORIZONTAL_SPACING := HEX_SIZE * sqrt(3.0)
const ROW_SPACING := HEX_SIZE * 1.5


static func cell_to_local(col: int, row: int) -> Vector3:
	var x := HORIZONTAL_SPACING * (float(col) + 0.5 * float(row & 1))
	var z := ROW_SPACING * float(row)
	return Vector3(x, 0.0, z)


static func cell_to_world(col: int, row: int, origin: Vector3) -> Vector3:
	return origin + cell_to_local(col, row)


static func enemy_global_row(local_row: int) -> int:
	# プレイヤー row0 の上に row -1, -2, … と続く1枚のグリッドとして配置
	return -(local_row + 1)


static func enemy_cell_to_local(col: int, row: int) -> Vector3:
	return cell_to_local(col, enemy_global_row(row))


static func enemy_cell_to_world(col: int, row: int, origin: Vector3) -> Vector3:
	return origin + enemy_cell_to_local(col, row)


static func is_light_hex(col: int, row: int) -> bool:
	return (col + row) % 2 == 0


static func world_to_cell(world_pos: Vector3, origin: Vector3) -> Vector2i:
	var local := world_pos - origin
	var best_cell := Vector2i(-1, -1)
	var best_dist := INF
	for row in ROWS:
		for col in COLS:
			var cell_local := cell_to_local(col, row)
			var dist := Vector2(local.x - cell_local.x, local.z - cell_local.z).length()
			if dist < best_dist:
				best_dist = dist
				best_cell = Vector2i(col, row)
	if best_dist > HEX_SIZE * 0.9:
		return Vector2i(-1, -1)
	return best_cell


static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


static func compute_board_extents(origin: Vector3) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for row in ROWS:
		for col in COLS:
			var world := cell_to_world(col, row, origin)
			min_x = minf(min_x, world.x)
			max_x = maxf(max_x, world.x)
			min_z = minf(min_z, world.z)
			max_z = maxf(max_z, world.z)
	return {
		"center_x": (min_x + max_x) * 0.5,
		"center_z": (min_z + max_z) * 0.5,
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
	}


static func compute_enemy_board_extents(origin: Vector3) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for row in ROWS:
		for col in COLS:
			var world := enemy_cell_to_world(col, row, origin)
			min_x = minf(min_x, world.x)
			max_x = maxf(max_x, world.x)
			min_z = minf(min_z, world.z)
			max_z = maxf(max_z, world.z)
	return {
		"center_x": (min_x + max_x) * 0.5,
		"center_z": (min_z + max_z) * 0.5,
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
	}


static func bench_slot_to_local(slot_index: int, board_max_x: float, board_center_z: float) -> Vector3:
	var col: int = slot_index % BENCH_COLS
	var row: int = int(slot_index / BENCH_COLS)
	var x := board_max_x + HORIZONTAL_SPACING * 1.35 + float(col) * HORIZONTAL_SPACING * 0.92
	var z := board_center_z + (float(row) - 2.0) * ROW_SPACING
	return Vector3(x, 0.0, z)


static func bench_slot_to_world(
	slot_index: int,
	board_global: Vector3,
	board_max_x: float,
	board_center_z: float
) -> Vector3:
	return board_global + bench_slot_to_local(slot_index, board_max_x, board_center_z)


static func nearest_bench_slot(
	world_pos: Vector3,
	board_global: Vector3,
	board_max_x: float,
	board_center_z: float
) -> int:
	var best_slot := -1
	var best_dist := INF
	for slot in BENCH_SIZE:
		var slot_pos := bench_slot_to_world(slot, board_global, board_max_x, board_center_z)
		var dist := Vector2(world_pos.x - slot_pos.x, world_pos.z - slot_pos.z).length()
		if dist < best_dist:
			best_dist = dist
			best_slot = slot
	if best_dist > HEX_SIZE * 0.85:
		return -1
	return best_slot


static func get_enemy_board_origin(player_origin: Vector3) -> Vector3:
	# 敵盤面は同一 origin 上の連続グリッド（row -1 から）
	return player_origin
