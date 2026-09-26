class_name BoardController
extends Node3D

signal units_changed
signal merges_applied(messages: Array[String])

const SLOTS_PER_FACE := 6
const FRONT_COUNT := 3
const BENCH_SIZE := 15
const MAX_FACES := 8

const ALLY_STANDS: Array[Vector3] = [
	Vector3(-0.95, 0.0, 1.05),
	Vector3(0.0, 0.0, 0.55),
	Vector3(0.95, 0.0, 1.05),
]
const ENEMY_STANDS: Array[Vector3] = [
	Vector3(-0.95, 0.0, -1.05),
	Vector3(0.0, 0.0, -0.55),
	Vector3(0.95, 0.0, -1.05),
]
const ALLY_YAW := PI
const ENEMY_YAW := 0.0

var bench_units: Array = []
var board_unit_limit: int = 1
var active_face: int = 0

var _faces: Array = []
var _slot_numbers: Array = []
var _enemy_slots: Array = []
var _unlocked_faces: int = 1
var _in_battle: bool = false
var _visual_shift: float = 0.0


static func unlocked_face_count_for_level(level: int) -> int:
	if level <= 6:
		return 1
	return mini(MAX_FACES, 1 + int((level - 1) / 6))


func _ready() -> void:
	bench_units.resize(BENCH_SIZE)
	bench_units.fill(null)
	_enemy_slots.resize(SLOTS_PER_FACE)
	_enemy_slots.fill(null)
	for _face_index in MAX_FACES:
		_faces.append(_make_face())
		var numbers: Array = []
		numbers.resize(SLOTS_PER_FACE)
		for slot_index in SLOTS_PER_FACE:
			numbers[slot_index] = slot_index + 1
		_slot_numbers.append(numbers)
	_build_stage()


func get_unlocked_face_count() -> int:
	return _unlocked_faces


func set_unlocked_face_count(count: int) -> void:
	var next := clampi(count, 1, MAX_FACES)
	if next == _unlocked_faces:
		return
	_unlocked_faces = next
	if active_face >= _unlocked_faces:
		active_face = _unlocked_faces - 1
	refresh_presentation()
	units_changed.emit()


func cycle_face() -> void:
	if _unlocked_faces <= 1:
		return
	active_face = (active_face + 1) % _unlocked_faces
	refresh_presentation()
	units_changed.emit()


func rotate_active_face(steps: int) -> void:
	var shift := posmod(steps, SLOTS_PER_FACE)
	if shift == 0:
		return
	var face: Array = _faces[active_face]
	var rotated := _make_face()
	for slot_index in SLOTS_PER_FACE:
		var source := posmod(slot_index - shift, SLOTS_PER_FACE)
		var unit: GameUnit = face[source]
		rotated[slot_index] = unit
		if unit != null:
			unit.circle_face = active_face
			unit.circle_slot = slot_index
	var numbers: Array = _slot_numbers[active_face]
	var rotated_numbers: Array = []
	rotated_numbers.resize(SLOTS_PER_FACE)
	for slot_index in SLOTS_PER_FACE:
		var source := posmod(slot_index - shift, SLOTS_PER_FACE)
		rotated_numbers[slot_index] = numbers[source]
	_faces[active_face] = rotated
	_slot_numbers[active_face] = rotated_numbers
	refresh_presentation()
	units_changed.emit()


func set_visual_shift(shift: float) -> void:
	_visual_shift = shift
	refresh_presentation()


func apply_spin_commit(steps: int) -> void:
	_visual_shift = 0.0
	if posmod(steps, SLOTS_PER_FACE) == 0:
		refresh_presentation()
		return
	rotate_active_face(steps)


func get_placed_unit(face_index: int, slot_index: int) -> GameUnit:
	if face_index < 0 or face_index >= _faces.size():
		return null
	if slot_index < 0 or slot_index >= SLOTS_PER_FACE:
		return null
	return _faces[face_index][slot_index]


func get_resolved_unit(face_index: int, slot_index: int) -> GameUnit:
	var placed := get_placed_unit(face_index, slot_index)
	if placed != null:
		return placed
	if face_index <= 0:
		return null
	return get_placed_unit(face_index - 1, slot_index)


func get_wheel_slots() -> Array:
	var result: Array = []
	for slot_index in SLOTS_PER_FACE:
		var placed := get_placed_unit(active_face, slot_index)
		var resolved := get_resolved_unit(active_face, slot_index)
		result.append({
			"occupied": placed != null,
			"fallback": placed == null and resolved != null,
			"name": resolved.get_display_name() if resolved != null else "",
			"stars": resolved.get_star_text() if resolved != null else "",
			"cost": resolved.get_cost() if resolved != null else 0,
			"number": int(_slot_numbers[active_face][slot_index]),
		})
	return result


