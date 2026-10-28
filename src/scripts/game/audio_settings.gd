class_name AudioSettings
extends Control

var button_font := 14
var button_height := 36.0

var _open := false
var _button: Button
var _panel: PanelContainer
var _all_button: Button
var _bgm_button: Button
var _se_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, button_height)
	_button = _make_button("設定")
	_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.pressed.connect(_toggle_panel)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.94)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var heading := Label.new()
	heading.text = "音声"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", button_font + 2)
	heading.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	column.add_child(heading)
	_all_button = _make_button("")
	_all_button.custom_minimum_size = Vector2(168, button_height)
	_all_button.pressed.connect(_toggle_all)
	column.add_child(_all_button)
	_bgm_button = _make_button("")
	_bgm_button.custom_minimum_size = Vector2(168, button_height)
	_bgm_button.pressed.connect(_toggle_bgm)
	column.add_child(_bgm_button)
	_se_button = _make_button("")
	_se_button.custom_minimum_size = Vector2(168, button_height)
	_se_button.pressed.connect(_toggle_se)
	column.add_child(_se_button)
	add_child(_panel)
	_refresh()


func _toggle_panel() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		_place_panel()
	_refresh()
	GameAudio.play_confirm()


func _toggle_all() -> void:
	var enabled := not (GameAudio.is_bgm_enabled() and GameAudio.is_se_enabled())
	if not enabled:
		GameAudio.play_confirm()
	GameAudio.set_bgm_enabled(enabled)
	GameAudio.set_se_enabled(enabled)
	if enabled:
		GameAudio.play_confirm()
	_refresh()


func _toggle_bgm() -> void:
	GameAudio.set_bgm_enabled(not GameAudio.is_bgm_enabled())
	_refresh()
	GameAudio.play_confirm()


func _toggle_se() -> void:
	var turning_off := GameAudio.is_se_enabled()
	if turning_off:
		GameAudio.play_confirm()
	GameAudio.set_se_enabled(not turning_off)
	if not turning_off:
		GameAudio.play_confirm()
	_refresh()


func _place_panel() -> void:
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	var view := get_viewport().get_visible_rect().size
	var place := Vector2(-panel_size.x - 8.0, 0.0)
	if global_position.x + place.x < 8.0:
		place.x = size.x + 8.0
	if global_position.y + place.y + panel_size.y > view.y - 8.0:
		place.y = minf(0.0, size.y - panel_size.y)
	_panel.position = place


func _refresh() -> void:
	_button.text = "閉じる" if _open else "設定"
	var bgm_on := GameAudio.is_bgm_enabled()
	var se_on := GameAudio.is_se_enabled()
	var all_label := "オン" if bgm_on and se_on else "オフ" if not bgm_on and not se_on else "混在"
	_all_button.text = "一括　%s" % all_label
	_bgm_button.text = "BGM　%s" % ("オン" if bgm_on else "オフ")
	_se_button.text = "SE　%s" % ("オン" if GameAudio.is_se_enabled() else "オフ")


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", button_font)
	button.set_meta(&"confirm_bound", true)
	return button
