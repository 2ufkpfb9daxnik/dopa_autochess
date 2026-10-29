class_name CircleWheel
extends Control

signal rotate_steps(steps: int)
signal visual_shift_changed(shift: float)
signal center_pressed
signal unit_drag_started(slot_index: int)
signal unit_drag_moved(global_position: Vector2)
signal unit_drag_finished(slot_index: int, global_position: Vector2)
signal slot_move_requested(from_slot: int, to_slot: int)
signal unit_clicked(slot_index: int)
signal debuff_cleanse_requested(slot_index: int)

const RIM_GRAB := 40.0
const FORMATION_COLORS := {
	"炎": Color(0.93, 0.18, 0.12, 0.92),
	"水": Color(0.16, 0.4, 0.96, 0.92),
	"氷": Color(0.45, 0.88, 1.0, 0.92),
	"風": Color(0.62, 0.9, 0.22, 0.92),
	"雷": Color(1.0, 0.86, 0.15, 0.92),
	"吸収": Color(0.64, 0.28, 0.95, 0.92),
	"土": Color(0.96, 0.5, 0.12, 0.92),
}
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
var _bubble_rects: Array[Rect2] = []
var _bubble_slots: Array[int] = []
var _poison_time := 0.0
var _cleanse_enabled := false
var _attribute_textures: Dictionary = {}


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


func set_cleanse_enabled(enabled: bool) -> void:
	if _cleanse_enabled == enabled:
		return
	_cleanse_enabled = enabled
	queue_redraw()


func _process(delta: float) -> void:
	if not _cleanse_enabled or not _has_debuffed_slot():
		return
	_poison_time += delta
	queue_redraw()


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


func reset_visual_spin() -> void:
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_visual_angle = 0.0
	_accum = 0.0
	queue_redraw()
	visual_shift_changed.emit(0.0)


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
	_ccw_button.position = _clamp_button(_center() + Vector2(cos(-PI * 0.75), sin(-PI * 0.75)) * (_outer_radius() + 24.0) - button_size * 0.5, button_size)
	_cw_button.position = _clamp_button(_center() + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * (_outer_radius() + 24.0) - button_size * 0.5, button_size)
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
	var bubble_slot := _bubble_slot_at(mouse_button.position)
	if _cleanse_enabled and bubble_slot >= 0:
		debuff_cleanse_requested.emit(bubble_slot)
		accept_event()
		return
	_commit_spin_now()
	if _is_center(mouse_button.position):
		center_pressed.emit()
		accept_event()
		return
	var slot := _slot_at(mouse_button.position)
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
	elif _mode == _MODE_NONE:
		var release_slot := _slot_at(mouse_button.position)
		if _press_slot >= 0 and release_slot >= 0 and release_slot != _press_slot and _is_occupied(_press_slot) and _unit_drag_enabled:
			slot_move_requested.emit(_press_slot, release_slot)
		elif _press_slot >= 0 and release_slot == _press_slot and _shows_unit(_press_slot):
			if _cleanse_enabled and _press_slot >= BoardController.FRONT_COUNT and _slot_is_debuffed(_press_slot):
				debuff_cleanse_requested.emit(_press_slot)
			else:
				unit_clicked.emit(_press_slot)
	_pressing = false
	_mode = _MODE_NONE
	accept_event()


func _drag_motion(mouse_motion: InputEventMouseMotion) -> void:
	var delta := wrapf(_angle_at(mouse_motion.position) - _last_angle, -PI, PI)
	_last_angle = _angle_at(mouse_motion.position)
	_accum += delta
	if _mode == _MODE_NONE:
		var travel := mouse_motion.position.distance_to(_press_pos)
		if _unit_drag_enabled and _press_slot >= 0 and _is_occupied(_press_slot) and travel > 12.0:
			_mode = _MODE_UNIT
			unit_drag_started.emit(_press_slot)
		elif absf(_accum) > 0.28:
			_mode = _MODE_ROTATE
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
	for slot_index in BoardController.SLOTS_PER_FACE:
		_draw_slot_portrait(slot_index)
	draw_arc(center, inner, 0.0, TAU, 48, Color(0.08, 0.09, 0.12), 4.0, true)
	draw_arc(center, outer, 0.0, TAU, 64, Color(0.08, 0.09, 0.12), 4.0, true)
	draw_circle(center, inner - 3.0, Color(0.1, 0.11, 0.14, 0.96))
	for slot_index in BoardController.SLOTS_PER_FACE:
		_draw_slot_number(slot_index)
		_draw_slot_outline(slot_index)
	_draw_formation_links()
	for slot_index in BoardController.SLOTS_PER_FACE:
		_draw_slot_label(slot_index)
		_draw_slot_attribute(slot_index)
	_draw_debuff_bubbles()


