class_name BoardNotice
extends Control

const HOLD := 2.8

var _label: Label
var _hide_at := 0.0
var _persistent := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	_label.add_theme_color_override("font_outline_color", Color(0.55, 0.05, 0.08, 0.95))
	_label.add_theme_constant_override("outline_size", 14)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	visible = false
	set_process(false)


func show_notice(text: String, persistent: bool = false) -> void:
	_label.text = text
	_persistent = persistent
	visible = true
	_fit_font()
	if persistent:
		set_process(false)
		return
	_hide_at = Time.get_ticks_msec() * 0.001 + HOLD
	set_process(true)


func clear_persistent() -> void:
	if not _persistent:
		return
	_persistent = false
	visible = false
	set_process(false)


func is_persistent() -> bool:
	return _persistent and visible


func _process(_delta: float) -> void:
	if _persistent:
		return
	if Time.get_ticks_msec() * 0.001 >= _hide_at:
		visible = false
		set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_font()


func _fit_font() -> void:
	if _label == null or size.y < 8.0:
		return
	var font_size := int(clampf(size.y * 0.42, 42.0, 96.0))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override("outline_size", maxi(8, int(round(float(font_size) * 0.16))))
