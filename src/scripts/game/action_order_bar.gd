class_name ActionOrderBar
extends PanelContainer

const ROW_GAP := 4.0
const MOVE_SECONDS := 0.32

var _scroll: ScrollContainer
var _list: Control
var _rows: Dictionary = {}
var _fading: Array[Control] = []
var _order: Array[int] = []
var _move_tween: Tween
var _seen_layout := false
var _width_used := -1.0
var _placing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scroll)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	resized.connect(_on_resized)


func set_entries(entries: Array) -> void:
	if _list == null:
		return
	_finish_fading()
	var next: Array[int] = []
	var by_key: Dictionary = {}
	for entry in entries:
		var key := int(entry.get("key", 0))
		if by_key.has(key):
			continue
		by_key[key] = entry
		next.append(key)
		if not _rows.has(key):
			var row := _make_entry(entry)
			_list.add_child(row)
			_rows[key] = row
		else:
			_refresh_entry(_rows[key], entry)
	var removed: Array[int] = []
	for key in _rows.keys():
		if not by_key.has(int(key)):
			removed.append(int(key))
	for key in removed:
		var row: Control = _rows[key]
		_rows.erase(key)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fading.append(row)
	_order = next
	_place_rows(not _seen_layout)
	_seen_layout = true


func _on_resized() -> void:
	if _placing or not _seen_layout or absf(size.x - _width_used) < 1.0:
		return
	_place_rows(true)


func _place_rows(snap: bool) -> void:
	if _placing:
		return
	_placing = true
	_place_rows_now(snap)
	_placing = false


func _place_rows_now(snap: bool) -> void:
	var width := maxf(48.0, size.x - 12.0)
	var row_h := width * 0.5
	_width_used = size.x
	var y := 0.0
	var targets: Dictionary = {}
	for key in _order:
		targets[key] = y
		var row: Control = _rows[key]
		_fit_row(row, width, row_h)
		y += row_h + ROW_GAP
	var final_h := y
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if snap:
		for key in _order:
			(_rows[key] as Control).position = Vector2(0.0, float(targets[key]))
			(_rows[key] as Control).set_meta("placed", true)
		_finish_fading()
		_list.custom_minimum_size = Vector2(0.0, final_h)
		_list.size = Vector2(width, final_h)
		return
	var travel_h := final_h
	for row in _fading:
		travel_h = maxf(travel_h, row.position.y + row.size.y + ROW_GAP)
	for key in _order:
		var existing: Control = _rows[key]
		travel_h = maxf(travel_h, existing.position.y + row_h + ROW_GAP)
	var motions: Array[Dictionary] = []
	for key in _order:
		var row: Control = _rows[key]
		var target := Vector2(0.0, float(targets[key]))
		if not bool(row.get_meta("placed", false)) or row.position.distance_to(target) < 0.5:
			row.position = target
			row.set_meta("placed", true)
			continue
		motions.append({"row": row, "target": target})
		travel_h = maxf(travel_h, row.position.y + row_h + ROW_GAP)
	if motions.is_empty() and _fading.is_empty():
		_list.custom_minimum_size = Vector2(0.0, final_h)
		_list.size = Vector2(width, final_h)
		return
	_list.custom_minimum_size = Vector2(0.0, travel_h)
	_list.size = Vector2(width, travel_h)
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_CUBIC)
	_move_tween.set_ease(Tween.EASE_OUT)
	for motion in motions:
		_move_tween.tween_property(motion["row"], "position", motion["target"], MOVE_SECONDS)
	for row in _fading:
		_move_tween.tween_property(row, "modulate:a", 0.0, MOVE_SECONDS * 0.65)
	_move_tween.finished.connect(_on_move_finished.bind(final_h, width), CONNECT_ONE_SHOT)


func _on_move_finished(final_h: float, width: float) -> void:
	_finish_fading()
	if _list == null:
		return
	_list.custom_minimum_size = Vector2(0.0, final_h)
	_list.size = Vector2(maxf(_list.size.x, 1.0), final_h)


func _finish_fading() -> void:
	for row in _fading:
		if is_instance_valid(row):
			row.queue_free()
	_fading.clear()


func _fit_row(row: Control, width: float, row_h: float) -> void:
	row.custom_minimum_size = Vector2(0.0, row_h)
	row.size = Vector2(width, row_h)
	var value_label := row.get_node_or_null("Value") as Label
	if value_label == null:
		return
	var font_size := _value_font_size(value_label.text, width, row_h)
	value_label.add_theme_font_size_override("font_size", font_size)


func _refresh_entry(row: Control, entry: Dictionary) -> void:
	var on_front := bool(entry.get("front", true))
	var border := CostColors.get_color(int(entry.get("cost", 1)))
	if not on_front:
		border.a = 0.45
	var frame := row.get_node_or_null("Frame") as Panel
	if frame != null:
		var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style = style.duplicate() as StyleBoxFlat
			style.border_color = border
			frame.add_theme_stylebox_override("panel", style)
	var icon := row.get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.modulate.a = 0.45 if not on_front else 1.0
	var value_label := row.get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = str(entry.get("action_value", 0))


func _make_entry(entry: Dictionary) -> Control:
	var width := maxf(48.0, size.x - 12.0)
	var height := width * 0.5
	var texture := UnitCatalog.make_portrait(int(entry.get("unit_id", 0)), Vector2(width, height))
	var on_front := bool(entry.get("front", true))
	var border := CostColors.get_color(int(entry.get("cost", 1)))
	if not on_front:
		border.a = 0.45
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	root.custom_minimum_size = Vector2(0, height)
	root.size = Vector2(width, height)
	var frame := Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.z_index = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", style)
	root.add_child(frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = -8.0
	icon.offset_top = -8.0
	icon.offset_right = 8.0
	icon.offset_bottom = 8.0
	icon.z_index = 0
	if not on_front:
		icon.modulate.a = 0.45
	root.add_child(icon)
	var value_text := str(entry.get("action_value", 0))
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = 4.0
	value_label.offset_top = 0.0
	value_label.offset_right = -6.0
	value_label.offset_bottom = 0.0
	value_label.z_index = 3
	value_label.add_theme_font_size_override("font_size", _value_font_size(value_text, width, height))
	value_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82))
	value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	value_label.add_theme_constant_override("outline_size", 12)
	root.add_child(value_label)
	return root


func _value_font_size(value_text: String, width: float, height: float) -> int:
	var font_size := int(height * 0.72)
	var estimated := float(value_text.length()) * float(font_size) * 0.58
	if estimated > width - 8.0:
		font_size = int((width - 8.0) / (float(value_text.length()) * 0.58))
	return clampi(font_size, 22, 56)
