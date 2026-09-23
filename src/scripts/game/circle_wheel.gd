class_name CircleWheel
extends Control

signal rotate_steps(steps: int)
signal visual_shift_changed(shift: float)
signal center_pressed
signal unit_drag_started(slot_index: int)
signal unit_drag_moved(global_position: Vector2)
signal unit_drag_finished(slot_index: int, global_position: Vector2)
signal slot_move_requested(from_slot: int, to_slot: int)

const PLACEHOLDER_TEXTURE := preload("res://images/placeholder.png")
const _MODE_NONE := 0
const _MODE_ROTATE := 1
const _MODE_UNIT := 2

var _view_slots: Array = []
var _occupied: Array[bool] = []
var _center_label: Label
var _ccw_button: Button
var _cw_button: Button
var _unit_drag_enabled := true
var _pressing := false
var _press_slot := -1
var _press_pos := Vector2.ZERO
var _last_angle := 0.0
var _accum := 0.0
var _mode := _MODE_NONE
var _visual_angle := 0.0
var _spin_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center_label = Label.new()
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 14)
	_center_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
	add_child(_center_label)
	_ccw_button = _make_rotate_button("↙", -1)
	_cw_button = _make_rotate_button("↘", 1)
	resized.connect(_layout_chrome)
	_layout_chrome()


func set_unit_drag_enabled(enabled: bool) -> void:
	_unit_drag_enabled = enabled


func set_interaction_enabled(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _ccw_button == null:
		return
	_ccw_button.disabled = not enabled
	_cw_button.disabled = not enabled
	_ccw_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_cw_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_view(center_text: String, slots: Array) -> void:
	_center_label.text = center_text
	_view_slots = slots
	_occupied.clear()
	for slot in slots:
		_occupied.append(bool(slot.get("occupied", false)))
	queue_redraw()


func slot_index_at_global(global_position: Vector2) -> int:
	return _slot_at(_to_local(global_position))


func _make_rotate_button(label_text: String, steps: int) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(46, 46)
	var arrow_font := SystemFont.new()
	arrow_font.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI", "Yu Gothic UI"])
	button.add_theme_font_override("font", arrow_font)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(func() -> void: _animate_steps(steps))
	add_child(button)
	return button


func _layout_chrome() -> void:
	if _center_label == null:
		return
	var inner := _inner_radius()
	_center_label.size = Vector2(inner * 1.7, inner * 1.15)
	_center_label.position = _center() - _center_label.size * 0.5
	var button_size := Vector2(46, 46)
	_ccw_button.position = _center() + Vector2(cos(-PI * 0.75), sin(-PI * 0.75)) * (_outer_radius() + 24.0) - button_size * 0.5
	_cw_button.position = _center() + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * (_outer_radius() + 24.0) - button_size * 0.5
	_ccw_button.size = button_size
	_cw_button.size = button_size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_begin_press(mouse_button)
		else:
			_end_press(mouse_button)
	elif event is InputEventMouseMotion and _pressing:
		_drag_motion(event as InputEventMouseMotion)


func _begin_press(mouse_button: InputEventMouseButton) -> void:
	_commit_spin_now()
	if _is_center(mouse_button.position):
		center_pressed.emit()
		accept_event()
		return
	var slot := _slot_at(mouse_button.position)
	if slot < 0 and not _is_ring(mouse_button.position):
		return
	_pressing = true
	_press_slot = slot
	_press_pos = mouse_button.position
	_last_angle = _angle_at(mouse_button.position)
	_accum = 0.0
	_mode = _MODE_NONE
	accept_event()


func _end_press(mouse_button: InputEventMouseButton) -> void:
	if not _pressing:
		return
	if _mode == _MODE_UNIT:
		unit_drag_finished.emit(_press_slot, mouse_button.global_position)
	elif _mode == _MODE_ROTATE:
		_animate_to_nearest_step()
	elif _mode == _MODE_NONE and _unit_drag_enabled:
		var release_slot := _slot_at(mouse_button.position)
		if _press_slot >= 0 and release_slot >= 0 and release_slot != _press_slot and _is_occupied(_press_slot):
			slot_move_requested.emit(_press_slot, release_slot)
	_pressing = false
	_mode = _MODE_NONE
	accept_event()


func _drag_motion(mouse_motion: InputEventMouseMotion) -> void:
	var delta := wrapf(_angle_at(mouse_motion.position) - _last_angle, -PI, PI)
	_last_angle = _angle_at(mouse_motion.position)
	_accum += delta
	if _mode == _MODE_NONE:
		var travel := mouse_motion.position.distance_to(_press_pos)
		var dist := mouse_motion.position.distance_to(_center())
		if absf(_accum) > 0.28:
			_mode = _MODE_ROTATE
		elif _unit_drag_enabled and _press_slot >= 0 and _is_occupied(_press_slot) and travel > 12.0 and dist > _outer_radius() * 0.98:
			_mode = _MODE_UNIT
			unit_drag_started.emit(_press_slot)
	if _mode == _MODE_ROTATE:
		_set_visual_angle(_accum)
	elif _mode == _MODE_UNIT:
		unit_drag_moved.emit(mouse_motion.global_position)
	accept_event()


func _draw() -> void:
	var center := _center()
	var inner := _inner_radius()
	var outer := _outer_radius()
	for slot_index in BoardController.SLOTS_PER_FACE:
		draw_colored_polygon(_wedge_polygon(_slot_center_angle(slot_index)), _slot_fill(slot_index))
	draw_arc(center, inner, 0.0, TAU, 48, Color(0.08, 0.09, 0.12), 4.0, true)
	draw_arc(center, outer, 0.0, TAU, 64, Color(0.08, 0.09, 0.12), 4.0, true)
	draw_circle(center, inner - 3.0, Color(0.1, 0.11, 0.14, 0.96))
	for slot_index in BoardController.SLOTS_PER_FACE:
		_draw_slot_number(slot_index)
		_draw_slot_label(slot_index)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-28.0, -outer - 6.0), "前衛", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.9, 0.96))
	draw_string(font, center + Vector2(-28.0, outer + 18.0), "後衛", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.72, 0.68))


