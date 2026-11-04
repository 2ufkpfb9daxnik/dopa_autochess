class_name ExpHintArrow
extends Control

## サークル人数上限で弾かれたとき、経験値購入ボタンを指す。
const HOLD := 3.4

var _target: Control
var _hide_at := 0.0
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	visible = false
	set_process(false)


func point_at(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	_target = target
	_pulse = 0.0
	_hide_at = Time.get_ticks_msec() * 0.001 + HOLD
	visible = true
	set_process(true)
	_layout_to_target()
	queue_redraw()


func clear() -> void:
	visible = false
	set_process(false)
	_target = null


func _process(delta: float) -> void:
	_pulse += delta
	if Time.get_ticks_msec() * 0.001 >= _hide_at:
		clear()
		return
	_layout_to_target()
	queue_redraw()


func _layout_to_target() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		clear()
		return
	var rect := _target.get_global_rect()
	var arrow_w := clampf(rect.size.x * 2.8, 180.0, 320.0)
	var arrow_h := clampf(rect.size.y * 2.4, 120.0, 220.0)
	var bounce := sin(_pulse * 7.0) * 18.0
	## ボタンの左から右向きに指す。
	global_position = Vector2(rect.position.x - arrow_w - 12.0 + bounce, rect.get_center().y - arrow_h * 0.5)
	size = Vector2(arrow_w, arrow_h)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var tip := Vector2(size.x - 6.0, size.y * 0.5)
	var base_x := size.x * 0.18
	var wing := size.y * 0.42
	var shaft_h := size.y * 0.22
	var poly := PackedVector2Array([
		tip,
		Vector2(size.x * 0.48, size.y * 0.5 - wing),
		Vector2(size.x * 0.48, size.y * 0.5 - shaft_h),
		Vector2(base_x, size.y * 0.5 - shaft_h),
		Vector2(base_x, size.y * 0.5 + shaft_h),
		Vector2(size.x * 0.48, size.y * 0.5 + shaft_h),
		Vector2(size.x * 0.48, size.y * 0.5 + wing),
	])
	var fill := Color(1.0, 0.86, 0.18, 0.96)
	var outline := Color(0.35, 0.08, 0.02, 0.95)
	## 縁取り用に少し大きい多角形を先に塗る。
	var fat := PackedVector2Array()
	var center := size * 0.5
	for point in poly:
		fat.append(center + (point - center) * 1.08)
	draw_colored_polygon(fat, outline)
	draw_colored_polygon(poly, fill)
	## 「ここ」ラベル。
	var font := get_theme_default_font()
	if font == null:
		return
	var label := "経験値"
	var font_size := int(clampf(size.y * 0.22, 28.0, 48.0))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := Vector2(base_x + 8.0, size.y * 0.5 + text_size.y * 0.35)
	draw_string(font, text_pos + Vector2(2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.04, 0.02, 0.85))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.12, 0.05, 0.02, 1.0))