func get_action_order() -> Array:
	var entries: Array = []
	var seen: Dictionary = {}
	for slot_index in SLOTS_PER_FACE:
		var unit := get_resolved_unit(active_face, slot_index)
		if unit == null or seen.has(unit):
			continue
		seen[unit] = true
		entries.append(_action_entry(unit, false, slot_index < FRONT_COUNT))
	if _in_battle:
		for slot_index in SLOTS_PER_FACE:
			var enemy: GameUnit = _enemy_slots[slot_index]
			if enemy == null:
				continue
			entries.append(_action_entry(enemy, true, slot_index < FRONT_COUNT))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["action_value"]) == int(b["action_value"]):
			return str(a["name"]) < str(b["name"])
		return int(a["action_value"]) < int(b["action_value"])
	)
	return entries


func get_all_units() -> Array[GameUnit]:
	var units: Array[GameUnit] = []
	for face in _faces:
		for unit in face:
			if unit != null:
				units.append(unit)
	for unit in bench_units:
		if unit != null:
			units.append(unit)
	return units


func get_front_unit_count() -> int:
	var count := 0
	for slot_index in FRONT_COUNT:
		if get_placed_unit(active_face, slot_index) != null:
			count += 1
	return count


func get_board_unit_count() -> int:
	var count := 0
	for face in _faces:
		for unit in face:
			if unit != null:
				count += 1
	return count


func get_enemy_unit_count() -> int:
	var count := 0
	for unit in _enemy_slots:
		if unit != null:
			count += 1
	return count


func find_empty_bench_slot() -> int:
	for slot_index in bench_units.size():
		if bench_units[slot_index] == null:
			return slot_index
	return -1


func bench_is_full() -> bool:
	return find_empty_bench_slot() == -1


func find_empty_circle_slot(face_index: int) -> int:
	if face_index < 0 or face_index >= _unlocked_faces:
		return -1
	for slot_index in SLOTS_PER_FACE:
		if _faces[face_index][slot_index] == null:
			return slot_index
	return -1


func place_on_bench(unit: GameUnit, slot_index: int, trigger_merge: bool = true) -> bool:
	if slot_index < 0 or slot_index >= bench_units.size():
		return false
	if bench_units[slot_index] != null:
		return false
	_detach(unit)
	_attach_bench(unit, slot_index)
	if trigger_merge:
		_finish_mutation()
	else:
		refresh_presentation()
		units_changed.emit()
	return true


func place_on_circle(unit: GameUnit, face_index: int, slot_index: int, trigger_merge: bool = true) -> bool:
	if not _can_address(face_index, slot_index):
		return false
	if _faces[face_index][slot_index] != null:
		return false
	_detach(unit)
	_attach_circle(unit, face_index, slot_index)
	if trigger_merge:
		_finish_mutation()
	else:
		refresh_presentation()
	return true


func try_move_unit_to_circle(unit: GameUnit, face_index: int, slot_index: int) -> bool:
	if unit == null or unit.is_enemy or not _can_address(face_index, slot_index):
		return false
	var occupant: GameUnit = _faces[face_index][slot_index]
	if occupant == unit:
		return true
	var from_bench := unit.is_on_bench()
	if occupant == null and from_bench and get_board_unit_count() >= board_unit_limit:
		return false
	var src_face := unit.circle_face
	var src_slot := unit.circle_slot
	var src_bench := unit.bench_index
	_detach(unit)
	if occupant != null:
		_detach(occupant)
	_attach_circle(unit, face_index, slot_index)
	if occupant != null:
		if from_bench:
			_attach_bench(occupant, src_bench)
		else:
			_attach_circle(occupant, src_face, src_slot)
	_finish_mutation()
	return true


func try_move_unit_to_bench(unit: GameUnit, slot_index: int) -> bool:
	if unit == null or unit.is_enemy:
		return false
	if slot_index < 0 or slot_index >= bench_units.size():
		return false
	var occupant: GameUnit = bench_units[slot_index]
	if occupant == unit:
		return true
	var from_circle := unit.is_on_board()
	var src_face := unit.circle_face
	var src_slot := unit.circle_slot
	var src_bench := unit.bench_index
	_detach(unit)
	if occupant != null:
		_detach(occupant)
	_attach_bench(unit, slot_index)
	if occupant != null:
		if from_circle:
			_attach_circle(occupant, src_face, src_slot)
		else:
			_attach_bench(occupant, src_bench)
	_finish_mutation()
	return true


func remove_unit(unit: GameUnit) -> void:
	_detach(unit)
	refresh_presentation()
	units_changed.emit()