func _slot_fill(slot_index: int) -> Color:
	if _slot_color_index(slot_index) % 2 == 0:
		return Color(0.16, 0.45, 0.88)
	return Color(0.95, 0.96, 0.97)


func _slot_color_index(slot_index: int) -> int:
	if slot_index >= 0 and slot_index < _view_slots.size():
		return int(_view_slots[slot_index].get("number", slot_index + 1)) - 1
	return slot_index


func _on_blue(slot_index: int) -> bool:
	return _slot_color_index(slot_index) % 2 == 0


func _draw_slot_number(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	if bool(slot.get("occupied", false)) or bool(slot.get("fallback", false)):
		return
	var angle := _slot_center_angle(slot_index)
	var radius := (_inner_radius() + _outer_radius()) * 0.5
	var pos := _center() + Vector2(cos(angle), sin(angle)) * radius
	var color := Color(0.97, 0.98, 1.0) if _on_blue(slot_index) else Color(0.12, 0.22, 0.4)
	var font := ThemeDB.fallback_font
	var font_size := 28
	draw_string(font, pos + Vector2(-18.0, font_size * 0.35), str(int(slot.get("number", slot_index + 1))), HORIZONTAL_ALIGNMENT_CENTER, 36.0, font_size, color)


func _draw_slot_label(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	var occupied := bool(slot.get("occupied", false))
	var fallback := bool(slot.get("fallback", false))
	if not occupied and not fallback:
		return
	var angle := _slot_center_angle(slot_index)
	var radius := (_inner_radius() + _outer_radius()) * 0.5
	var pos := _center() + Vector2(cos(angle), sin(angle)) * radius
	var band := _outer_radius() - _inner_radius()
	var icon_h := clampf(band * 0.58, 28.0, 72.0)
	var icon_w := icon_h * 0.86
	var icon_rect := Rect2(pos - Vector2(icon_w * 0.5, icon_h * 0.62), Vector2(icon_w, icon_h))
	var icon_color := Color(1, 1, 1, 0.45) if fallback else Color.WHITE
	draw_texture_rect(PLACEHOLDER_TEXTURE, icon_rect, false, icon_color)
	var cost := int(slot.get("cost", 0))
	if cost > 0:
		draw_rect(icon_rect, CostColors.get_color(cost), false, 2.0)
	var text := "%s %s" % [slot.get("name", ""), slot.get("stars", "")]
	if fallback:
		text = "補 %s %s" % [slot.get("name", ""), slot.get("stars", "")]
	var on_blue := _on_blue(slot_index)
	var color := Color(1, 1, 1, 0.75) if fallback else Color.WHITE
	if not on_blue and not fallback:
		color = Color(0.08, 0.1, 0.16)
	var font := ThemeDB.fallback_font
	draw_string(font, icon_rect.position + Vector2(-6.0, icon_rect.size.y + 14.0), text, HORIZONTAL_ALIGNMENT_CENTER, icon_rect.size.x + 12.0, 12, color)
	var number_color := Color(0.97, 0.98, 1.0) if on_blue else Color(0.12, 0.22, 0.4)
	draw_string(
		font,
		icon_rect.position + Vector2(-2.0, 14.0),
		str(int(slot.get("number", slot_index + 1))),
		HORIZONTAL_ALIGNMENT_LEFT,
		24.0,
		14,
		number_color
	)


func _has_point(point: Vector2) -> bool:
	if _ccw_button != null and _ccw_button.get_rect().grow(4.0).has_point(point):
		return true
	if _cw_button != null and _cw_button.get_rect().grow(4.0).has_point(point):
		return true
	return point.distance_to(_center()) <= _outer_radius() + 8.0


func _center() -> Vector2:
	return size * 0.5


func _outer_radius() -> float:
	return maxf(48.0, minf(size.x, size.y) * 0.5 - 50.0)


func _inner_radius() -> float:
	return _outer_radius() * 0.4


func _fixed_slot_center_angle(slot_index: int) -> float:
	return -PI / 2.0 + float(slot_index - 1) * TAU / 6.0


func _slot_center_angle(slot_index: int) -> float:
	return _fixed_slot_center_angle(slot_index) + _visual_angle


func _animate_steps(steps: int) -> void:
	if steps == 0:
		return
	_commit_spin_now()
	_tween_visual(0.0, float(steps) * TAU / 6.0, 0.22)


func _animate_to_nearest_step() -> void:
	var step := TAU / 6.0
	var steps := int(round(_visual_angle / step))
	_tween_visual(_visual_angle, float(steps) * step, 0.16)


func _tween_visual(from_angle: float, to_angle: float, duration: float) -> void:
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_visual_angle = from_angle
	_spin_tween = create_tween()
	_spin_tween.set_trans(Tween.TRANS_CUBIC)
	_spin_tween.set_ease(Tween.EASE_OUT)
	_spin_tween.tween_method(_set_visual_angle, from_angle, to_angle, duration)
	_spin_tween.tween_callback(_commit_visual_angle)


func _set_visual_angle(angle: float) -> void:
	_visual_angle = angle
	queue_redraw()
	visual_shift_changed.emit(_visual_angle / (TAU / 6.0))


func _commit_spin_now() -> void:
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_commit_visual_angle()


func _commit_visual_angle() -> void:
	var steps := int(round(_visual_angle / (TAU / 6.0)))
	_visual_angle = 0.0
	_accum = 0.0
	queue_redraw()
	rotate_steps.emit(steps)


func _angle_at(point: Vector2) -> float:
	var delta := point - _center()
	return atan2(delta.y, delta.x)


func _is_center(point: Vector2) -> bool:
	return point.distance_to(_center()) <= _inner_radius() * 0.92


func _is_ring(point: Vector2) -> bool:
	var dist := point.distance_to(_center())
	return dist >= _inner_radius() and dist <= _outer_radius() + 4.0


func _slot_at(point: Vector2) -> int:
	if not _is_ring(point):
		return -1
	var angle := _angle_at(point)
	for slot_index in BoardController.SLOTS_PER_FACE:
		var delta := absf(wrapf(angle - _slot_center_angle(slot_index), -PI, PI))
		if delta <= TAU / 12.0 + 0.02:
			return slot_index
	return -1


func _is_occupied(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _occupied.size() and _occupied[slot_index]


func _wedge_polygon(center_angle: float) -> PackedVector2Array:
	var start := center_angle - TAU / 12.0
	var finish := center_angle + TAU / 12.0
	var points := PackedVector2Array()
	var segments := 6
	var center := _center()
	var outer := _outer_radius()
	var inner := _inner_radius()
	for step in segments + 1:
		var angle := lerpf(start, finish, float(step) / float(segments))
		points.append(center + Vector2(cos(angle), sin(angle)) * outer)
	for step in segments + 1:
		var angle := lerpf(start, finish, float(segments - step) / float(segments))
		points.append(center + Vector2(cos(angle), sin(angle)) * inner)
	return points


func _to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position
