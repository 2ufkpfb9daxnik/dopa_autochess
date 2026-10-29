class_name OverflowPile
extends Control

signal unit_drag_started(index: int)
signal unit_drag_finished(index: int, global_position: Vector2)
signal unit_clicked(index: int)

const CARD := Vector2(78.0, 96.0)
const STEP := Vector2(-54.0, -18.0)

var _units: Array = []
var _input_enabled := true
var _pressing := false
var _press_index := -1
var _press_pos := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 35


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled or not _units.is_empty() else Control.MOUSE_FILTER_IGNORE


func set_units(units: Array) -> void:
	_units = units.duplicate()
	visible = not _units.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	_layout_size()
	queue_redraw()


func index_at_global(screen_position: Vector2) -> int:
	return _index_at(get_global_transform_with_canvas().affine_inverse() * screen_position)


func unit_at(index: int) -> GameUnit:
	if index < 0 or index >= _units.size():
		return null
	return _units[index] as GameUnit


func _gui_input(event: InputEvent) -> void:
	if not _input_enabled or _units.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			var index := _index_at(mouse_button.position)
			if index < 0:
				return
			_pressing = true
			_dragging = false
			_press_index = index
			_press_pos = mouse_button.position
			accept_event()
		elif _pressing:
			if _dragging:
				unit_drag_finished.emit(_press_index, mouse_button.global_position)
			else:
				unit_clicked.emit(_press_index)
			_pressing = false
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var mouse_motion := event as InputEventMouseMotion
		if not _dragging and mouse_motion.position.distance_to(_press_pos) > 8.0:
			_dragging = true
			unit_drag_started.emit(_press_index)
		accept_event()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for index in _units.size():
		var unit: GameUnit = _units[index]
		if unit == null or not is_instance_valid(unit):
			continue
		var rect := _card_rect(index)
		draw_rect(rect, Color(0.08, 0.08, 0.1, 0.94))
		draw_rect(rect, Color(0.95, 0.35, 0.28, 0.95), false, 3.0)
		var portrait := Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, rect.size.y - 28))
		_draw_cover(UnitCatalog.get_icon(unit.unit_id), portrait)
		_draw_outlined(font, rect.position + Vector2(4, rect.size.y - 6), unit.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 12, Color(1, 0.92, 0.9))


func _layout_size() -> void:
	if _units.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		return
	var count := _units.size()
	var width := CARD.x + absf(STEP.x) * float(count - 1) + 8.0
	var height := CARD.y + absf(STEP.y) * float(count - 1) + 8.0
	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size


func _card_rect(index: int) -> Rect2:
	var origin := Vector2(size.x - CARD.x - 4.0, size.y - CARD.y - 4.0)
	return Rect2(origin + STEP * float(index), CARD)


func _index_at(local_pos: Vector2) -> int:
	for index in range(_units.size() - 1, -1, -1):
		if _card_rect(index).has_point(local_pos):
			return index
	return -1


func _draw_cover(texture: Texture2D, dest: Rect2) -> void:
	if texture == null:
		return
	var source := UnitCatalog.portrait_source_rect(texture, dest.size)
	draw_texture_rect_region(texture, dest, source)


func _draw_outlined(font: Font, pos: Vector2, text: String, alignment: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	var outline := Color(0, 0, 0, color.a)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + offset, text, alignment, width, font_size, outline)
	draw_string(font, pos, text, alignment, width, font_size, color)
