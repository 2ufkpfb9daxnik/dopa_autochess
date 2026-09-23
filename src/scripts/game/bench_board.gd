class_name BenchBoard
extends Panel

signal unit_drag_started(slot_index: int)
signal unit_drag_moved(global_position: Vector2)
signal unit_drag_finished(slot_index: int, global_position: Vector2)
signal slot_clicked(slot_index: int)

const COLUMNS := 3
const TITLE_TAB_WIDTH := 40.0
const TITLE_TAB_HEIGHT := 92.0
const TITLE_TAB_OVERLAP := 8.0
const PLACEHOLDER_TEXTURE := preload("res://images/placeholder.png")

var _title_tab: Panel
var _slots: Array = []
var _input_enabled := true
var _pressing := false
var _press_slot := -1
var _press_pos := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.94)
	style.border_color = Color(0.78, 0.66, 0.32)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	_title_tab = Panel.new()
	_title_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_tab.z_index = 8
	var tab_style := style.duplicate() as StyleBoxFlat
	tab_style.set_corner_radius_all(8)
	tab_style.corner_radius_top_right = 0
	tab_style.corner_radius_bottom_right = 0
	tab_style.border_width_right = 0
	tab_style.content_margin_left = 2
	tab_style.content_margin_right = 0
	tab_style.content_margin_top = 8
	tab_style.content_margin_bottom = 8
	_title_tab.add_theme_stylebox_override("panel", tab_style)
	var title_box := VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_tab.add_child(title_box)
	for character in "ベンチ":
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = character
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72))
		title_box.add_child(label)
	add_child(_title_tab)
	resized.connect(_layout_title_tab)
	_layout_title_tab()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_slots(slots: Array) -> void:
	_slots = slots
	queue_redraw()


func slot_index_at_global(global_position: Vector2) -> int:
	return _slot_at(_to_local(global_position))


func _gui_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			var slot := _slot_at(mouse_button.position)
			if slot < 0 or not _is_occupied(slot):
				return
			_pressing = true
			_dragging = false
			_press_slot = slot
			_press_pos = mouse_button.position
			accept_event()
		elif _pressing:
			if _dragging:
				unit_drag_finished.emit(_press_slot, mouse_button.global_position)
			else:
				slot_clicked.emit(_press_slot)
			_pressing = false
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var mouse_motion := event as InputEventMouseMotion
		if not _dragging and mouse_motion.position.distance_to(_press_pos) > 8.0:
			_dragging = true
			unit_drag_started.emit(_press_slot)
		if _dragging:
			unit_drag_moved.emit(mouse_motion.global_position)
		accept_event()


func _layout_title_tab() -> void:
	if _title_tab == null:
		return
	_title_tab.position = Vector2(-TITLE_TAB_WIDTH + TITLE_TAB_OVERLAP, size.y - TITLE_TAB_HEIGHT - 6.0)
	_title_tab.size = Vector2(TITLE_TAB_WIDTH, TITLE_TAB_HEIGHT)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for slot_index in _slots.size():
		var rect := _slot_rect(slot_index)
		var slot: Dictionary = _slots[slot_index]
		var occupied := bool(slot.get("occupied", false))
		var cost := int(slot.get("cost", 0))
		var bg := Color(0.13, 0.14, 0.17) if not occupied else Color(0.16, 0.17, 0.2)
		draw_rect(rect, bg)
		var border := Color(0.32, 0.34, 0.38) if not occupied else CostColors.get_color(cost)
		if occupied:
			var image_rect := Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4))
			_draw_cover(PLACEHOLDER_TEXTURE, image_rect)
			var bar_h := minf(22.0, image_rect.size.y * 0.36)
			var bar := Rect2(image_rect.position.x, image_rect.end.y - bar_h, image_rect.size.x, bar_h)
			draw_rect(bar, CostColors.get_color(cost))
			var label_color := CostColors.get_shop_label_color(cost)
			draw_string(font, bar.position + Vector2(2.0, bar_h - 6.0), str(cost), HORIZONTAL_ALIGNMENT_LEFT, 22.0, 14, label_color)
			draw_string(
				font,
				bar.position + Vector2(22.0, bar_h - 6.0),
				str(slot.get("name", "")),
				HORIZONTAL_ALIGNMENT_LEFT,
				bar.size.x - 26.0,
				13,
				label_color
			)
			var stars := str(slot.get("stars", ""))
			if not stars.is_empty():
				draw_string(font, image_rect.position + Vector2(2.0, 16.0), stars, HORIZONTAL_ALIGNMENT_RIGHT, image_rect.size.x - 6.0, 14, Color(1, 0.95, 0.7))
		draw_rect(rect, border, false, 2.0)


func _draw_cover(texture: Texture2D, dest: Rect2) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	var scale := maxf(dest.size.x / tex_size.x, dest.size.y / tex_size.y)
	var crop := dest.size / scale
	var origin := (tex_size - crop) * 0.5
	draw_texture_rect_region(texture, dest, Rect2(origin, crop))


func _slot_rect(slot_index: int) -> Rect2:
	var origin := Vector2(6.0, 6.0)
	var gap := 8.0
	var grid_size := size - origin - Vector2(6.0, 6.0)
	var cell_w := (grid_size.x - gap * float(COLUMNS - 1)) / float(COLUMNS)
	var rows := maxi(1, int(ceil(float(_slots.size()) / float(COLUMNS))))
	var cell_h := (grid_size.y - gap * float(rows - 1)) / float(rows)
	var column := slot_index % COLUMNS
	var row := int(slot_index / COLUMNS)
	return Rect2(
		origin + Vector2(float(column) * (cell_w + gap), float(row) * (cell_h + gap)),
		Vector2(cell_w, cell_h)
	)


func _slot_at(point: Vector2) -> int:
	for slot_index in _slots.size():
		if _slot_rect(slot_index).has_point(point):
			return slot_index
	return -1


func _is_occupied(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size() and bool(_slots[slot_index].get("occupied", false))


func _to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position
