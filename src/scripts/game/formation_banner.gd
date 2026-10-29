class_name FormationBanner
extends Control

const HOLD := 1.6
const FADE := 0.75
const ELEMENT_COLORS := {
	"炎": Color(1.0, 0.42, 0.28),
	"水": Color(0.35, 0.62, 1.0),
	"氷": Color(0.55, 0.92, 1.0),
	"風": Color(0.72, 0.95, 0.35),
	"雷": Color(1.0, 0.9, 0.28),
	"吸収": Color(0.78, 0.48, 1.0),
	"土": Color(1.0, 0.62, 0.28),
}

var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.95))
	_label.add_theme_constant_override("outline_size", 18)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	visible = false
	modulate.a = 0.0


func show_elements(elements: PackedStringArray) -> void:
	if elements.is_empty():
		return
	var parts: PackedStringArray = []
	for element in elements:
		parts.append("%s属性ダメージ上昇！！" % element)
	_label.text = "\n".join(parts)
	var accent: Color = ELEMENT_COLORS.get(elements[0], Color(1.0, 0.95, 0.82))
	_label.add_theme_color_override("font_color", accent)
	_fit_font()
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		visible = false
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_font()


func _fit_font() -> void:
	if _label == null or size.y < 8.0:
		return
	var font_size := int(clampf(minf(size.x, size.y) * 0.22, 48.0, 110.0))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override("outline_size", maxi(12, int(round(float(font_size) * 0.18))))
