class_name BenchBoard
extends Panel

signal unit_drag_started(slot_index: int)
signal unit_drag_moved(global_position: Vector2)
signal unit_drag_finished(slot_index: int, global_position: Vector2)
signal slot_clicked(slot_index: int)

const COLUMNS := 3
const TITLE_TAB_OVERLAP := 8.0
const FRAME_BLEED := 1.16
const BENCH_FRAME := preload("res://images/ui/bench.png")

var _title_tab: Panel
var _count_label: Label
var _slots: Array = []
var _input_enabled := true
var _pressing := false
var _press_slot := -1
var _press_pos := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", style)
	_title_tab = Panel.new()
	_title_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_tab.z_index = 8
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.08, 0.09, 0.12, 0.94)
	tab_style.border_color = Color(0.78, 0.66, 0.32)
	tab_style.set_border_width_all(2)
	tab_style.set_corner_radius_all(8)
	tab_style.corner_radius_top_right = 0
	tab_style.corner_radius_bottom_right = 0
	tab_style.border_width_right = 0
	tab_style.content_margin_left = 2
	tab_style.content_margin_right = 0
	tab_style.content_margin_top = 8
	tab_style.content_margin_bottom = 8
	_title_tab.add_theme_stylebox_override("panel", tab_style)
	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.text = "0/15"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72))
	_title_tab.add_child(_count_label)
	add_child(_title_tab)
	resized.connect(_layout_title_tab)
	_layout_title_tab()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_count(occupied: int, capacity: int) -> void:
	if _count_label == null:
		return
	_count_label.text = "%d/%d" % [occupied, capacity]
	_layout_title_tab()


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
	var text_width := 52.0
	if _count_label != null:
		text_width = maxf(48.0, _count_label.get_minimum_size().x + 12.0)
	var tab_height := 28.0
	_title_tab.position = Vector2(-text_width + TITLE_TAB_OVERLAP, size.y - tab_height - 6.0)
	_title_tab.size = Vector2(text_width, tab_height)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for slot_index in _slots.size():
		var rect := _slot_rect(slot_index)
		var slot: Dictionary = _slots[slot_index]
		var occupied := bool(slot.get("occupied", false))
		var frame := _frame_rect(rect)
		draw_texture_rect(BENCH_FRAME, frame, false, Color.WHITE if occupied else Color(1, 1, 1, 0.72))
		if not occupied:
			continue
		var portrait := _portrait_rect(frame)
		_draw_cover(UnitCatalog.get_icon(int(slot.get("unit_id", -1))), portrait)
		var stars := str(slot.get("stars", ""))
		if not stars.is_empty():
			_draw_outlined(font, portrait.position + Vector2(4.0, 16.0), stars, HORIZONTAL_ALIGNMENT_RIGHT, portrait.size.x - 8.0, 14, Color(1, 0.92, 0.55))
		var cost := int(slot.get("cost", 0))
		if cost > 0:
			_draw_cost_corner(font, portrait, cost)
		_draw_outlined(font, portrait.position + Vector2(4.0, portrait.size.y - 4.0), str(slot.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, portrait.size.x - 8.0, 13, Color(0.96, 0.97, 1))


func _draw_cover(texture: Texture2D, dest: Rect2) -> void:
	var region := UnitCatalog.portrait_source_rect(texture, dest.size)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	draw_texture_rect_region(texture, dest, region)


func _frame_rect(cell: Rect2) -> Rect2:
	var side := maxf(cell.size.x, cell.size.y) * FRAME_BLEED
	return Rect2(cell.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _portrait_rect(frame: Rect2) -> Rect2:
	return Rect2(
		frame.position + frame.size * Vector2(0.12, 0.1),
		frame.size * Vector2(0.76, 0.68)
	)


func _draw_cost_corner(font: Font, portrait: Rect2, cost: int) -> void:
	var leg := minf(portrait.size.x, portrait.size.y) * 0.46
	var origin := portrait.position
	var fill := CostColors.get_color(cost)
	draw_colored_polygon(PackedVector2Array([
		origin,
		origin + Vector2(leg, 0.0),
		origin + Vector2(0.0, leg),
	]), fill)
	draw_line(origin + Vector2(leg, 0.0), origin + Vector2(0.0, leg), Color(0, 0, 0, 0.55), 2.0)
	var font_size := maxi(11, int(leg * 0.34))
	var box := Rect2(origin + Vector2(leg * 0.04, leg * 0.01), Vector2(leg * 0.46, leg * 0.46))
	var text_height := font.get_height(font_size)
	var baseline := box.position.y + font.get_ascent(font_size) + maxf(0.0, (box.size.y - text_height) * 0.5)
	_draw_outlined(font, Vector2(box.position.x, baseline), str(cost), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, font_size, CostColors.get_shop_label_color(cost))


func _draw_outlined(font: Font, pos: Vector2, text: String, alignment: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	var shadow := Color(0, 0, 0, 0.9)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + offset, text, alignment, width, font_size, shadow)
	draw_string(font, pos, text, alignment, width, font_size, color)


func _slot_rect(slot_index: int) -> Rect2:
	var gap := 2.0
	var rows := maxi(1, int(ceil(float(maxi(_slots.size(), 1)) / float(COLUMNS))))
	var cell := minf(
		(size.x - gap * float(COLUMNS - 1)) / float(COLUMNS),
		(size.y - gap * float(rows - 1)) / float(rows)
	)
	var grid := Vector2(cell * float(COLUMNS) + gap * float(COLUMNS - 1), cell * float(rows) + gap * float(rows - 1))
	var origin := (size - grid) * 0.5
	var column := slot_index % COLUMNS
	var row := int(slot_index / COLUMNS)
	return Rect2(origin + Vector2(float(column) * (cell + gap), float(row) * (cell + gap)), Vector2(cell, cell))


func _slot_at(point: Vector2) -> int:
	for slot_index in _slots.size():
		if _slot_rect(slot_index).has_point(point):
			return slot_index
	return -1


func _is_occupied(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size() and bool(_slots[slot_index].get("occupied", false))


func _to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position
