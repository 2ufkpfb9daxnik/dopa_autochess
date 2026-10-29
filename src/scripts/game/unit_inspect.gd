class_name UnitInspect
extends Control

const PANEL_WIDTH := 480.0
const SUMMARY_FONT := 20
const DETAIL_FONT := 15
const TABLE_FONT := 13
const ROUNDED_ICON := preload("res://shaders/rounded_icon.gdshader")

var _panel: PanelContainer
var _summary_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _detail_button: Button
var _tip: PanelContainer
var _tip_label: Label
var _tip_owner: Control
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
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_summary_box = VBoxContainer.new()
	_summary_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_summary_box.add_theme_constant_override("separation", 4)
	box.add_child(_summary_box)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 36.0, 280)
	_detail_scroll.visible = false
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 20
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.98, 0.96, 0.88, 0.98)
	tip_style.border_color = Color(0.35, 0.28, 0.12, 0.95)
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(10)
	tip_style.content_margin_left = 12
	tip_style.content_margin_right = 12
	tip_style.content_margin_top = 8
	tip_style.content_margin_bottom = 8
	tip_style.shadow_color = Color(0, 0, 0, 0.35)
	tip_style.shadow_size = 8
	_tip.add_theme_stylebox_override("panel", tip_style)
	_tip_label = Label.new()
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.06))
	_tip.add_child(_tip_label)
	add_child(_tip)


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
	_hide_tip()
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
		height += _add_labeled_icon("コスト", cost, SUMMARY_FONT, rows)
		rows += 1
	var synergies := str(info.get("synergies", ""))
	if not synergies.is_empty():
		height += _add_synergy_chips(synergies, width, rows)
		rows += 1
	var role_rows: Array = []
	var attack := str(info.get("attack", "")).strip_edges()
	if not attack.is_empty():
		role_rows.append({"caption": "使用", "names": PackedStringArray([attack])})
	var strong := _as_strings(info.get("strong", []))
	if not strong.is_empty():
		role_rows.append({"caption": "得意", "names": strong})
	var weak := _as_strings(info.get("weak", []))
	if not weak.is_empty():
		role_rows.append({"caption": "苦手", "names": weak})
	if not role_rows.is_empty():
		height += _add_role_rows(role_rows, SUMMARY_FONT, rows)
		rows += 1
	var stat_rows: Array = info.get("stat_rows", [])
	if not stat_rows.is_empty():
		height += _add_stat_rows(stat_rows, SUMMARY_FONT, rows)
		rows += 1
	var brief := str(info.get("brief", "")).strip_edges()
	if not brief.is_empty():
		height += _add_rich_line(brief, SUMMARY_FONT, width, rows)
		rows += 1
	_summary_height = height


func _add_labeled_icon(label: String, value: String, font_size: int, rows: int) -> float:
	var px := CharacterText.icon_px(font_size)
	var line := _stat_pair({"label": label, "value": value, "icon": CharacterText.status_icon(label)}, font_size, px)
	_summary_box.add_child(line)
	var gap := 4.0 if rows > 0 else 0.0
	return gap + maxf(float(px), float(font_size))


func _add_stat_rows(entries: Array, font_size: int, rows: int) -> float:
	var px := CharacterText.icon_px(font_size)
	var height := 0.0
	var index := 0
	var line_index := 0
	while index < entries.size():
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_theme_constant_override("separation", 14)
		var end := mini(index + 4, entries.size())
		for entry_index in range(index, end):
			var item: Dictionary = entries[entry_index]
			line.add_child(_stat_pair(item, font_size, px))
		_summary_box.add_child(line)
		var gap := 0.0
		if line_index == 0 and rows > 0:
			gap = 4.0
		elif line_index > 0:
			gap = 6.0
		height += gap + maxf(float(px), float(font_size))
		index = end
		line_index += 1
	return height


func _stat_pair(item: Dictionary, font_size: int, px: int) -> HBoxContainer:
	var pair := HBoxContainer.new()
	pair.mouse_filter = Control.MOUSE_FILTER_PASS
	pair.add_theme_constant_override("separation", 4)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := _texture_icon(str(item.get("icon", "")), px)
	if icon != null:
		_bind_tip(icon, CharacterText.status_tooltip(str(item.get("label", ""))))
		pair.add_child(icon)
	var value := _make_label(font_size)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text = str(item.get("value", ""))
	pair.add_child(value)
	return pair


