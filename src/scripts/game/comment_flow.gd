class_name CommentFlow
extends Control

## 新しい行は下に追加（チャット／コンソール型）。上にスクロールで履歴を見る。
const FONT_SIZE := 16
const MAX_LINES := 200
const STICK_BOTTOM_PX := 48.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _pending: Array[String] = []
var _stick_bottom := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var panel := PanelContainer.new()
	panel.name = "LogPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	## ある程度透過した普通の黒。
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.name = "LogScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "LogList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		bar.value_changed.connect(_on_scroll_value_changed)
	resized.connect(_on_resized)


## 互換のため残す（縦ログでは未使用）。
func set_hole(_rect: Rect2) -> void:
	pass


func push(text: String) -> void:
	if text.is_empty():
		return
	if _list == null or size.x < 8.0:
		_pending.append(text)
		return
	_append_line(text)


func _on_resized() -> void:
	_flush_pending()
	if _stick_bottom:
		_scroll_to_bottom()


func _flush_pending() -> void:
	if _list == null or size.x < 8.0 or _pending.is_empty():
		return
	var queued := _pending.duplicate()
	_pending.clear()
	for text in queued:
		_append_line(text)


func _append_line(text: String) -> void:
	var follow := _stick_bottom or _is_near_bottom()
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	_list.add_child(label)
	label.custom_minimum_size = Vector2(maxf(40.0, size.x - 18.0), 0.0)
	while _list.get_child_count() > MAX_LINES:
		var oldest := _list.get_child(0)
		_list.remove_child(oldest)
		oldest.queue_free()
	_stick_bottom = follow
	if follow:
		call_deferred("_scroll_to_bottom")


func _is_near_bottom() -> bool:
	if _scroll == null:
		return true
	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return true
	return bar.max_value - bar.value <= STICK_BOTTOM_PX + bar.page


func _on_scroll_value_changed(_value: float) -> void:
	_stick_bottom = _is_near_bottom()


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = bar.max_value
	_stick_bottom = true
