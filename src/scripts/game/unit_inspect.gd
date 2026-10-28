class_name UnitInspect
extends Control

const PANEL_WIDTH := 480.0
const SUMMARY_FONT := 20
const DETAIL_FONT := 15
const TABLE_FONT := 13

var _panel: PanelContainer
var _summary_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _detail_button: Button
var _anchor := Vector2.ZERO
var _detailed := false
var _summary_height := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	style.border_color = Color(0.9, 0.78, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_summary_box = VBoxContainer.new()
	_summary_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_box.add_theme_constant_override("separation", 4)
	box.add_child(_summary_box)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 36.0, 280)
	_detail_scroll.visible = false
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 8)
	_detail_scroll.add_child(_detail_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_detail_button = Button.new()
	_detail_button.text = "詳細"
	_detail_button.custom_minimum_size = Vector2(120, 42)
	_detail_button.pressed.connect(_toggle_detail)
	buttons.add_child(_detail_button)


func open_unit(unit_id: int, stars: int, anchor: Vector2) -> void:
	_anchor = anchor
	_detailed = false
	_rebuild_summary(unit_id, stars)
	_rebuild_detail(unit_id)
	_detail_scroll.visible = false
	_detail_button.text = "詳細"
	_detail_button.visible = _detail_box.get_child_count() > 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true
	z_as_relative = false
	z_index = 90
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	move_to_front()
	call_deferred("_place_panel")


func close_card() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	if _panel.get_global_rect().has_point((event as InputEventMouseButton).global_position):
		return
	close_card()
	accept_event()


func _toggle_detail() -> void:
	_detailed = not _detailed
	_detail_scroll.visible = _detailed
	_detail_button.text = "戻る" if _detailed else "詳細"
	call_deferred("_place_panel")


func _place_panel() -> void:
	if not visible:
		return
	var inner_width := PANEL_WIDTH - 36.0
	_summary_box.custom_minimum_size = Vector2(inner_width, _summary_height)
	var button_height := maxf(42.0, _detail_button.get_combined_minimum_size().y)
	var panel_size := Vector2(PANEL_WIDTH, 16.0 + _summary_height + 10.0 + button_height + 14.0)
	if _detailed:
		panel_size.y += 10.0 + 280.0
	var viewport_size := get_viewport().get_visible_rect().size
	var origin := _anchor + Vector2(18.0, 18.0)
	if origin.x + panel_size.x > viewport_size.x - 12.0:
		origin.x = _anchor.x - panel_size.x - 18.0
	if origin.y + panel_size.y > viewport_size.y - 12.0:
		origin.y = _anchor.y - panel_size.y - 18.0
	origin.x = clampf(origin.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	origin.y = clampf(origin.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	_panel.position = origin
	_panel.size = panel_size


func _rebuild_summary(unit_id: int, stars: int) -> void:
	_clear(_summary_box)
	var info: Dictionary = CharacterText.summary_info(unit_id, stars)
	var width := PANEL_WIDTH - 36.0
	var height := 0.0
	var rows := 0
	var title := _make_label(SUMMARY_FONT)
	title.text = "%s  %s" % [str(info.get("name", "")), "★".repeat(maxi(int(info.get("stars", stars)), 1))]
	title.custom_minimum_size.x = width
	_summary_box.add_child(title)
	height += _block_height(title, width)
	rows += 1
	var cost := str(info.get("cost", ""))
	if not cost.is_empty():
		height += _add_text_line("コスト %s" % cost, SUMMARY_FONT, width, rows)
		rows += 1
	var synergies := str(info.get("synergies", ""))
	if not synergies.is_empty():
		height += _add_text_line(synergies, SUMMARY_FONT, width, rows)
		rows += 1
	var attack := str(info.get("attack", "")).strip_edges()
	if not attack.is_empty():
		height += _add_icon_line("攻撃属性", PackedStringArray([attack]), SUMMARY_FONT, rows)
		rows += 1
	var strong := _as_strings(info.get("strong", []))
	if not strong.is_empty():
		height += _add_icon_line("得意", strong, SUMMARY_FONT, rows)
		rows += 1
	var weak := _as_strings(info.get("weak", []))
	if not weak.is_empty():
		height += _add_icon_line("苦手", weak, SUMMARY_FONT, rows)
		rows += 1
	var stats := str(info.get("stats", ""))
	if not stats.is_empty():
		height += _add_text_line(stats, SUMMARY_FONT, width, rows)
		rows += 1
	var brief := str(info.get("brief", "")).strip_edges()
	if not brief.is_empty():
		height += _add_rich_line(brief, SUMMARY_FONT, width, rows)
		rows += 1
	_summary_height = height


func _add_text_line(text: String, font_size: int, width: float, rows: int) -> float:
	var label := _make_label(font_size)
	label.text = text
	label.custom_minimum_size.x = width
	_summary_box.add_child(label)
	var gap := 4.0 if rows > 0 else 0.0
	return gap + _block_height(label, width)


func _add_rich_line(text: String, font_size: int, width: float, rows: int) -> float:
	var icon_h := CharacterText.icon_px(font_size)
	var label := _make_rich(font_size, width)
	label.text = CharacterText.with_attribute_icons(text, icon_h)
	_summary_box.add_child(label)
	var plain := _make_label(font_size)
	plain.text = text
	var gap := 4.0 if rows > 0 else 0.0
	var text_h := _block_height(plain, width)
	if label.text != text:
		var extra := 0.0
		if text_h > float(font_size) * 1.5:
			extra = text_h - float(font_size) * 1.2
		text_h = maxf(text_h, float(icon_h)) + extra
	return gap + text_h


func _add_icon_line(caption: String, names: PackedStringArray, font_size: int, rows: int) -> float:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var label := _make_label(font_size)
	label.text = caption
	row.add_child(label)
	var px := CharacterText.icon_px(font_size)
	for attr_name in names:
		var icon := _attribute_icon(attr_name, px)
		if icon == null:
			var fallback := _make_label(font_size)
			fallback.text = attr_name
			row.add_child(fallback)
		else:
			row.add_child(icon)
	_summary_box.add_child(row)
	var gap := 4.0 if rows > 0 else 0.0
	return gap + maxf(float(px), _block_height(label, 240.0))


func _rebuild_detail(unit_id: int) -> void:
	_clear(_detail_box)
	var width := PANEL_WIDTH - 52.0
	var blocks: Array = CharacterText.detail_blocks(unit_id)
	for entry in blocks:
		var block: Dictionary = entry
		var title := _make_label(DETAIL_FONT + 2)
		title.text = str(block.get("title", ""))
		title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
		_detail_box.add_child(title)
		var parts: Array = block.get("parts", [])
		for part_value in parts:
			var part: Dictionary = part_value
			if str(part.get("kind", "")) == "table":
				_detail_box.add_child(_make_table(part.get("rows", []), TABLE_FONT))
			else:
				var text := str(part.get("text", "")).strip_edges()
				if text.is_empty():
					continue
				var body := _make_rich(DETAIL_FONT, width)
				body.text = CharacterText.with_attribute_icons(text, CharacterText.icon_px(DETAIL_FONT))
				_detail_box.add_child(body)


func _make_table(rows_value: Variant, font_size: int) -> Control:
	var rows: Array = rows_value if rows_value is Array else []
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	var columns := 1
	for row_value in rows:
		if row_value is Array:
			columns = maxi(columns, (row_value as Array).size())
	grid.columns = columns
	var row_index := 0
	for row_value in rows:
		var row: Array = row_value if row_value is Array else []
		for column in columns:
			var text := ""
			if column < row.size():
				text = str(row[column])
			grid.add_child(_table_cell(text, font_size, row_index == 0, column > 0))
		row_index += 1
	frame.add_child(grid)
	return frame


func _table_cell(text: String, font_size: int, header: bool, numeric_column: bool) -> Control:
	var icon_path := CharacterText.attribute_icon(text)
	if not icon_path.is_empty():
		var icon := _attribute_icon(text, CharacterText.icon_px(font_size))
		if icon != null:
			return icon
	if CharacterText.with_attribute_icons(text, font_size) != text:
		var rich := _make_rich(font_size, 120.0)
		rich.text = CharacterText.with_attribute_icons(text, CharacterText.icon_px(font_size))
		rich.fit_content = true
		if header:
			rich.add_theme_color_override("default_color", Color(0.95, 0.86, 0.55))
		return rich
	var label := _make_label(font_size)
	label.text = text
	if numeric_column:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size.x = 48.0
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 108.0
	if header:
		label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	return label


func _attribute_icon(attr_name: String, px: int) -> TextureRect:
	var path := CharacterText.attribute_icon(attr_name)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var aspect := 1.0
	if texture.get_height() > 0:
		aspect = float(texture.get_width()) / float(texture.get_height())
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.custom_minimum_size = Vector2(maxf(1.0, float(px) * aspect), px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _as_strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


func _block_height(label: Label, width: float) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 16
	if font == null or label.text.is_empty():
		return font_size
	label.custom_minimum_size.x = width
	var measured := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	return maxf(measured.y, font_size)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	return label


func _make_rich(font_size: int, width: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color(0.97, 0.96, 0.93))
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.free()
