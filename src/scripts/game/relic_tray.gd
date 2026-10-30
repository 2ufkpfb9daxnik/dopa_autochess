class_name RelicTray
extends Control

signal clicked(uid: int)
signal drag_finished(uid: int, global_position: Vector2)

const ICON := 54.0
const GAP := 8.0

var _entries: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _origin := Vector2.ZERO
var _limit := Vector2.ZERO
var _obstacle := Rect2()
var _drag_uid := -1
var _pending_uid := -1
var _press_pos := Vector2.ZERO
var _drag_moved := false
var _ghost: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	_ghost = TextureRect.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.visible = false
	_ghost.z_index = 40
	_ghost.top_level = true
	add_child(_ghost)


func set_entries(entries: Array) -> void:
	_entries.clear()
	for item in entries:
		if not (item is Dictionary):
			continue
		var relic_id: int = int(item.get("id", -1))
		var uid: int = int(item.get("uid", -1))
		if relic_id <= 0 or uid < 0:
			continue
		_entries.append(item)
	_rebuild()


func set_layout(origin: Vector2, limit: Vector2, obstacle: Rect2) -> void:
	_origin = origin
	_limit = limit
	_obstacle = obstacle
	_place()


func uid_at(global_position: Vector2) -> int:
	for index in _buttons.size():
		var button := _buttons[index]
		if button.visible and button.get_global_rect().has_point(global_position):
			return int(_entries[index].get("uid", -1))
	return -1


func begin_drag(uid: int) -> void:
	_drag_uid = uid
	var relic_id := _id_of(uid)
	_ghost.texture = RelicCatalog.get_icon(relic_id)
	_ghost.size = Vector2(ICON, ICON)
	_ghost.visible = relic_id > 0
	_follow_ghost()


func _plate_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.08, 0.08, 0.08)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	return style


func _rebuild() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for index in _entries.size():
		var relic_id := int(_entries[index].get("id", -1))
		var uid := int(_entries[index].get("uid", -1))
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(ICON, ICON)
		var plate := _plate_style(Color(0.96, 0.96, 0.96))
		button.add_theme_stylebox_override("normal", plate)
		button.add_theme_stylebox_override("hover", _plate_style(Color(0.86, 0.86, 0.86)))
		button.add_theme_stylebox_override("pressed", _plate_style(Color(0.74, 0.74, 0.74)))
		button.add_theme_stylebox_override("focus", plate)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = RelicCatalog.get_icon(relic_id)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5.0
		icon.offset_top = 5.0
		icon.offset_right = -5.0
		icon.offset_bottom = -5.0
		button.add_child(icon)
		button.pressed.connect(_on_pressed.bind(uid))
		button.button_down.connect(_on_down.bind(uid))
		add_child(button)
		_buttons.append(button)
	_place()


func _place() -> void:
	if _buttons.is_empty():
		return
	var cursor := _origin
	for button in _buttons:
		var rect := _next_rect(cursor)
		button.position = rect.position
		button.size = rect.size
		cursor = Vector2(rect.position.x, rect.end.y + GAP)
		if cursor.y + ICON > _limit.y:
			cursor = Vector2(rect.end.x + GAP, _origin.y)


func _next_rect(cursor: Vector2) -> Rect2:
	var point := cursor
	for _step in 48:
		if point.y + ICON > _limit.y:
			point = Vector2(point.x + ICON + GAP, _origin.y)
		var rect := Rect2(point, Vector2(ICON, ICON))
		if _obstacle.size.x > 1.0 and _obstacle.grow(6.0).intersects(rect):
			point = Vector2(_obstacle.end.x + GAP, _origin.y)
			continue
		return rect
	return Rect2(point, Vector2(ICON, ICON))


func _on_pressed(uid: int) -> void:
	if _drag_moved:
		_drag_moved = false
		return
	clicked.emit(uid)


func _on_down(uid: int) -> void:
	_pending_uid = uid
	_press_pos = get_viewport().get_mouse_position()
	_drag_moved = false


func _id_of(uid: int) -> int:
	for item in _entries:
		if int(item.get("uid", -1)) == uid:
			return int(item.get("id", -1))
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _pending_uid >= 0 and _drag_uid < 0:
		if get_viewport().get_mouse_position().distance_to(_press_pos) > 8.0:
			_drag_moved = true
			begin_drag(_pending_uid)
	if _drag_uid < 0:
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_pending_uid = -1
		return
	if event is InputEventMouseMotion:
		_follow_ghost()
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var uid := _drag_uid
		var at := (event as InputEventMouseButton).global_position
		_drag_uid = -1
		_pending_uid = -1
		_ghost.visible = false
		drag_finished.emit(uid, at)


func _follow_ghost() -> void:
	if _ghost == null or not _ghost.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	_ghost.global_position = mouse - _ghost.size * 0.5