func _draw_formation_links() -> void:
	for slot_index in BoardController.SLOTS_PER_FACE:
		var next := (slot_index + 1) % BoardController.SLOTS_PER_FACE
		var element := _formation_element(slot_index, next)
		if element.is_empty():
			continue
		var left := _slot_center_angle(slot_index)
		var right := _slot_center_angle(next)
		var mid := left + wrapf(right - left, -PI, PI) * 0.5
		var color: Color = FORMATION_COLORS.get(element, Color(1, 1, 1, 0.9))
		_draw_soft_fan(mid, color)


func _draw_soft_fan(center_angle: float, color: Color) -> void:
	var half := TAU / 22.0
	var radii := _fan_radii()
	var layers := 5
	for index in layers:
		var spread := float(layers - 1 - index) / float(layers - 1)
		var layer_color := color
		layer_color.a *= lerpf(1.0, 0.16, spread)
		_draw_fading_fan(center_angle, half * lerpf(1.0, 1.55, spread), radii.x, radii.y, layer_color)
	var arc := Color(1, 1, 1, 0.7 * color.a)
	_draw_fading_arc(center_angle, half, radii.y, arc)
	_draw_fading_arc(center_angle, half, radii.x, arc)


func _draw_fading_fan(center_angle: float, half: float, inner_radius: float, outer_radius: float, color: Color) -> void:
	var segments := 16
	var center := _center()
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for step in segments + 1:
		var amount := float(step) / float(segments)
		var angle := lerpf(center_angle - half, center_angle + half, amount)
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
		colors.append(_faded_color(color, amount))
	for step in segments + 1:
		var amount := float(segments - step) / float(segments)
		var angle := lerpf(center_angle - half, center_angle + half, amount)
		points.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)
		colors.append(_faded_color(color, amount))
	draw_polygon(points, colors)


func _draw_fading_arc(center_angle: float, half: float, radius: float, color: Color) -> void:
	var segments := 16
	var center := _center()
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for step in segments + 1:
		var amount := float(step) / float(segments)
		var angle := lerpf(center_angle - half, center_angle + half, amount)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		colors.append(_faded_color(color, amount))
	draw_polyline_colors(points, colors, 2.0, true)


func _faded_color(color: Color, amount: float) -> Color:
	var edge := absf(amount * 2.0 - 1.0)
	var keep := 1.0 - edge
	color.a *= keep * keep * (3.0 - 2.0 * keep)
	return color


func _fan_radii() -> Vector2:
	var outer := _outer_radius()
	var inner := _inner_radius()
	var mid_radius := (inner + outer) * 0.5
	var radial := (outer - inner) / 8.0
	return Vector2(mid_radius - radial * 0.5, mid_radius + radial * 0.5)


func _formation_element(left_index: int, right_index: int) -> String:
	if left_index >= _view_slots.size() or right_index >= _view_slots.size():
		return ""
	var left: Dictionary = _view_slots[left_index]
	var right: Dictionary = _view_slots[right_index]
	if not _links_formation(left) or not _links_formation(right):
		return ""
	var element := str(left.get("element", ""))
	if element.is_empty() or element != str(right.get("element", "")):
		return ""
	return element


func _links_formation(slot: Dictionary) -> bool:
	if bool(slot.get("down", false)):
		return false
	return bool(slot.get("occupied", false)) or bool(slot.get("fallback", false))


func _slot_fill(slot_index: int) -> Color:
	var base := Color(0.16, 0.45, 0.88) if _slot_color_index(slot_index) % 2 == 0 else Color(0.95, 0.96, 0.97)
	if not _slot_is_debuffed(slot_index):
		return base
	var pulse := 0.5 + 0.5 * sin(_poison_time * 5.0)
	return base.lerp(Color(0.55, 0.92, 0.12), 0.62 + pulse * 0.28)


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