func place_enemy_unit(unit: GameUnit, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOTS_PER_FACE:
		return false
	if _enemy_slots[slot_index] != null:
		return false
	unit.is_enemy = true
	unit.circle_face = -1
	unit.circle_slot = slot_index
	unit.bench_index = -1
	_enemy_slots[slot_index] = unit
	refresh_presentation()
	return true


func clear_enemy_units() -> void:
	for unit in _enemy_slots:
		if unit != null and is_instance_valid(unit):
			unit.queue_free()
	for slot_index in _enemy_slots.size():
		_enemy_slots[slot_index] = null
	refresh_presentation()


func set_battle_mode(active: bool) -> void:
	var changed := _in_battle != active
	_in_battle = active
	if changed and not active:
		clear_enemy_units()
		return
	refresh_presentation()


func refresh_presentation() -> void:
	for unit in get_all_units():
		unit.visible = false
		unit.set_battle_walking(false)
	for enemy in _enemy_slots:
		if enemy != null and is_instance_valid(enemy):
			enemy.visible = false
			enemy.set_battle_walking(false)
	if absf(_visual_shift) > 0.001:
		_show_sliding_allies()
	else:
		for slot_index in FRONT_COUNT:
			var ally := get_resolved_unit(active_face, slot_index)
			if ally == null:
				continue
			_show_unit(ally, ALLY_STANDS[slot_index], ALLY_YAW)
	if _in_battle:
		for slot_index in FRONT_COUNT:
			var enemy: GameUnit = _enemy_slots[slot_index]
			if enemy == null:
				continue
			_show_unit(enemy, ENEMY_STANDS[slot_index], ENEMY_YAW)


func _show_unit(unit: GameUnit, stand: Vector3, yaw: float) -> void:
	unit.visible = true
	unit.global_position = stand
	unit.rotation = Vector3(0.0, yaw, 0.0)
	unit.set_battle_walking(_in_battle)


func _show_sliding_allies() -> void:
	var shown: Dictionary = {}
	for slot_index in SLOTS_PER_FACE:
		var ally := get_resolved_unit(active_face, slot_index)
		if ally == null or shown.has(ally):
			continue
		var from_center := wrapf(float(slot_index - 1) + _visual_shift + 3.0, 0.0, 6.0) - 3.0
		if absf(from_center) > 2.35:
			continue
		shown[ally] = true
		var depth := 0.55 + 0.50 * minf(absf(from_center), 1.0)
		_show_unit(ally, Vector3(from_center * 0.95, 0.0, depth), ALLY_YAW)


func _finish_mutation() -> void:
	refresh_presentation()
	units_changed.emit()
	_run_merges()


func _run_merges() -> void:
	var messages := UnitMerge.try_merge_all(self)
	if messages.is_empty():
		return
	refresh_presentation()
	merges_applied.emit(messages)
	units_changed.emit()


func _detach(unit: GameUnit) -> void:
	if unit == null:
		return
	if unit.is_on_board() and get_placed_unit(unit.circle_face, unit.circle_slot) == unit:
		_faces[unit.circle_face][unit.circle_slot] = null
	if unit.is_on_bench() and unit.bench_index < bench_units.size() and bench_units[unit.bench_index] == unit:
		bench_units[unit.bench_index] = null
	unit.clear_location()


func _attach_circle(unit: GameUnit, face_index: int, slot_index: int) -> void:
	_faces[face_index][slot_index] = unit
	unit.circle_face = face_index
	unit.circle_slot = slot_index
	unit.bench_index = -1


func _attach_bench(unit: GameUnit, slot_index: int) -> void:
	bench_units[slot_index] = unit
	unit.bench_index = slot_index
	unit.circle_face = -1
	unit.circle_slot = -1


func _can_address(face_index: int, slot_index: int) -> bool:
	return face_index >= 0 and face_index < _unlocked_faces and slot_index >= 0 and slot_index < SLOTS_PER_FACE


func _make_face() -> Array:
	var slots: Array = []
	slots.resize(SLOTS_PER_FACE)
	slots.fill(null)
	return slots


func _action_entry(unit: GameUnit, enemy: bool, front: bool) -> Dictionary:
	return {
		"name": unit.get_display_name(),
		"stars": unit.get_star_text(),
		"cost": unit.get_cost(),
		"action_value": unit.action_value,
		"enemy": enemy,
		"front": front,
	}


func _build_stage() -> void:
	_add_pad(Vector3(0.0, -0.06, 0.0), Vector3(4.2, 0.08, 3.6), Color(0.14, 0.15, 0.18))
	_add_pad(Vector3(0.0, -0.01, 0.8), Vector3(2.8, 0.04, 1.15), Color(0.22, 0.3, 0.4))
	_add_pad(Vector3(0.0, -0.01, -0.8), Vector3(2.8, 0.04, 1.15), Color(0.38, 0.2, 0.22))


func _add_pad(pad_position: Vector3, pad_size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = pad_size
	mesh_instance.mesh = mesh
	mesh_instance.position = pad_position
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	mesh_instance.material_override = material
	add_child(mesh_instance)