func _add_synergy_chips(raw: String, width: float, rows: int) -> float:
	var names := PackedStringArray()
	for part in raw.replace("、", ",").split(","):
		var synergy_name := part.strip_edges()
		if not synergy_name.is_empty():
			names.append(synergy_name)
	if names.is_empty():
		return 0.0
	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.custom_minimum_size.x = width
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var font_size := 16
	var chip_h := 32.0
	var font := ThemeDB.fallback_font
	var cursor := 0.0
	var lines := 1
	for synergy_name in names:
		flow.add_child(_synergy_chip(synergy_name, font_size))
		var chip_w := font.get_string_size(synergy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 29.0
		if cursor > 0.0 and cursor + chip_w > width:
			lines += 1
			cursor = chip_w + 6.0
		else:
			cursor += chip_w + 6.0
	_summary_box.add_child(flow)
	var gap := 4.0 if rows > 0 else 0.0
	return gap + float(lines) * chip_h + float(maxi(lines - 1, 0)) * 6.0


func _synergy_chip(synergy_name: String, font_size: int) -> PanelContainer:
	var color := SynergyCatalog.color_of(synergy_name)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.34)
	style.border_color = Color(color.r, color.g, color.b, 1.0)
	style.set_border_width_all(2)
	style.border_width_left = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", style)
	var label := _make_label(font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = synergy_name
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	chip.add_child(label)
	return chip


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


func _add_role_rows(entries: Array, font_size: int, rows: int) -> float:
	var px := CharacterText.icon_px(font_size)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for entry in entries:
		var item: Dictionary = entry
		var caption := str(item.get("caption", ""))
		var slot := CenterContainer.new()
		slot.custom_minimum_size = Vector2(px, px)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var caption_icon := _texture_icon(CharacterText.status_icon(caption), px)
		if caption_icon != null:
			_bind_tip(caption_icon, CharacterText.status_tooltip(caption))
			slot.add_child(caption_icon)
		grid.add_child(slot)
		var attrs := HBoxContainer.new()
		attrs.mouse_filter = Control.MOUSE_FILTER_PASS
		attrs.add_theme_constant_override("separation", 4)
		attrs.alignment = BoxContainer.ALIGNMENT_CENTER
		var names: PackedStringArray = item.get("names", PackedStringArray())
		for attr_name in names:
			var icon := _attribute_icon(attr_name, px)
			if icon == null:
				var fallback := _make_label(font_size)
				fallback.autowrap_mode = TextServer.AUTOWRAP_OFF
				fallback.text = attr_name
				attrs.add_child(fallback)
			else:
				attrs.add_child(icon)
		grid.add_child(attrs)
	_summary_box.add_child(grid)
	var gap := 4.0 if rows > 0 else 0.0
	var line_count := entries.size()
	return gap + float(line_count) * float(px) + float(maxi(line_count - 1, 0)) * 4.0


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
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
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
	var status_path := CharacterText.status_icon(text)
	if not status_path.is_empty():
		var status_icon := _texture_icon(status_path, CharacterText.icon_px(font_size))
		if status_icon != null:
			_bind_tip(status_icon, CharacterText.status_tooltip(text))
			return status_icon
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
	var icon := _texture_icon(CharacterText.attribute_icon(attr_name), px)
	if icon != null:
		_bind_tip(icon, CharacterText.attribute_tooltip(attr_name))
	return icon


func _texture_icon(path: String, px: int) -> TextureRect:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var aspect := 1.0
	if texture.get_height() > 0:
		aspect = float(texture.get_width()) / float(texture.get_height())
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.mouse_default_cursor_shape = Control.CURSOR_HELP
	rect.texture = texture
	rect.custom_minimum_size = Vector2(maxf(1.0, float(px) * aspect), px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if path.ends_with("/speed.png"):
		var material := ShaderMaterial.new()
		material.shader = ROUNDED_ICON
		rect.material = material
	return rect


func _bind_tip(control: Control, text: String) -> void:
	if control == null or text.is_empty():
		return
	control.set_meta("tip_text", text)
	control.tooltip_text = ""
	if not control.mouse_entered.is_connected(_on_tip_control_entered):
		control.mouse_entered.connect(_on_tip_control_entered.bind(control))
	if not control.mouse_exited.is_connected(_on_tip_control_exited):
		control.mouse_exited.connect(_on_tip_control_exited.bind(control))


func _on_tip_control_entered(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	_show_tip(str(control.get_meta("tip_text", "")), control)


func _on_tip_control_exited(control: Control) -> void:
	if _tip_owner == control:
		_hide_tip()


func _show_tip(text: String, owner: Control = null, at_global: Variant = null) -> void:
	if text.is_empty() or _tip == null or _tip_label == null:
		return
	_tip_owner = owner
	_tip_label.text = text
	_tip.visible = true
	_tip.reset_size()
	var tip_size := _tip.get_combined_minimum_size()
	_tip.size = tip_size
	var pos := get_global_mouse_position() + Vector2(14.0, -28.0)
	if at_global is Vector2:
		pos = at_global as Vector2
	elif owner != null and is_instance_valid(owner):
		var rect := owner.get_global_rect()
		pos = Vector2(rect.get_center().x - tip_size.x * 0.5, rect.position.y - tip_size.y - 10.0)
	var viewport_size := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, viewport_size.x - tip_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, viewport_size.y - tip_size.y - 8.0))
	_tip.global_position = pos
	_tip.move_to_front()


func _hide_tip() -> void:
	_tip_owner = null
	if _tip != null:
		_tip.visible = false


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
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.hint_underlined = false
	label.meta_underlined = false
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color(0.97, 0.96, 0.93))
	label.meta_hover_started.connect(func(meta: Variant) -> void:
		_show_tip(str(meta), label, get_global_mouse_position() + Vector2(12.0, -30.0))
	)
	label.meta_hover_ended.connect(func(_meta: Variant) -> void:
		if _tip_owner == label:
			_hide_tip()
	)
	label.mouse_exited.connect(func() -> void:
		if _tip_owner == label:
			_hide_tip()
	)
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.free()