func _draw_slot_portrait(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	if not bool(slot.get("occupied", false)) and not bool(slot.get("fallback", false)):
		return
	var points := _wedge_polygon(_slot_center_angle(slot_index))
	var bounds := _polygon_bounds(points)
	var texture := UnitCatalog.get_icon(int(slot.get("unit_id", -1)))
	var cover := _cover_rect(bounds, texture)
	var poisoned := bool(slot.get("debuffed", false))
	var modulate := Color(0.48, 1.0, 0.18, _slot_alpha(slot)) if poisoned else Color(1, 1, 1, _slot_alpha(slot))
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for point in points:
		colors.append(modulate)
		uvs.append(Vector2((point.x - cover.position.x) / cover.size.x, (point.y - cover.position.y) / cover.size.y))
	draw_polygon(points, colors, uvs, texture)
	if poisoned:
		var wash := 0.42 + 0.16 * sin(_poison_time * 5.0)
		draw_colored_polygon(points, Color(0.42, 0.86, 0.05, wash))


func _has_debuffed_slot() -> bool:
	for slot in _view_slots:
		if slot is Dictionary and bool(slot.get("debuffed", false)):
			return true
	return false


func _slot_is_debuffed(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _view_slots.size():
		return false
	return bool(_view_slots[slot_index].get("debuffed", false))


func _draw_debuff_bubbles() -> void:
	_bubble_rects.clear()
	_bubble_slots.clear()
	if not _cleanse_enabled:
		return
	var font := ThemeDB.fallback_font
	var font_size := maxi(18, int(_outer_radius() * 0.12))
	var text := "デバフ解除"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	for slot_index in BoardController.SLOTS_PER_FACE:
		if slot_index < BoardController.FRONT_COUNT or not _slot_is_debuffed(slot_index):
			continue
		var angle := _slot_center_angle(slot_index)
		var outline := _wedge_polygon(angle)
		outline.append(outline[0])
		draw_polyline(outline, Color(0.72, 1.0, 0.18, 0.95), 5.0, true)
		var anchor := _center() + Vector2(cos(angle), sin(angle)) * (_outer_radius() - 8.0)
		var box := Rect2(anchor - Vector2(text_size.x * 0.5 + 10.0, text_size.y + 8.0), Vector2(text_size.x + 20.0, text_size.y + 14.0))
		box.position.x = clampf(box.position.x, 4.0, size.x - box.size.x - 4.0)
		box.position.y = clampf(box.position.y, 4.0, size.y - box.size.y - 4.0)
		_bubble_rects.append(box)
		_bubble_slots.append(slot_index)
		draw_rect(box, Color(0.12, 0.22, 0.04, 0.96))
		draw_rect(box, Color(0.78, 1.0, 0.22), false, 3.0)
		draw_string(font, box.position + Vector2(10.0, text_size.y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.86, 1.0, 0.45))


func _bubble_slot_at(point: Vector2) -> int:
	for index in _bubble_rects.size():
		if _bubble_rects[index].has_point(point):
			return _bubble_slots[index]
	return -1


func _draw_slot_outline(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	if not bool(slot.get("occupied", false)) and not bool(slot.get("fallback", false)):
		return
	var cost := int(slot.get("cost", 0))
	if cost <= 0:
		return
	var outline := _wedge_polygon(_slot_center_angle(slot_index))
	outline.append(outline[0])
	draw_polyline(outline, CostColors.get_color(cost), 2.0, true)


func _draw_slot_label(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	var occupied := bool(slot.get("occupied", false))
	var fallback := bool(slot.get("fallback", false))
	if not occupied and not fallback:
		return
	var layout := _slot_label_layout(slot_index)
	var font := ThemeDB.fallback_font
	var ink := Color(1, 1, 1, _slot_alpha(slot))
	_draw_outlined_string(font, layout["name_pos"], str(layout["name"]), HORIZONTAL_ALIGNMENT_LEFT, float(layout["name_width"]), 13, ink)
	if not str(layout["stars"]).is_empty():
		_draw_outlined_string(font, layout["star_pos"], str(layout["stars"]), HORIZONTAL_ALIGNMENT_LEFT, float(layout["star_width"]), 15, Color(1, 0.92, 0.45, ink.a))
	_draw_outlined_string(font, layout["number_pos"], str(layout["number"]), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 14, Color(0.97, 0.98, 1.0, ink.a))


func _slot_label_layout(slot_index: int) -> Dictionary:
	var slot: Dictionary = _view_slots[slot_index]
	var angle := _slot_center_angle(slot_index)
	var pos := _center() + Vector2(cos(angle), sin(angle)) * (_inner_radius() + _outer_radius()) * 0.5
	var band := _outer_radius() - _inner_radius()
	var name := str(slot.get("name", ""))
	if bool(slot.get("fallback", false)):
		name = "補 %s" % name
	var name_width := band * 0.72
	var name_pos := _clamp_to_wedge(pos + Vector2(-name_width * 0.35, band * 0.28), slot_index)
	var stars := str(slot.get("stars", ""))
	var star_width := band * 0.4
	var star_pos := _clamp_to_wedge(pos + Vector2(band * 0.16, -4.0), slot_index)
	var number := str(int(slot.get("number", slot_index + 1)))
	var number_pos := _clamp_to_wedge(_center() + Vector2(cos(angle), sin(angle)) * (_inner_radius() + 18.0) + Vector2(-10.0, 0.0), slot_index)
	return {
		"name": name,
		"name_pos": name_pos,
		"name_width": name_width,
		"stars": stars,
		"star_pos": star_pos,
		"star_width": star_width,
		"number": number,
		"number_pos": number_pos,
		"blocked": _slot_text_blocked_rects(name_pos, name_width, stars, star_pos, star_width, number_pos),
	}


func _slot_text_blocked_rects(name_pos: Vector2, name_width: float, stars: String, star_pos: Vector2, star_width: float, number_pos: Vector2) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	blocked.append(Rect2(name_pos + Vector2(-2.0, -14.0), Vector2(name_width + 4.0, 18.0)))
	if not stars.is_empty():
		blocked.append(Rect2(star_pos + Vector2(-2.0, -16.0), Vector2(star_width + 4.0, 20.0)))
	blocked.append(Rect2(number_pos + Vector2(-2.0, -14.0), Vector2(28.0, 18.0)))
	return blocked


func _draw_slot_attribute(slot_index: int) -> void:
	if slot_index >= _view_slots.size():
		return
	var slot: Dictionary = _view_slots[slot_index]
	if not bool(slot.get("occupied", false)) and not bool(slot.get("fallback", false)):
		return
	var element := str(slot.get("element", "")).strip_edges()
	if element.is_empty():
		return
	var texture := _attribute_texture(element)
	if texture == null:
		return
	var entry: Variant = CharacterText.ATTRIBUTE_ICONS.get(element, {})
	var aspect := 1.0
	if entry is Dictionary:
		aspect = float((entry as Dictionary).get("aspect", 1.0))
	var band := _outer_radius() - _inner_radius()
	var icon_h := clampf(band * 0.28, 18.0, 36.0)
	var icon_w := maxf(10.0, icon_h * aspect)
	var layout := _slot_label_layout(slot_index)
	var blocked: Array = layout["blocked"]
	var angle := _slot_center_angle(slot_index)
	var half := TAU / 12.0
	var radial_outer := _outer_radius() - maxf(icon_w, icon_h) * 0.55 - 8.0
	var radial_mid := lerpf(_inner_radius(), _outer_radius(), 0.82)
	var candidates: Array[Vector2] = [
		Vector2(angle - half * 0.62, radial_outer),
		Vector2(angle + half * 0.62, radial_outer),
		Vector2(angle - half * 0.42, radial_mid),
		Vector2(angle + half * 0.42, radial_mid),
		Vector2(angle - half * 0.72, lerpf(_inner_radius(), _outer_radius(), 0.7)),
		Vector2(angle + half * 0.72, lerpf(_inner_radius(), _outer_radius(), 0.7)),
	]
	var chosen := Vector2.ZERO
	var found := false
	for candidate in candidates:
		var center := _center() + Vector2(cos(candidate.x), sin(candidate.x)) * candidate.y
		var rect := Rect2(center - Vector2(icon_w, icon_h) * 0.5, Vector2(icon_w, icon_h)).grow(3.0)
		if _rect_hits_blocked(rect, blocked):
			continue
		chosen = center
		found = true
		break
	if not found:
		chosen = _center() + Vector2(cos(angle - half * 0.68), sin(angle - half * 0.68)) * radial_outer
	var rect := Rect2(chosen - Vector2(icon_w, icon_h) * 0.5, Vector2(icon_w, icon_h))
	var alpha := _slot_alpha(slot)
	draw_circle(chosen, maxf(icon_w, icon_h) * 0.56, Color(0.05, 0.06, 0.08, 0.7 * alpha))
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))


func _rect_hits_blocked(rect: Rect2, blocked: Array) -> bool:
	for entry in blocked:
		if entry is Rect2 and rect.intersects(entry as Rect2):
			return true
	return false


func _attribute_texture(element: String) -> Texture2D:
	if _attribute_textures.has(element):
		return _attribute_textures[element] as Texture2D
	var path := CharacterText.attribute_icon(element)
	if path.is_empty() or not ResourceLoader.exists(path):
		_attribute_textures[element] = null
		return null
	var texture := load(path) as Texture2D
	_attribute_textures[element] = texture
	return texture


func _slot_alpha(slot: Dictionary) -> float:
	if bool(slot.get("down", false)):
		return 0.35
	if bool(slot.get("fallback", false)):
		return 0.45
	return 1.0


func _cover_rect(bounds: Rect2, texture: Texture2D) -> Rect2:
	var tex_size := texture.get_size()
	var aspect := tex_size.x / maxf(1.0, tex_size.y)
	var target := Vector2(bounds.size.x, bounds.size.y * 1.08)
	var cover := target
	if cover.x / maxf(1.0, cover.y) > aspect:
		cover.y = cover.x / aspect
	else:
		cover.x = cover.y * aspect
	if cover.x < target.x:
		cover *= target.x / cover.x
	if cover.y < target.y:
		cover *= target.y / cover.y
	var shown := target.y / maxf(1.0, cover.y)
	if shown > 0.5:
		cover *= shown / 0.5
	var shift := UnitCatalog.PORTRAIT_TOP_SHIFT
	var span := target.y / maxf(1.0, cover.y)
	if shift + span > 1.0:
		shift = maxf(0.0, 1.0 - span)
	return Rect2(Vector2(bounds.get_center().x - cover.x * 0.5, bounds.position.y - cover.y * shift), cover)


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _clamp_to_wedge(point: Vector2, slot_index: int) -> Vector2:
	var delta := point - _center()
	var dist := clampf(delta.length(), _inner_radius() + 12.0, _outer_radius() - 12.0)
	var angle := _slot_center_angle(slot_index)
	var point_angle := angle if delta.length() <= 1.0 else atan2(delta.y, delta.x)
	var limit := TAU / 12.0 - 0.16
	var delta_angle := clampf(wrapf(point_angle - angle, -PI, PI), -limit, limit)
	return _center() + Vector2(cos(angle + delta_angle), sin(angle + delta_angle)) * dist


func _draw_outlined_string(font: Font, pos: Vector2, text: String, alignment: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	var shadow := Color(0, 0, 0, 0.9 * color.a)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + offset, text, alignment, width, font_size, shadow)
	draw_string(font, pos, text, alignment, width, font_size, color)


func _has_point(point: Vector2) -> bool:
	if _ccw_button != null and _ccw_button.get_rect().grow(4.0).has_point(point):
		return true
	if _cw_button != null and _cw_button.get_rect().grow(4.0).has_point(point):
		return true
	return point.distance_to(_center()) <= _outer_radius() + RIM_GRAB


func _center() -> Vector2:
	return size * 0.5


func _outer_radius() -> float:
	return maxf(48.0, minf(size.x, size.y) * 0.5 - RIM_GRAB)


func _clamp_button(pos: Vector2, button_size: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, 0.0, maxf(0.0, size.x - button_size.x)),
		clampf(pos.y, 0.0, maxf(0.0, size.y - button_size.y))
	)


func _inner_radius() -> float:
	return _outer_radius() * 0.4


func _fixed_slot_center_angle(slot_index: int) -> float:
	return -PI / 2.0 + float(slot_index - 1) * TAU / 6.0


func _slot_center_angle(slot_index: int) -> float:
	return _fixed_slot_center_angle(slot_index) + _visual_angle


func spin_steps(steps: int) -> void:
	if posmod(steps, BoardController.SLOTS_PER_FACE) == 0:
		return
	_commit_spin_now()
	_tween_visual(0.0, float(steps) * TAU / 6.0, 0.45)
	if _spin_tween != null and _spin_tween.is_valid():
		await _spin_tween.finished


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


func _shows_unit(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _view_slots.size():
		return false
	var slot: Dictionary = _view_slots[slot_index]
	return bool(slot.get("occupied", false)) or bool(slot.get("fallback", false))


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
