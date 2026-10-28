class_name ActionOrderBar
extends PanelContainer

var _row: VBoxContainer


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
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	_row = VBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 4)
	scroll.add_child(_row)


func set_entries(entries: Array) -> void:
	if _row == null:
		return
	var stale := _row.get_children()
	for child in stale:
		_row.remove_child(child)
		child.free()
	var title := Label.new()
	title.text = "行動順"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	_row.add_child(title)
	for entry in entries:
		_row.add_child(_make_entry(entry))


func _make_entry(entry: Dictionary) -> Control:
	var texture := UnitCatalog.get_icon(int(entry.get("unit_id", 0)))
	var width := maxf(48.0, size.x - 12.0)
	var height := width * 0.5
	var on_front := bool(entry.get("front", true))
	var border := CostColors.get_color(int(entry.get("cost", 1)))
	if not on_front:
		border.a = 0.45
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, height)
	root.clip_contents = true
	var frame := Panel.new()
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
	var font_size := int(height * 0.72)
	var estimated := float(value_text.length()) * float(font_size) * 0.58
	if estimated > width - 8.0:
		font_size = int((width - 8.0) / (float(value_text.length()) * 0.58))
	font_size = clampi(font_size, 22, 56)
	var value_label := Label.new()
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
	value_label.add_theme_font_size_override("font_size", font_size)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82))
	value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	value_label.add_theme_constant_override("outline_size", 12)
	root.add_child(value_label)
	return root
