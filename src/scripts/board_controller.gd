class_name BoardController
extends Node3D

signal units_changed
signal merges_applied(messages: Array[String])

const WORLD_OFFSET := Vector3(0.0, 0.0, -5.5)
const BATTLE_FOCUS_SOUTH_OFFSET := 1.35
const BOARD_COUNT_LABEL_NORTH_OFFSET := HexMath.ROW_SPACING * 0.95
const BOARD_COUNT_LABEL_FONT_SIZE := 96

var board_origin: Vector3 = Vector3.ZERO
var board_center_x: float = 0.0
var board_center_z: float = 0.0
var board_max_x: float = 0.0
var bench_min_x: float = 0.0
var bench_max_x: float = 0.0
var board_units: Dictionary = {}
var enemy_units: Dictionary = {}
var bench_units: Array = []
var board_unit_limit: int = 1

var _bench_markers: Array[MeshInstance3D] = []
var _hex_markers: Array[MeshInstance3D] = []
var _enemy_hex_markers: Array[MeshInstance3D] = []
var _board_count_label: Label3D
var _in_battle: bool = false


func _ready() -> void:
	position = WORLD_OFFSET
	bench_units.resize(HexMath.BENCH_SIZE)
	bench_units.fill(null)
	_build_visuals()


func _build_visuals() -> void:
	board_origin = _compute_board_origin()
	var extents := HexMath.compute_board_extents(board_origin)
	board_center_x = extents["center_x"]
	board_center_z = extents["center_z"]
	board_max_x = extents["max_x"]
	_cache_bench_extents()
	_build_hex_tiles(false, board_origin, _hex_markers)
	_build_bench_slots()
	_build_board_count_label()


func _cache_bench_extents() -> void:
	bench_min_x = INF
	bench_max_x = -INF
	for slot in HexMath.BENCH_SIZE:
		var pos := HexMath.bench_slot_to_local(slot, board_max_x, board_center_z)
		bench_min_x = minf(bench_min_x, pos.x)
		bench_max_x = maxf(bench_max_x, pos.x)


func _compute_board_origin() -> Vector3:
	var min_pos := Vector3(INF, 0.0, INF)
	var max_pos := Vector3(-INF, 0.0, -INF)
	for row in HexMath.ROWS:
		for col in HexMath.COLS:
			var local := HexMath.cell_to_local(col, row)
			min_pos.x = minf(min_pos.x, local.x)
			min_pos.z = minf(min_pos.z, local.z)
			max_pos.x = maxf(max_pos.x, local.x)
			max_pos.z = maxf(max_pos.z, local.z)
	return Vector3(-(min_pos.x + max_pos.x) * 0.5, 0.0, -(min_pos.z + max_pos.z) * 0.5)


func _build_hex_tiles(enemy: bool, origin: Vector3, storage: Array) -> void:
	for row in HexMath.ROWS:
		for col in HexMath.COLS:
			var grid_row := HexMath.enemy_global_row(row) if enemy else row
			var tile := _create_hex_tile(HexMath.is_light_hex(col, grid_row), enemy)
			if enemy:
				tile.position = HexMath.enemy_cell_to_world(col, row, origin)
			else:
				tile.position = HexMath.cell_to_world(col, row, origin)
			tile.name = ("EnemyHex" if enemy else "Hex") + "_%d_%d" % [col, row]
			add_child(tile)
			storage.append(tile)


func _build_bench_slots() -> void:
	for slot in HexMath.BENCH_SIZE:
		var marker := _create_bench_slot()
		marker.position = _bench_local_pos(slot)
		marker.name = "BenchSlot_%d" % slot
		add_child(marker)
		_bench_markers.append(marker)


func _build_board_count_label() -> void:
	_board_count_label = Label3D.new()
	_board_count_label.name = "BoardCountLabel"
	_board_count_label.font_size = BOARD_COUNT_LABEL_FONT_SIZE
	_board_count_label.outline_size = 14
	_board_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_board_count_label.text = "0/1"
	var extents := HexMath.compute_board_extents(board_origin)
	_board_count_label.position = Vector3(
		extents["center_x"],
		0.45,
		float(extents["min_z"]) - BOARD_COUNT_LABEL_NORTH_OFFSET
	)
	add_child(_board_count_label)


