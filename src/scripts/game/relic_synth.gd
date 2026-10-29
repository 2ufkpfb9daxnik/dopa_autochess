class_name RelicSynth
extends Control

signal confirmed(left_uid: int, right_uid: int)

const TEXT_WIDTH := 440.0

var _left_uid := -1
var _right_uid := -1
var _icon: TextureRect
var _name: Label
var _body: Label
var _panel: PanelContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 96
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close_synth()
	)
	add_child(dim)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.border_color = Color(0.9, 0.78, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "合成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var holder := CenterContainer.new()
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(120, 120)
	holder.add_child(_icon)
	box.add_child(holder)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_size_override("font_size", 26)
	_name.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_name)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
	_body.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	row.add_child(_mark_button("〇", true))
	row.add_child(_mark_button("×", false))


func open_pair(left_uid: int, right_uid: int, left_id: int, right_id: int) -> void:
	_left_uid = left_uid
	_right_uid = right_uid
	var result_id := RelicCatalog.synthesize_id(left_id, right_id)
	var data := RelicCatalog.get_relic(result_id)
	_icon.texture = RelicCatalog.get_icon(result_id)
	_name.text = str(data.get("name", "レリック"))
	var brief := str(data.get("brief", "")).strip_edges()
	if brief.is_empty():
		brief = str(data.get("detail", "")).strip_edges()
	_body.text = brief
	visible = true
	move_to_front()
	_layout_panel()


func close_synth() -> void:
	visible = false
	_left_uid = -1
	_right_uid = -1


func _mark_button(text: String, accept: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 88)
	button.add_theme_font_size_override("font_size", 48)
	button.pressed.connect(func() -> void:
		if accept and _left_uid >= 0:
			confirmed.emit(_left_uid, _right_uid)
		close_synth()
	)
	return button


func _layout_panel() -> void:
	var view := get_viewport().get_visible_rect().size
	size = view
	position = Vector2.ZERO
	var panel_size := _panel.get_combined_minimum_size()
	panel_size.x = maxf(panel_size.x, TEXT_WIDTH + 56.0)
	panel_size.y = minf(panel_size.y, view.y - 32.0)
	_panel.position = (view - panel_size) * 0.5
	_panel.size = panel_size
