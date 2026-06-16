class_name UnitDragController
extends Node

signal sell_requested(unit: GameUnit)
## sell_zone_side: -1=なし, 0=左, 1=右
signal drag_state_changed(is_dragging: bool, sell_zone_side: int)

const DRAG_LIFT := 0.35

var drag_plane_y: float = 0.4

var _camera: Camera3D
var _board: BoardController
var _dragging_unit: GameUnit = null
var _drag_offset: Vector3 = Vector3.ZERO
var _original_position: Vector3 = Vector3.ZERO
var _sell_zone_checker: Callable = Callable()


func setup(camera: Camera3D, board: BoardController, sell_zone_checker: Callable) -> void:
	_camera = camera
	_board = board
	_sell_zone_checker = sell_zone_checker


func handle_drag_press(screen_pos: Vector2) -> void:
	var hit := _raycast_unit(screen_pos)
	if hit == null:
		return
	_dragging_unit = hit
	_original_position = hit.global_position
	_drag_offset = _world_point_on_plane(screen_pos) - hit.global_position
	_drag_offset.y = 0.0
	drag_state_changed.emit(true, -1)


func handle_drag_move(screen_pos: Vector2) -> void:
	if _dragging_unit == null:
		return
	var world_pos := _world_point_on_plane(screen_pos)
	_dragging_unit.global_position = world_pos - _drag_offset + Vector3(0.0, DRAG_LIFT, 0.0)
	drag_state_changed.emit(true, _get_sell_zone_side(screen_pos))


func handle_drag_release(screen_pos: Vector2, shop_ui_blocks: Callable) -> void:
	if _dragging_unit == null:
		return
	var unit := _dragging_unit
	_dragging_unit = null
	drag_state_changed.emit(false, -1)
	if _get_sell_zone_side(screen_pos) >= 0:
		sell_requested.emit(unit)
		return
	if shop_ui_blocks.call(screen_pos):
		unit.global_position = _original_position
		return
	var drop_pos := _world_point_on_plane(screen_pos)
	if not _board.resolve_drop(unit, drop_pos):
		unit.global_position = _original_position


func is_dragging() -> bool:
	return _dragging_unit != null


func _get_sell_zone_side(screen_pos: Vector2) -> int:
	if not _sell_zone_checker.is_valid():
		return -1
	return _sell_zone_checker.call(screen_pos)


func _raycast_unit(screen_pos: Vector2) -> GameUnit:
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collision_mask = 2
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit.collider
	if collider is GameUnit:
		return collider
	return null


func _world_point_on_plane(screen_pos: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	if is_zero_approx(direction.y):
		return Vector3.ZERO
	var t := (drag_plane_y - origin.y) / direction.y
	return origin + direction * t
