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
	var root := Control.new()
	root.custom_minimum_size = Vector2(64, 48)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ColorRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.color = CostColors.get_color(int(entry.get("cost", 1)))
	if bool(entry.get("enemy", false)):
		icon.color = icon.color.lerp(Color(0.75, 0.16, 0.18), 0.45)
	if not bool(entry.get("front", true)):
		icon.color.a = 0.45
	icon.position = Vector2(4, 2)
	icon.size = Vector2(56, 36)
	root.add_child(icon)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(entry.get("name", ""))
	name_label.position = Vector2(6, 4)
	name_label.size = Vector2(52, 16)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", CostColors.get_shop_label_color(int(entry.get("cost", 1))))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 3)
	root.add_child(name_label)
	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = str(entry.get("action_value", 0))
	value_label.position = Vector2(8, 28)
	value_label.size = Vector2(50, 16)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	value_label.add_theme_constant_override("outline_size", 4)
	root.add_child(value_label)
	return root
