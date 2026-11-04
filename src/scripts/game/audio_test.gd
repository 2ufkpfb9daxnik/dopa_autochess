class_name AudioTest
extends Control

var button_font := 14
var button_height := 36.0

var _open := false
var _button: Button
var _panel: PanelContainer
var _option: OptionButton
var _play_button: Button
var _stop_button: Button
var _tracks: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, button_height)
	_button = _make_button("音声テスト")
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
	heading.text = "BGMテスト"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", button_font + 2)
	heading.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	column.add_child(heading)
	_option = OptionButton.new()
	_option.focus_mode = Control.FOCUS_NONE
	_option.custom_minimum_size = Vector2(240, button_height)
	_option.add_theme_font_size_override("font_size", button_font)
	column.add_child(_option)
	_play_button = _make_button("再生")
	_play_button.custom_minimum_size = Vector2(240, button_height)
	_play_button.pressed.connect(_play_selected)
	column.add_child(_play_button)
	_stop_button = _make_button("停止")
	_stop_button.custom_minimum_size = Vector2(240, button_height)
	_stop_button.pressed.connect(_stop_playback)
	column.add_child(_stop_button)
	add_child(_panel)
	_fill_tracks()
	_refresh()


func _fill_tracks() -> void:
	_tracks = GameAudio.list_bgm_tracks()
	_option.clear()
	for path in _tracks:
		_option.add_item(path.get_file().get_basename())
	if _option.item_count > 0:
		_option.select(0)


func _toggle_panel() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		_fill_tracks()
		_place_panel()
	_refresh()
	GameAudio.play_confirm()


func _play_selected() -> void:
	var index := _option.selected
	if index < 0 or index >= _tracks.size():
		return
	GameAudio.play_bgm_track(_tracks[index])
	GameAudio.play_confirm()


func _stop_playback() -> void:
	GameAudio.stop_bgm()
	GameAudio.play_confirm()


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
	_button.text = "閉じる" if _open else "音声テスト"


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", button_font)
	button.set_meta(&"confirm_bound", true)
	return button