func set_board_count_display(count: int, cap: int) -> void:
	if _board_count_label == null:
		return
	_board_count_label.text = "%d/%d" % [count, cap]


func _bench_local_pos(slot_index: int) -> Vector3:
	return HexMath.bench_slot_to_local(slot_index, board_max_x, board_center_z)


func _create_hex_tile(is_light: bool, enemy: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = HexMath.HEX_SIZE
	mesh.bottom_radius = HexMath.HEX_SIZE
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.05
	var material := StandardMaterial3D.new()
	if enemy:
		material.albedo_color = Color(0.42, 0.22, 0.24) if is_light else Color(0.34, 0.18, 0.2)
	else:
		material.albedo_color = Color(0.28, 0.34, 0.42) if is_light else Color(0.22, 0.27, 0.34)
	mesh_instance.material_override = material
	return mesh_instance


func _create_bench_slot() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(HexMath.HORIZONTAL_SPACING * 0.88, 0.06, HexMath.ROW_SPACING * 0.88)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.03
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.22, 0.28, 0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	return mesh_instance


func set_battle_mode(active: bool) -> void:
	if _in_battle == active:
		return
	_in_battle = active
	if active:
		var enemy_origin := HexMath.get_enemy_board_origin(board_origin)
		_build_hex_tiles(true, enemy_origin, _enemy_hex_markers)
	else:
		_clear_enemy_tiles()
		clear_enemy_units()


func _clear_enemy_tiles() -> void:
	for tile in _enemy_hex_markers:
		tile.queue_free()
	_enemy_hex_markers.clear()


func get_hex_board_center() -> Vector3:
	return global_position + Vector3(board_center_x, 0.0, board_center_z)


func get_camera_focus_prep() -> Vector3:
	return get_hex_board_center()


func get_prep_framing() -> Dictionary:
	var hex := HexMath.compute_board_extents(board_origin)
	var hex_min_x: float = float(hex["min_x"])
	var hex_min_z: float = float(hex["min_z"])
	var hex_max_z: float = float(hex["max_z"])
	var left_extent: float = board_center_x - hex_min_x + HexMath.HORIZONTAL_SPACING * 3.5
	var right_extent: float = bench_max_x - board_center_x + HexMath.HORIZONTAL_SPACING * 1.5
	var vertical_half: float = (hex_max_z - hex_min_z) * 0.5 + HexMath.HEX_SIZE * 2.0
	return {
		"focus": get_hex_board_center(),
		"horizontal_half": maxf(left_extent, right_extent),
		"vertical_half": vertical_half,
	}


func get_camera_focus_battle() -> Vector3:
	var player_extents := HexMath.compute_board_extents(board_origin)
	var enemy_origin := HexMath.get_enemy_board_origin(board_origin)
	var enemy_extents := HexMath.compute_enemy_board_extents(enemy_origin)
	var center_z: float = (float(player_extents["center_z"]) + float(enemy_extents["center_z"])) * 0.5
	center_z += BATTLE_FOCUS_SOUTH_OFFSET
	return global_position + Vector3(board_center_x, 0.0, center_z)


func get_battle_board_span() -> float:
	var player_extents := HexMath.compute_board_extents(board_origin)
	var enemy_origin := HexMath.get_enemy_board_origin(board_origin)
	var enemy_extents := HexMath.compute_enemy_board_extents(enemy_origin)
	return float(player_extents["max_z"]) - float(enemy_extents["min_z"]) + HexMath.HEX_SIZE * 2.0


func compute_prep_camera_position(
	focus: Vector3,
	horizontal_half: float,
	vertical_half: float,
	fov_deg: float,
	aspect: float
) -> Vector3:
	var fov_v_rad := deg_to_rad(fov_deg)
	var tan_v_half := tan(fov_v_rad * 0.5)
	var tan_h_half := tan_v_half * maxf(aspect, 0.01)
	var dist_for_height := vertical_half / tan_v_half
	var dist_for_width := horizontal_half / tan_h_half
	var distance := maxf(dist_for_height, dist_for_width) * 1.25
	var height := distance * 0.62
	var back := distance * 0.52
	return Vector3(focus.x, focus.y + height, focus.z + back)


func compute_camera_position(focus: Vector3, vertical_span: float, fov_deg: float) -> Vector3:
	var margin := HexMath.HEX_SIZE * 1.8
	var half_span := vertical_span * 0.5 + margin
	var fov_rad := deg_to_rad(fov_deg)
	var distance := half_span / tan(fov_rad * 0.5)
	var height := distance * 0.72
	var back := distance * 0.42
	return Vector3(focus.x, focus.y + height, focus.z + back)


func get_all_units() -> Array[GameUnit]:
	var units: Array[GameUnit] = []
	for unit in board_units.values():
		units.append(unit)
	for unit in bench_units:
		if unit != null:
			units.append(unit)
	return units


func get_enemy_unit_global_pos(cell: Vector2i) -> Vector3:
	var enemy_origin := HexMath.get_enemy_board_origin(board_origin)
	return to_global(HexMath.enemy_cell_to_world(cell.x, cell.y, enemy_origin))


func get_enemy_unit_count() -> int:
	return enemy_units.size()


func place_enemy_unit(unit: GameUnit, cell: Vector2i) -> bool:
	if not HexMath.is_in_bounds(cell):
		return false
	if enemy_units.has(cell):
		return false
	unit.clear_location()
	unit.is_enemy = true
	unit.board_hex = cell
	enemy_units[cell] = unit
	unit.global_position = get_enemy_unit_global_pos(cell)
	if unit.is_node_ready():
		unit.refresh_visuals()
	return true


func clear_enemy_units() -> void:
	for unit in enemy_units.values():
		if is_instance_valid(unit):
			unit.queue_free()
	enemy_units.clear()


func get_board_world_pos(cell: Vector2i) -> Vector3:
	return HexMath.cell_to_world(cell.x, cell.y, board_origin)


func get_unit_global_pos(cell: Vector2i) -> Vector3:
	return to_global(get_board_world_pos(cell))


func get_bench_global_pos(slot_index: int) -> Vector3:
	return to_global(_bench_local_pos(slot_index))


func has_unit_on_board(cell: Vector2i) -> bool:
	return board_units.has(cell)


func find_empty_bench_slot() -> int:
	for slot in bench_units.size():
		if bench_units[slot] == null:
			return slot
	return -1


func bench_is_full() -> bool:
	return find_empty_bench_slot() == -1


func get_board_unit_count() -> int:
	return board_units.size()


func place_on_board(unit: GameUnit, cell: Vector2i, trigger_merge: bool = true) -> bool:
	if not HexMath.is_in_bounds(cell):
		return false
	if board_units.has(cell):
		return false
	if not unit.is_on_board() and board_units.size() >= board_unit_limit:
		return false
	_remove_unit_from_current_location(unit)
	unit.clear_location()
	unit.board_hex = cell
	board_units[cell] = unit
	unit.global_position = get_unit_global_pos(cell)
	units_changed.emit()
	if trigger_merge:
		_run_merges()
	return true


func place_on_bench(unit: GameUnit, slot_index: int, trigger_merge: bool = true) -> bool:
	if slot_index < 0 or slot_index >= bench_units.size():
		return false
	if bench_units[slot_index] != null:
		return false
	_remove_unit_from_current_location(unit)
	unit.clear_location()
	unit.bench_index = slot_index
	bench_units[slot_index] = unit
	unit.global_position = get_bench_global_pos(slot_index)
	units_changed.emit()
	if trigger_merge:
		_run_merges()
	return true


func remove_unit(unit: GameUnit) -> void:
	_remove_unit_from_current_location(unit)
	unit.clear_location()
	units_changed.emit()


func swap_board_cells(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not board_units.has(from_cell):
		return
	var moving: GameUnit = board_units[from_cell]
	board_units.erase(from_cell)
	moving.board_hex = Vector2i(-1, -1)
	if board_units.has(to_cell):
		var other: GameUnit = board_units[to_cell]
		board_units.erase(to_cell)
		other.board_hex = from_cell
		board_units[from_cell] = other
		other.global_position = get_unit_global_pos(from_cell)
	moving.board_hex = to_cell
	board_units[to_cell] = moving
	moving.global_position = get_unit_global_pos(to_cell)
	units_changed.emit()
	_run_merges()


func move_board_to_bench(from_cell: Vector2i, slot_index: int) -> bool:
	if not board_units.has(from_cell):
		return false
	if bench_units[slot_index] != null:
		return false
	var unit: GameUnit = board_units[from_cell]
	board_units.erase(from_cell)
	unit.board_hex = Vector2i(-1, -1)
	unit.bench_index = slot_index
	bench_units[slot_index] = unit
	unit.global_position = get_bench_global_pos(slot_index)
	units_changed.emit()
	_run_merges()
	return true


func move_bench_to_board(slot_index: int, cell: Vector2i) -> bool:
	if bench_units[slot_index] == null:
		return false
	if not HexMath.is_in_bounds(cell):
		return false
	if board_units.has(cell):
		return false
	if board_units.size() >= board_unit_limit:
		return false
	var unit: GameUnit = bench_units[slot_index]
	bench_units[slot_index] = null
	unit.bench_index = -1
	unit.board_hex = cell
	board_units[cell] = unit
	unit.global_position = get_unit_global_pos(cell)
	units_changed.emit()
	_run_merges()
	return true


func resolve_drop(unit: GameUnit, world_pos: Vector3) -> bool:
	var hex_origin := global_position + board_origin
	var cell := HexMath.world_to_cell(world_pos, hex_origin)
	if HexMath.is_in_bounds(cell):
		return _drop_on_board(unit, cell)
	var bench_slot := HexMath.nearest_bench_slot(
		world_pos,
		global_position,
		board_max_x,
		board_center_z
	)
	if bench_slot >= 0:
		return _drop_on_bench(unit, bench_slot)
	return false


func _drop_on_board(unit: GameUnit, cell: Vector2i) -> bool:
	if unit.is_on_board() and unit.board_hex == cell:
		unit.global_position = get_unit_global_pos(cell)
		return true
	if unit.is_on_board():
		if has_unit_on_board(cell):
			swap_board_cells(unit.board_hex, cell)
			return true
		board_units.erase(unit.board_hex)
		unit.board_hex = cell
		board_units[cell] = unit
		unit.global_position = get_unit_global_pos(cell)
		units_changed.emit()
		_run_merges()
		return true
	if unit.is_on_bench():
		return move_bench_to_board(unit.bench_index, cell)
	return place_on_board(unit, cell)


func _drop_on_bench(unit: GameUnit, slot_index: int) -> bool:
	if unit.is_on_bench() and unit.bench_index == slot_index:
		unit.global_position = get_bench_global_pos(slot_index)
		return true
	if unit.is_on_bench():
		if bench_units[slot_index] != null:
			return false
		bench_units[unit.bench_index] = null
		unit.bench_index = slot_index
		bench_units[slot_index] = unit
		unit.global_position = get_bench_global_pos(slot_index)
		units_changed.emit()
		_run_merges()
		return true
	if unit.is_on_board():
		return move_board_to_bench(unit.board_hex, slot_index)
	return place_on_bench(unit, slot_index)


func _run_merges() -> void:
	var messages := UnitMerge.try_merge_all(self)
	if not messages.is_empty():
		merges_applied.emit(messages)


func _remove_unit_from_current_location(unit: GameUnit) -> void:
	if unit.is_on_board() and board_units.get(unit.board_hex) == unit:
		board_units.erase(unit.board_hex)
	if unit.is_on_bench() and unit.bench_index >= 0 and bench_units[unit.bench_index] == unit:
		bench_units[unit.bench_index] = null
